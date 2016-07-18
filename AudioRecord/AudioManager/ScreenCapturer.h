//
//  ScreenCapturer.h
//  UCDisk
//
//  Created by Sunny on 15/8/4.
//  Copyright (c) 2015年 YXCloudDisk. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ScreenCapturerDelegate;

@interface ScreenCapturer : NSObject

@property (nonatomic, assign) id<ScreenCapturerDelegate> delegate;

- (void)startCapture;

@end

@protocol ScreenCapturerDelegate <NSObject>

- (void)screenCapturer:(ScreenCapturer *)capturer didFinishWithImageData:(NSData *)data;

@end
