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

@interface ViewController () <TLKSocketIOSignalingDelegate>

@property (strong, nonatomic) TLKSocketIOSignaling* signaling;
@property (strong, nonatomic) UIView* renderView;
@property (strong, nonatomic) RTCVideoRenderer* renderer;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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

-(void)addedStream:(TLKMediaStreamWrapper *)stream {
    if(!self.renderView) {
        self.renderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 480, 640)];
        self.renderView.layer.transform = CATransform3DMakeScale(1, -1, 1);
        
        self.renderer = [[RTCVideoRenderer alloc] initWithView:self.renderView];
        [self.view addSubview:self.renderView];
        
        [(RTCVideoTrack*)stream.stream.videoTracks[0] addRenderer:self.renderer];
        [self.renderer start];
    }
}

@end
