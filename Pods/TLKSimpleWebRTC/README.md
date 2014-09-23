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
    
	pod 'webrtc-ios', :git => 'https://github.com/otalk/webrtc-ios.git'
	pod 'TLKWebRTC', :git => 'https://github.com/otalk/TLKWebRTC.git'
	pod 'TLKSimpleWebRTC', :git => 'https://github.com/otalk/TLKSimpleWebRTC.git'

	end

	post_install do |installer_representation|
	    installer_representation.project.targets.each do |target|
	        target.build_configurations.each do |config|
	            config.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
	        end
	    end
	end

The post_install hook forces the libraries to build in armv7 mode, which is required by the WebRTC libraries. 
You also need to go and set the same flag in you app project. In the project build settings, you should set 
"Build Active Architecture Only" to "No" for the Debug build (by default it is only set for release), and also
 set the "Architectures" to "armv7" only (default is all three). 

**Connecting to the signaling server**

You can connect to the signaling server by allocating a TLKSocketIOSignaling object. You'll also need to set 
a delegate to receive messages from the signaling server.

    self.signaling = [[TLKSocketIOSignaling alloc] initAllowingVideo:YES];
    self.signaling.delegate = self;
    
To join a chat, you need to both connect to a server and join a room.

    [self.signaling connectToServer:@"signaling.simplewebrtc.com" port:8888 secure:NO success:^{
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
interface (headers included with the precompiled WebRTC libs). Create a UIView to render to and an RTCVideoRenderer 
to handle the processing in response to delegate calls from TLKSocketIOSignaling.

	@interface ViewController () <TLKSocketIOSignalingDelegate>
	@property (strong, nonatomic) RTCVideoRenderer* renderer;
	@end
	
	//...
	
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
