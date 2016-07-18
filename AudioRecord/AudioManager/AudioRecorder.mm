//
//  AudioRecorder.mm
//  Twindow
//
//  Created by Sunny on 15/7/10.
//  Copyright (c) 2015年 Sunny. All rights reserved.
//

#include "AudioRecorder.h"
#import "AudioManager.h"

AudioRecorder::AudioRecorder()
{
    mIsRunning = false;
    mRecordPacket = 0;
    mVerbose = false;
}

AudioRecorder::~AudioRecorder()
{
    ResetRecord();
}


// Infer an audio file type from a filename's extension.
static Boolean InferAudioFileFormatFromFilename(CFStringRef filename, AudioFileTypeID *outFiletype)
{
    OSStatus err;
    
    // find the extension in the filename.
    CFRange range = CFStringFind(filename, CFSTR("."), kCFCompareBackwards);
    if (range.location == kCFNotFound)
        return FALSE;
    range.location += 1;
    range.length = CFStringGetLength(filename) - range.location;
    CFStringRef extension = CFStringCreateWithSubstring(NULL, filename, range);
    
    UInt32 propertySize = sizeof(AudioFileTypeID);
    err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_TypesForExtension, sizeof(extension), &extension, &propertySize, outFiletype);
    CFRelease(extension);
    
    return (err == noErr && propertySize > 0);
}

static Boolean FileFormatRequiresBigEndian(AudioFileTypeID audioFileType, int bitdepth)
{
    AudioFileTypeAndFormatID ftf;
    UInt32 propertySize;
    OSStatus err;
    Boolean requiresBigEndian;
    
    ftf.mFileType = audioFileType;
    ftf.mFormatID = kAudioFormatID;
    
    err = AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(ftf), &ftf, &propertySize);
    if (err) return FALSE;
    
    AudioStreamBasicDescription *formats = (AudioStreamBasicDescription *)malloc(propertySize);
    err = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat, sizeof(ftf), &ftf, &propertySize, formats);
    requiresBigEndian = TRUE;
    if (err == noErr) {
        int i, nFormats = propertySize / sizeof(AudioStreamBasicDescription);
        for (i = 0; i < nFormats; ++i) {
            if (formats[i].mBitsPerChannel == bitdepth
                && !(formats[i].mFormatFlags & kLinearPCMFormatFlagIsBigEndian)) {
                requiresBigEndian = FALSE;
                break;
            }
        }
    }
    free(formats);
    return requiresBigEndian;
}



// get sample rate of the default input device
OSStatus GetDefaultInputDeviceSampleRate(Float64 *outSampleRate)
{
    OSStatus err;
    AudioDeviceID deviceID = 0;
    
    // get the default input device
    AudioObjectPropertyAddress addr;
    UInt32 size;
    addr.mSelector = kAudioHardwarePropertyDefaultInputDevice;
    addr.mScope = kAudioObjectPropertyScopeGlobal;
    addr.mElement = 0;
    size = sizeof(AudioDeviceID);
    err = AudioHardwareServiceGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &deviceID);
    if (err) return err;
    
    // get its sample rate
    addr.mSelector = kAudioDevicePropertyNominalSampleRate;
    addr.mScope = kAudioObjectPropertyScopeGlobal;
    addr.mElement = 0;
    size = sizeof(Float64);
    err = AudioHardwareServiceGetPropertyData(deviceID, &addr, 0, NULL, &size, outSampleRate);
    
    return err;
}

// ____________________________________________________________________________________
// Determine the size, in bytes, of a buffer necessary to represent the supplied number
// of seconds of audio data.
int	AudioRecorder::ComputeRecordBufferSize(const AudioStreamBasicDescription *format, float seconds)
{
    int packets, frames, bytes = 0;
    try {
        frames = (int)ceil(seconds * format->mSampleRate);
        
        if (format->mBytesPerFrame > 0)
            bytes = frames * format->mBytesPerFrame;
        else {
            UInt32 maxPacketSize;
            if (format->mBytesPerPacket > 0)
                maxPacketSize = format->mBytesPerPacket;	// constant packet size
            else {
                UInt32 propertySize = sizeof(maxPacketSize);
                XThrowIfError(AudioQueueGetProperty(mQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize,
                                                    &propertySize), "couldn't get queue's maximum output packet size");
            }
            if (format->mFramesPerPacket > 0)
                packets = frames / format->mFramesPerPacket;
            else
                packets = frames;	// worst-case scenario: 1 frame in a packet
            if (packets == 0)		// sanity check
                packets = 1;
            bytes = packets * maxPacketSize;
        }
    } catch (CAXException e) {
        char buf[256];
        fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
        return 0;
    }
    return bytes;
}

// ____________________________________________________________________________________
// AudioQueue callback function, called when a property changes.
void AudioRecorder::PropertyListener(void *userData, AudioQueueRef queue, AudioQueuePropertyID propertyID)
{
    AudioRecorder * recorder = (AudioRecorder *)userData;
    if (propertyID == kAudioQueueProperty_IsRunning)
    {
        if (recorder -> mQueueStartStopTime == 0.)
        {
            recorder -> mQueueStartStopTime = CFAbsoluteTimeGetCurrent();
        }
        else
        {
            recorder -> mQueueStartStopTime = CFAbsoluteTimeGetCurrent() - recorder -> mQueueStartStopTime;
        }
    }
    NSLog(@"PropertyListener -> mQueueStartStopTime : %.2f====",recorder -> mQueueStartStopTime);
}

// ____________________________________________________________________________________
// AudioQueue callback function, called when an input buffers has been filled.
void AudioRecorder::MyInputBufferHandler(	void *                          inUserData,
                                 AudioQueueRef                   inAQ,
                                 AudioQueueBufferRef             inBuffer,
                                 const AudioTimeStamp *          inStartTime,
                                 UInt32							inNumPackets,
                                 const AudioStreamPacketDescription *inPacketDesc)
{
    AudioRecorder * recorder = (AudioRecorder *)inUserData;
    
    
    NSLog(@"---------------录音时间： %.2f ",CFAbsoluteTimeGetCurrent() - recorder -> mQueueStartStopTime);
    
    if (CFAbsoluteTimeGetCurrent() - recorder -> mQueueStartStopTime >= kMaxDurationSeconds)
    {
        NSLog(@"---------------录音时间超过最大限制时间---------------");
        recorder -> StopRecord();
    }
//    NSLog(@"录音长度:%u  numPackets: %u", inBuffer->mAudioDataByteSize , inNumPackets);
    try {
        if (recorder->IsVerbose()) {
            printf("buf data %p, 0x%x bytes, 0x%x packets\n", inBuffer->mAudioData,
                   (int)inBuffer->mAudioDataByteSize, (int)inNumPackets);
        }
        
        if (inNumPackets > 0) {
            // write packets to file
            XThrowIfError(AudioFileWritePackets(recorder->mRecordFile, FALSE, inBuffer->mAudioDataByteSize,
                                                inPacketDesc, recorder->mRecordPacket, &inNumPackets, inBuffer->mAudioData),
                          "AudioFileWritePackets failed");
            recorder->mRecordPacket += inNumPackets;
        }
        
        // if we're not stopping, re-enqueue the buffe so that it gets filled again
        if (recorder->IsRunning())
            XThrowIfError(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL), "AudioQueueEnqueueBuffer failed");
    } 
    catch (CAXException e) {
        char buf[256];
        fprintf(stderr, "MyInputBufferHandler: %s (%s)\n", e.mOperation, e.FormatError(buf));
    }	
}

// ____________________________________________________________________________________
// Copy a queue's encoder's magic cookie to an audio file.
void AudioRecorder::CopyEncoderCookieToFile()
{
    UInt32 propertySize;
    // get the magic cookie, if any, from the converter
    OSStatus err = AudioQueueGetPropertySize(mQueue, kAudioQueueProperty_MagicCookie, &propertySize);
    
    // we can get a noErr result and also a propertySize == 0
    // -- if the file format does support magic cookies, but this file doesn't have one.
    if (err == noErr && propertySize > 0) {
        // there is valid cookie data to be fetched;  get it
        Byte *magicCookie = (Byte *)malloc(propertySize);
        try
        {
            XThrowIfError(AudioQueueGetProperty(mQueue, kAudioConverterCompressionMagicCookie, magicCookie,
                                                &propertySize), "get audio converter's magic cookie");
            // now set the magic cookie on the output file
            // even though some formats have cookies, some files don't take them, so we ignore the error
            /*err =*/ AudioFileSetProperty(mRecordFile, kAudioFilePropertyMagicCookieData, propertySize, magicCookie);
        }
        catch (CAXException e)
        {
            char buf[256];
            fprintf(stderr, "CopyEncoderCookieToFile: %s (%s)\n", e.mOperation, e.FormatError(buf));
        }
        catch (...)
        {
            fprintf(stderr, "CopyEncoderCookieToFile: Unexpected exception\n");
        }
        free(magicCookie);
    }
}

void AudioRecorder::SetupAudioFormat()
{
    memset(&mRecordFormat, 0, sizeof(mRecordFormat));
    
    mRecordFormat.mFormatID = kAudioFormatID;
    
    // adapt record format to hardware and apply defaults
    if (mRecordFormat.mSampleRate == 0.)
        GetDefaultInputDeviceSampleRate(&mRecordFormat.mSampleRate);
    
    if (mRecordFormat.mChannelsPerFrame == 0)
        mRecordFormat.mChannelsPerFrame = kChannelsPerFrame;
    
    if (mRecordFormat.mFormatID == 0 || mRecordFormat.mFormatID == kAudioFormatLinearPCM) {
        // default to PCM, 16 bit int
        mRecordFormat.mFormatID = kAudioFormatID;
        mRecordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        mRecordFormat.mBitsPerChannel = kAudioBitsPerChannel;
        
        if (FileFormatRequiresBigEndian(kAudioFileTypeID, mRecordFormat.mBitsPerChannel))
            mRecordFormat.mFormatFlags |= kLinearPCMFormatFlagIsBigEndian;
        
        mRecordFormat.mBytesPerPacket = mRecordFormat.mBytesPerFrame =
        (mRecordFormat.mBitsPerChannel / 8) * mRecordFormat.mChannelsPerFrame;
        mRecordFormat.mFramesPerPacket = 1;
        mRecordFormat.mReserved = 0;
    }
}

void AudioRecorder::StartRecord(CFStringRef inRecordFile)
{
    int i, bufferByteSize;
    UInt32 size;
    CFURLRef url = nil;
    mQueueStartStopTime = 0.;
    try {
        // determine file format
        mFileName = CFStringCreateCopy(kCFAllocatorDefault, inRecordFile);
        AudioFileTypeID audioFileType = kAudioFileTypeID;
        InferAudioFileFormatFromFilename(mFileName, &audioFileType);
        
        // specify the recording format
        // adapt record format to hardware and apply defaults
        SetupAudioFormat();
        
        // create the queue
        XThrowIfError(AudioQueueNewInput(
                                         &mRecordFormat,
                                         MyInputBufferHandler,
                                         this /* userData */,
                                         NULL /* run loop */, NULL /* run loop mode */,
                                         0 /* flags */, &mQueue), "AudioQueueNewInput failed");
        
        // get the record format back from the queue's audio converter --
        // the file may require a more specific stream description than was necessary to create the encoder.
        mRecordPacket = 0;
        
        size = sizeof(mRecordFormat);
        XThrowIfError(AudioQueueGetProperty(mQueue, kAudioQueueProperty_StreamDescription,
                                            &mRecordFormat, &size), "couldn't get queue's format");
        // convert recordFileName from C string to CFURL
        url = CFURLCreateWithString(kCFAllocatorDefault, mFileName, NULL);
        
        // create the audio file
        OSStatus status = AudioFileCreateWithURL(url, audioFileType, &mRecordFormat, kAudioFileFlags_EraseFile, &mRecordFile);
        CFRelease(url);
        
        XThrowIfError(status, "AudioFileCreateWithURL failed");
        
        // copy the cookie first to give the file object as much info as we can about the data going in
        // not necessary for pcm, but required for some compressed audio
        CopyEncoderCookieToFile();
        
        // allocate and enqueue buffers
        bufferByteSize = ComputeRecordBufferSize(&mRecordFormat, kBufferDurationSeconds);	// enough bytes for half a second
        for (i = 0; i < kNumberRecordBuffers; ++i) {
            XThrowIfError(AudioQueueAllocateBuffer(mQueue, bufferByteSize, &mBuffers[i]),
                          "AudioQueueAllocateBuffer failed");
            XThrowIfError(AudioQueueEnqueueBuffer(mQueue, mBuffers[i], 0, NULL),
                          "AudioQueueEnqueueBuffer failed");
        }
        
        float seconds = kBufferDurationSeconds;
        
        if (seconds > 0) {
            // user requested a fixed-length recording (specified a duration with -s)
            // to time the recording more accurately, watch the queue's IsRunning property
            XThrowIfError(AudioQueueAddPropertyListener(mQueue, kAudioQueueProperty_IsRunning,
                                                        PropertyListener, this), "AudioQueueAddPropertyListener failed");
            
            // start the queue
            mIsRunning = TRUE;
            XThrowIfError(AudioQueueStart(mQueue, NULL), "AudioQueueStart failed");
            CFAbsoluteTime waitUntil = CFAbsoluteTimeGetCurrent() + 10;
            // wait for the started notification
            while (mQueueStartStopTime == 0.)
            {
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.010, FALSE);
                if (CFAbsoluteTimeGetCurrent() >= waitUntil)
                {
                    fprintf(stderr, "Timeout waiting for the queue's IsRunning notification\n");
                    StopRecord();
                    break;
                }
            }
            
            printf("Recording...\n");
            CFAbsoluteTime stopTime = mQueueStartStopTime + seconds;
            CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, stopTime - now, FALSE);
        } else {
            // start the queue
            mIsRunning = TRUE;
            XThrowIfError(AudioQueueStart(mQueue, NULL), "AudioQueueStart failed");
            
            printf("Recording...\n");
        }
    }
    catch (CAXException e) {
        char buf[256];
        fprintf(stderr, "Error: %s (%s)\n", e.mOperation, e.FormatError(buf));
    }
    catch (...) {
        fprintf(stderr, "An unknown error occurred\n");;
    }
}

void AudioRecorder::StopRecord()
{
    // end recording
    if (!mIsRunning)
        return;
    
    mIsRunning = false;
    XThrowIfError(AudioQueueStop(mQueue, true), "AudioQueueStop failed");
    // a codec may update its cookie at the end of an encoding session, so reapply it to the file now
    CopyEncoderCookieToFile();
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kAudioQueueStop object: nil];
    
    ResetRecord();
}

void AudioRecorder::ResetRecord()
{
    mIsRunning = false;
    if (mFileName)
    {
        CFRelease(mFileName);
        mFileName = NULL;
    }
    AudioQueueDispose(mQueue, true);
    AudioFileClose(mRecordFile);
}

