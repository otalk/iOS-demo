//
//  ViewController.m
//  Copyright (c) 2014 &yet, LLC and otalk contributors
//

#import "ViewController.h"
#import "TLKSocketIOSignaling.h"
#import "TLKMediaStream.h"
#import "RTCMediaStream.h"
#import "RTCEAGLVideoView.h"
#import "RTCVideoTrack.h"

@interface ViewController () <TLKSocketIOSignalingDelegate, RTCEAGLVideoViewDelegate>

@property (strong, nonatomic) TLKSocketIOSignaling* signaling;
@property (strong, nonatomic) IBOutlet RTCEAGLVideoView *remoteView;
@property (strong, nonatomic) IBOutlet RTCEAGLVideoView *localView;
@property (strong, nonatomic) RTCVideoTrack *localVideoTrack;
@property (strong, nonatomic) RTCVideoTrack *remoteVideoTrack;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //RTCEAGLVideoViewDelegate provides notifications on video frame dimensions
    [self.remoteView setDelegate:self];
    [self.localView setDelegate:self];
    
    self.signaling = [[TLKSocketIOSignaling alloc] initWithVideo:YES];
    //TLKSocketIOSignalingDelegate provides signaling notifications
    self.signaling.delegate = self;
    [self.signaling connectToServer:@"signaling.simplewebrtc.com" port:80 secure:NO success:^{
        [self.signaling joinRoom:@"ios-demo" success:^{
            NSLog(@"join success");
        } failure:^{
            NSLog(@"join failure");
        }];
        NSLog(@"connect success");
    } failure:^(NSError* error) {
        NSLog(@"connect failure");
    }];
}


#pragma mark - TLKSocketIOSignalingDelegate

- (void)socketIOSignaling:(TLKSocketIOSignaling *)socketIOSignaling addedStream:(TLKMediaStream *)stream {
    NSLog(@"addedStream");

    RTCVideoTrack *remoteVideoTrack = stream.stream.videoTracks[0];

    if(self.remoteVideoTrack) {
        [self.remoteVideoTrack removeRenderer:self.remoteView];
        self.remoteVideoTrack = nil;
        [self.remoteView renderFrame:nil];
    }
    
    self.remoteVideoTrack = remoteVideoTrack;
    [self.remoteVideoTrack addRenderer:self.remoteView];

}

-(void)serverRequiresPassword:(TLKSocketIOSignaling*)server{
    NSLog(@"serverRequiresPassword");
}
-(void)removedStream:(TLKMediaStream*)stream{
    NSLog(@"removedStream");
}
-(void)peer:(NSString*)peer toggledAudioMute:(BOOL)mute{
    NSLog(@"toggledAudioMute");
}
-(void)peer:(NSString*)peer toggledVideoMute:(BOOL)mute{
    NSLog(@"toggledVideoMute");
}
-(void)lockChange:(BOOL)locked{
    NSLog(@"locked");
}


#pragma mark - RTCEAGLVideoViewDelegate

-(void)videoView:(RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size {
    NSLog(@"videoView ?");
}


@end
