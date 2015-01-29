//
//  ViewController.m
//  Copyright (c) 2014 &yet, LLC and otalk contributors
//

#import "ViewController.h"
#import "TLKMediaStreamWrapper.h"
#import "RTCMediaStream.h"
#import "RTCVideoRenderer.h"
#import "RTCVideoTrack.h"

@interface ViewController ()

@property (strong, nonatomic) UIView* renderView;
@property (strong, nonatomic) RTCVideoRenderer* renderer;
@end

@implementation ViewController

-(void)addedStream:(TLKMediaStreamWrapper *)stream {
    if(!self.renderView) {
        self.renderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 480, 640)];
        self.renderView.layer.transform = CATransform3DMakeScale(1, -1, 1);
        
        self.renderer = [[RTCVideoRenderer alloc] initWithView:self.renderView];
        [self.view insertSubview:self.renderView atIndex:0];
        
        [(RTCVideoTrack*)stream.stream.videoTracks[0] addRenderer:self.renderer];
        [self.renderer start];
    }
}

@end
