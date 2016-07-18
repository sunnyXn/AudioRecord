//
//  ScreenCapturer.m
//  UCDisk
//
//  Created by Sunny on 15/8/4.
//  Copyright (c) 2015年 YXCloudDisk. All rights reserved.
//

#import "ScreenCapturer.h"

#define kScreenCapturePath @"/usr/sbin/screencapture"

@interface ScreenCapturer()

@property (nonatomic, assign) NSUInteger initialPasteboardChangeCount;

@end


@implementation ScreenCapturer

- (void)startCapture
{
    self.initialPasteboardChangeCount = [[NSPasteboard generalPasteboard] changeCount];
    
    NSTask * task = [[NSTask alloc] init];
    
    [task setLaunchPath:kScreenCapturePath];
    [task setArguments:@[@"-ci"]];
    [task launch];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkCaptureTaskStatus:) name:NSTaskDidTerminateNotification object:task];
}

- (void)captureFinished
{
    NSPasteboard * pasteboard = [NSPasteboard generalPasteboard];
    
    NSString * desiredType = [pasteboard availableTypeFromArray:@[NSPasteboardTypePNG]];
    
    if ([desiredType isEqualToString:NSPasteboardTypePNG])
    {
        NSData *imageData = [pasteboard dataForType:desiredType];
        
        if (!imageData)
        {
            NSLog(@"capture failed! data is nil.");
        }
        if ([_delegate respondsToSelector:@selector(screenCapturer:didFinishWithImageData:)])
        {
            [_delegate screenCapturer:self didFinishWithImageData:imageData];
        }
    }
}

- (void)checkCaptureTaskStatus:(NSNotification *)notification
{
    NSTask * task = [notification object];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:task];
    
    if (![task isRunning] && [[task launchPath] isEqualToString:kScreenCapturePath])
    {
        int status = [task terminationStatus];
        
        if (status == 0)
        {
            if (self.initialPasteboardChangeCount == [[NSPasteboard generalPasteboard] changeCount])
            {
                NSLog(@"capture task canceled.");
            }
            else
            {
                [self captureFinished];
            }
        }
        else
        {
            NSLog(@"capture task failed.");
        }
    }
}


@end
