//
//  AudioManager.m
//  Twindow
//
//  Created by Sunny on 15/7/9.
//  Copyright (c) 2015年 Sunny. All rights reserved.
//
#import "AudioManager.h"
#import "AudioPlayer.h"
#import "AudioRecorder.h"

@interface AudioManager ()
{
    AudioRecorder *	recorder;
    AudioPlayer   * player;
    CFStringRef     mFilePath;
}

@end

@implementation AudioManager

singleton_implementation(AudioManager)

#pragma  mark - recordMethods

- (id)init
{
    self = [super init];
    
    if (self)
    {
        [self setupAudio];
    }
    return self;
}

- (void)setupAudio
{
    recorder = new AudioRecorder();
    player   = new AudioPlayer();
    
    self.audioTypeNow = AudioTypeNone;
}

- (CFStringRef)getFileName
{
    return mFilePath;
}

- (NSString *)getRecordFormatTime
{
    if (recorder)
    {
        return [self getFormatTime:(recorder -> GetDuration())];
    }
    return [self getFormatTime:0];
}

- (NSString *)getFormatTime:(CFAbsoluteTime)time
{
    NSLog(@"getFormatTime : %.2f",time);
    NSString * formatTime = nil;
    NSString * fir = nil;
    NSString * sed = nil;
    int first  = (int)time/60;
    int second = (int)time%60;
    
    if (first)
    {
        fir = [NSString stringWithFormat:@"0%d",first];
    }
    else
    {
        fir = [NSString stringWithFormat:@"00"];
    }
    
    if (second/10)
    {
        sed = [NSString stringWithFormat:@"%d",second];
    }
    else
    {
        sed = [NSString stringWithFormat:@"0%d",second];
    }
    
    formatTime = [NSString stringWithFormat:@"%@:%@",fir,sed];
    
    return formatTime;
}

#pragma  mark - actionMethods Button
- (BOOL)recordStart:(CFStringRef)recordFile
{
    if (!recordFile)
    {
        NSLog(@"recordFile is error");
        return NO;
    }
    
    if (player -> IsRunning())
    {
        NSLog(@"player -> IsRunning");
        return NO;
    }
    if (recorder->IsRunning())
    {
        NSLog(@"recorder->IsRunning()");
        return NO;
    }
    
    recorder -> StartRecord(recordFile);
    self.audioTypeNow = AudioTypeRecord;
    mFilePath = recorder -> GetFileName();
    
    return YES;
}

- (void)recordStop
{
    mFilePath = recorder -> GetFileName();
    
    recorder -> StopRecord();
}

- (BOOL)audioPlay:(CFStringRef)fileName
{
    if (!fileName || ![[NSFileManager defaultManager] fileExistsAtPath:(__bridge NSString *)fileName])
    {
        NSLog(@"fileName is error");
        return NO;
    }
    
    if (recorder -> IsRunning())
    {
        NSLog(@"recorder -> IsRunning");
        return NO;
    }
    
    if (!player -> IsRunning() && fileName)
    {
        // dispose the previous playback queue
        player -> DisposeQueue(true);
        // now create a new queue for the recorded file
        player -> CreateQueueForFile(fileName);
    }
    
    player -> StartQueue(false);
    
    self.audioTypeNow = AudioTypePlay;
    
    mFilePath = player -> GetFilePath();
    
    return YES;
}

- (void)audioStop
{
    player->StopQueue();
    self.audioTypeNow = AudioTypeNone;
}

- (void)audioPause
{
    player -> PauseQueue();
}

- (void)dealloc
{
    delete recorder;
    delete player;
}

@end
