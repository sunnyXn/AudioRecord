//
//  AudioManager.h
//  Twindow
//
//  Created by Sunny on 15/7/9.
//  Copyright (c) 2015年 Sunny. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kAudioQueueStop @"AudioQueueStopped"

typedef NS_ENUM(NSUInteger, AudioType)
{
    AudioTypeNone = 0,
    AudioTypeRecord  ,
    AudioTypePlay    ,
};


@interface AudioManager : NSObject

@property (nonatomic , assign) AudioType audioTypeNow;

singleton_interface(AudioManager)

- (CFStringRef)getFileName;
- (NSString *)getRecordFormatTime;
- (NSString *)getFormatTime:(CFAbsoluteTime)time;

- (BOOL)recordStart:(CFStringRef)recordFile;
- (void)recordStop;

- (BOOL)audioPlay:(CFStringRef)fileName;
- (void)audioStop;
- (void)audioPause;

@end

