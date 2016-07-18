//
//  AppDelegate.m
//  AudioRecord
//
//  Created by Sunny on 16/7/18.
//  Copyright © 2016年 Sunny. All rights reserved.
//

#import "AppDelegate.h"
#import "AudioManager.h"

#define kRecordImage        @"recorded.gif"
#define kRecordingImage     @"recording.gif"
#define kAudioFileExtension     @".aac"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;


@property (strong) IBOutlet NSImageView *recordImageView;

@property (strong) IBOutlet NSButton *closeBtn;

@property (strong) IBOutlet NSButton *confirmBtn;

@property (strong) IBOutlet NSTextField *timeLabel;

@property (strong) IBOutlet NSButton *stopBtn;

@property (strong) IBOutlet NSButton *recordBtn;

@property (strong) IBOutlet NSButton *playBtn;

@property (nonatomic , strong) NSTimer * timer;
@property (nonatomic , assign) CFAbsoluteTime timeNum;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    _timeNum = 0.;
    _timer = [NSTimer timerWithTimeInterval:1 target:self selector:@selector(timerUpdate:) userInfo:nil repeats:YES];
    [self timerStop];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(AudioQueueStop:) name:kAudioQueueStop object:nil];
    
    [self.confirmBtn setEnabled:NO];
    [self setRecordAndPlayEnable:YES];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)windowShouldClose:(NSWindow *)sender
{
    [self ActionStop:nil];
    [self.window orderOut:nil];
    [NSApp stopModalWithCode:NSModalResponseCancel];
    return YES;
}

- (IBAction)ActionConfirm:(id)sender
{
    [self.window orderOut:nil];
    [NSApp stopModalWithCode:NSModalResponseOK];
}

#pragma mark - timerUpdate 计时器
- (void)timerUpdate:(id)sender
{
    [self.timeLabel setStringValue:[[AudioManager sharedAudioManager] getFormatTime:_timeNum++]];
    //    NSLog(@"timerUpdate  %d      timeNum: %@",[_timer isValid],self.timeLabel.stringValue);
}

- (void)timerStart
{
    _timeNum = 0.;
    if (_timer)
    {
        [_timer setFireDate:[NSDate date]];
    }
    NSLog(@"timerStart: %d",[_timer isValid]);
}

- (void)timerStop
{
    if (_timer && [_timer isValid])
    {
        [_timer setFireDate:[NSDate distantFuture]];
    }
    NSLog(@"timerStop: %d",[_timer isValid]);
}


#pragma mark - 音频方法 AudioAction
- (void)AudioQueueStop:(NSNotification *)noti
{
    [self.recordImageView setImage:[NSImage imageNamed:kRecordImage]];
    [self timerStop];
    
    [self.confirmBtn setEnabled:YES];
    [self setRecordAndPlayEnable:YES];
}

- (IBAction)ActionClose:(id)sender
{
    
    [self ActionStop:nil];
    [self windowShouldClose:self.window];
}

- (IBAction)ActionStop:(id)sender
{
    [self timerStop];
    
    if ([[AudioManager sharedAudioManager] audioTypeNow] == AudioTypeRecord)
    {
        [[AudioManager sharedAudioManager] recordStop];
    }
    else if ([[AudioManager sharedAudioManager] audioTypeNow] == AudioTypePlay)
    {
        [[AudioManager sharedAudioManager] audioStop];
    }
}

- (IBAction)ActionRecord:(id)sender
{
    if ([[AudioManager sharedAudioManager] recordStart:[self getLocalAudioPath]])
    {
        [self setRecordAndPlayEnable:NO];
        [self.recordImageView setImage:[NSImage imageNamed:kRecordingImage]];
        [self timerStart];
    }
}

- (IBAction)ActionPlay:(id)sender
{
    if([[AudioManager sharedAudioManager] audioPlay:[[AudioManager sharedAudioManager] getFileName]])
    {
        [self setRecordAndPlayEnable:NO];
        [self.recordImageView setImage:[NSImage imageNamed:kRecordingImage]];
        [self timerStart];
    }
}

#pragma  mark - ToolMethods 辅助工具方法
- (CFStringRef)getLocalAudioPath
{
    NSString * filePath = nil;
    NSString * docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString * dirPath = [NSString stringWithFormat:@"%@/AudioRecord/%@/",docPath, nil];
    docPath = nil;
    NSFileManager * fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:dirPath])
    {
        NSLog(@"file not Exists At Path ");
        NSError * error = NULL;
        [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:&error];
    }
    NSDateFormatter * dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH:mm:ss"];
    NSString * timeString = [dateFormatter stringFromDate:[NSDate date]];
    dateFormatter = nil;
    filePath = [NSString stringWithFormat:@"%@%@%@",dirPath,timeString,kAudioFileExtension,nil];
    NSLog(@"audioFilePath: %@",filePath);
    
    return CFStringCreateCopy(kCFAllocatorDefault, (CFStringRef)filePath);
}

- (void)setRecordAndPlayEnable:(BOOL)isEnable
{
    [self.stopBtn setEnabled:!isEnable];
    [self.recordBtn setEnabled:isEnable];
    
    NSString * fileName = (__bridge NSString*)[[AudioManager sharedAudioManager] getFileName];
    if (fileName && [[NSFileManager defaultManager] fileExistsAtPath:fileName] && isEnable)
    {
        [self.playBtn setEnabled:YES];
    }
    else
    {
        [self.playBtn setEnabled:NO];
    }
}

@end
