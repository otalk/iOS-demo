# TLKSimpleWebRTC

A iOS interface to connect to WebRTC sessions using a [Signalmaster](https://github.com/andyet/signalmaster) 
based signaling server using Socket.io.

Usage 
-----

See [otalk/iOS-demo](https://github.com/otalk/iOS-demo) for an example application using the interface.

**Build Environment**

We recommend pulling the open source code (TLKSimpleWebRTC, as well as TLKWebRTC - a small part of the project 
that is independent of the signaling server) and the precompiled iOS libraries via CocoaPods. 

Here's the Podfile that we use for that:

    target "ios-demo" do
    
	pod 'libjingle_peerconnection'
	pod 'TLKWebRTC', :git => 'https://github.com/otalk/TLKWebRTC.git'
	pod 'TLKSimpleWebRTC', :git => 'https://github.com/otalk/TLKSimpleWebRTC.git'

	end

**Connecting to the signaling server**

You can connect to the signaling server by allocating a TLKSocketIOSignaling object. You'll also need to set 
a delegate to receive messages from the signaling server.

    self.signaling = [[TLKSocketIOSignaling alloc] initWithVideo:YES];
    self.signaling.delegate = self;
    
To join a chat, you need to both connect to a server and join a room.

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
	

**Showing the video**

TLKSimpleWebRTC doesn't provide any interfaces for showing the video, but you can do it with the WebRTC Objective-C 
interface (headers included with the precompiled WebRTC libs). Create a RTCEAGLVideoView to render in response to delegate calls from TLKSocketIOSignaling.

	@interface ViewController () <TLKSocketIOSignalingDelegate, RTCEAGLVideoViewDelegate>
	@property (strong, nonatomic) RTCEAGLVideoView* remoteView;
	@end
	
	//...
	
	- (void)addedStream:(TLKMediaStream *)stream {
	    if (!self.remoteView) {
	        self.remoteView = [[RTCEAGLVideoView alloc] initWithFrame:CGRectMake(0, 0, 640, 480)];
	        self.remoteView.delegate = self;
	        [self.view addSubview:self.renderView];
        
	        [(RTCVideoTrack*)stream.stream.videoTracks[0] addRenderer:self.remoteView];
	    }
	}
