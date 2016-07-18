//
//  AudioRecorder.h
//  Twindow
//
//  Created by Sunny on 15/7/10.
//  Copyright (c) 2015年 Sunny. All rights reserved.
//
#include <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#include "CAStreamBasicDescription.h"
#include "CAXException.h"

#define kMaxDurationSeconds     120.f
#define kNumberRecordBuffers    3
#define kBufferDurationSeconds  .5f
#define kSampleRate             22050   //采样速率
#define kAudioBitsPerChannel    16      //比特率
#define kChannelsPerFrame       2       //通道
#define kAudioFormatID          kAudioFormatMPEG4AAC_HE //kAudioFormatMPEG4AAC_HE //kAudioFormatMPEGLayer3 //kAudioFormatMPEG4AAC_HE_V2  //kAudioFormatLinearPCM
#define kAudioFileTypeID        kAudioFileMPEG4Type   //kAudioFileMP3Type //kAudioFileM4AType       //kAudioFileCAFType   //kAudioFileAAC_ADTSType
#define kAudioFileExtension     @".aac"

class AudioRecorder
{
public:
    AudioRecorder();
    ~AudioRecorder();
    
    UInt32						GetNumberChannels() const	{ return mRecordFormat.NumberChannels(); }
    CFStringRef					GetFileName() const			{ return mFileName; }
    AudioQueueRef				Queue() const				{ return mQueue; }
    CAStreamBasicDescription	DataFormat() const			{ return mRecordFormat; }
    
    void			StartRecord(CFStringRef inRecordFile);
    void			StopRecord();
    Boolean			IsRunning() const			{ return mIsRunning; }
    Boolean         IsVerbose() const           { return mVerbose;   }
    CFAbsoluteTime  GetDuration() const         { return mQueueStartStopTime;}
				
private:
    CFStringRef					mFileName;                      //保存的文件名
    AudioQueueRef				mQueue;                         //音频队列
    AudioQueueBufferRef			mBuffers[kNumberRecordBuffers]; //每个音频列队的buffer包
    AudioFileID					mRecordFile;                    //
    SInt64						mRecordPacket; // current packet number in record file
    CAStreamBasicDescription	mRecordFormat;                  //音频流信息
    CFAbsoluteTime				mQueueStartStopTime;             //固定起止时间设置
    Boolean						mIsRunning;                     //判断是否在录音
    Boolean                     mVerbose;                        //详细数据
    void			CopyEncoderCookieToFile();                  //创建音频文件并写入流数据
    void			SetupAudioFormat();                         //设置音频参数
    void            ResetRecord();
    int				ComputeRecordBufferSize(const AudioStreamBasicDescription *format, float seconds);
    static void     PropertyListener(void *userData, AudioQueueRef queue, AudioQueuePropertyID propertyID);
    //时时处理InputBuffer
    static void     MyInputBufferHandler(	void *								inUserData,
                                     AudioQueueRef						inAQ,
                                     AudioQueueBufferRef					inBuffer,
                                     const AudioTimeStamp *				inStartTime,
                                     UInt32								inNumPackets,
                                     const AudioStreamPacketDescription*	inPacketDesc);
};
