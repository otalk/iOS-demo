//
//  ViewController.m
//  Copyright (c) 2014 &yet, LLC and otalk contributors
//

#import "ViewController.h"
#import "TLKSocketIOSignaling.h"
#import "TLKMediaStreamWrapper.h"
#import "TLKSocketIOSignalingDelegate.h"
#import "RTCVideoRenderer.h"
#import "RTCVideoTrack.h"
#import "RTCEAGLVideoView.h"
#import "RTCVideoCapturer.h"
#import "RTCVideoTrack.h"
#import "RTCMediaConstraints.h"
#import "RTCPeerConnectionFactory.h"

@interface ViewController () <TLKSocketIOSignalingDelegate, RTCVideoRenderer, RTCEAGLVideoViewDelegate>

@property (strong, nonatomic) TLKSocketIOSignaling* signaling;
@property (strong, nonatomic) UIView* renderView;
//@property (strong, nonatomic) RTCVideoRenderer* renderer;
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
    
    self.signaling = [[TLKSocketIOSignaling alloc] initAllowingVideo:YES];
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
    
	// Do any additional setup after loading the view, typically from a nib.
}



- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - TLKSocketIOSignalingDelegate

-(void)addedStream:(TLKMediaStreamWrapper *)stream {
    NSLog(@"addedStream");

    RTCVideoTrack *localVideoTrack = stream.stream.videoTracks[0];
    
    if(self.localVideoTrack) {
        [self.localVideoTrack removeRenderer:self.localView];
        self.localVideoTrack = nil;
        [self.localView renderFrame:nil];
    }
    
    self.localVideoTrack = localVideoTrack;
    [self.localVideoTrack addRenderer:self.localView];

}



-(void)serverRequiresPassword:(TLKSocketIOSignaling*)server{
    NSLog(@"serverRequiresPassword");
}
-(void)removedStream:(TLKMediaStreamWrapper*)stream{
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

#pragma mark - RTCVideoRenderer

-(void)renderFrame:(RTCI420Frame *)frame {
    NSLog(@"renderFrame ?");
    [self.remoteView renderFrame:frame];

}
-(void)setSize:(CGSize)size {
    NSLog(@"setSize ?");
}


@end
