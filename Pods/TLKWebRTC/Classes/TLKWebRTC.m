//
//  TLKWebRTC.m
//  Copyright (c) 2014 &yet, LLC and TLKWebRTC contributors
//

#import "TLKWebRTC.h"

#import <AVFoundation/AVFoundation.h>
#import "RTCPeerConnectionFactory.h"
#import "RTCPeerConnection.h"
#import "RTCICEServer.h"
#import "RTCPair.h"
#import "RTCMediaConstraints.h"
#import "RTCSessionDescription.h"
#import "RTCSessionDescriptionDelegate.h"
#import "RTCPeerConnectionDelegate.h"

#import "RTCAudioTrack.h"
#import "RTCVideoCapturer.h"
#import "RTCVideoSource.h"
#import "RTCVideoTrack.h"

@interface TLKWebRTC () <RTCSessionDescriptionDelegate, RTCPeerConnectionDelegate>

@property (readwrite, nonatomic) RTCMediaStream* localMediaStream;
@property (nonatomic, strong) RTCPeerConnectionFactory* peerFactory;
@property (nonatomic, strong) NSMutableDictionary* peerConnections;
@property (nonatomic, strong) NSMutableDictionary* peerToRoleMap;
@property (nonatomic, strong) NSMutableDictionary* peerToICEMap;

@property BOOL allowVideo;

@property (nonatomic, strong) NSMutableArray* iceServers;

@end

NSString* const TLKPeerConnectionRoleInitiator = @"TLKPeerConnectionRoleInitiator";
NSString* const TLKPeerConnectionRoleReceiver = @"TLKPeerConnectionRoleReceiver";

@implementation TLKWebRTC

- (id)initAllowingVideo:(BOOL)allowVideo {
    self = [super init];
    if (self) {
        self.allowVideo = allowVideo;
        [self commonSetup];
    }
    return self;
}

- (id)init {
    self = [super init];
    if (self) {
        self.allowVideo = YES;
        [self commonSetup];
    }
    return self;
}

- (void)commonSetup {
    _peerFactory = [[RTCPeerConnectionFactory alloc] init];
    _peerConnections = [NSMutableDictionary dictionary];
    _peerToRoleMap = [NSMutableDictionary dictionary];
    _peerToICEMap = [NSMutableDictionary dictionary];
    
    self.iceServers = [NSMutableArray new];
    
    RTCICEServer* defaultStunServer = [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:@"stun:stun.l.google.com:19302"] username:@"" password:@""];
    [self.iceServers addObject:defaultStunServer];
    
    [RTCPeerConnectionFactory initializeSSL];
    
    [self initLocalStream];
}

- (void)addICEServer:(RTCICEServer*)server {
    bool isStun = [server.URI.scheme isEqualToString:@"stun"];
    
    if (isStun) {
        // Array of servers is always stored with stun server in first index, and we only want one,
        // so if this is a stun server, replace it
        [self.iceServers replaceObjectAtIndex:0 withObject:server];
    }
    else {
        [self.iceServers addObject:server];
    }
}

-(NSString*)identifierForPeer:(RTCPeerConnection*)peer {
    NSArray* keys = [self.peerConnections allKeysForObject:peer];
    return (keys.count == 0) ? nil : keys[0];
}

#pragma mark - Add/remove peerConnections

- (void)addPeerConnectionForID:(NSString*)identifier {
    RTCPeerConnection* peer = [self.peerFactory peerConnectionWithICEServers:[self iceServers] constraints:[self mediaConstraints] delegate:self];
    [peer addStream:self.localMediaStream];
    [self.peerConnections setObject:peer forKey:identifier];
}

- (void)removePeerConnectionForID:(NSString*)identifier {
    RTCPeerConnection* peer = self.peerConnections[identifier];
    [self.peerConnections removeObjectForKey:identifier];
    [self.peerToRoleMap removeObjectForKey:identifier];
    [peer close];
}

#pragma mark -

- (void)createOfferForPeerWithID:(NSString*)peerID {
    RTCPeerConnection* peerConnection = [self.peerConnections objectForKey:peerID];
    [self.peerToRoleMap setObject:TLKPeerConnectionRoleInitiator forKey:peerID];
    [peerConnection createOfferWithDelegate:self constraints:[self mediaConstraints]];
}

- (void)setRemoteDescription:(RTCSessionDescription*)remoteSDP forPeerWithID:(NSString*)peerID receiver:(BOOL)isReceiver {
    RTCPeerConnection* peerConnection = [self.peerConnections objectForKey:peerID];
    if (isReceiver) {
        [self.peerToRoleMap setObject:TLKPeerConnectionRoleReceiver forKey:peerID];
    }
    [peerConnection setRemoteDescriptionWithDelegate:self sessionDescription:remoteSDP];
}

- (void)addICECandidate:(RTCICECandidate*)candidate forPeerWithID:(NSString*)peerID {
    RTCPeerConnection* peerConnection = [self.peerConnections objectForKey:peerID];
    if (peerConnection.iceGatheringState == RTCICEGatheringNew) {
        NSMutableArray* candidates = [self.peerToICEMap objectForKey:peerID];
        if (!candidates) {
            candidates = [NSMutableArray array];
            [self.peerToICEMap setObject:candidates forKey:peerID];
        }
        [candidates addObject:candidate];
    } else {
        [peerConnection addICECandidate:candidate];
    }
}

#pragma mark - RTCSessionDescriptionDelegate method

// Note: all these delegate calls come back on a random background thread inside WebRTC,
// so all are bridged across to the main thread

- (void)peerConnection:(RTCPeerConnection*)peerConnection didCreateSessionDescription:(RTCSessionDescription*)sdp error:(NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        RTCSessionDescription* sessionDescription = [[RTCSessionDescription alloc] initWithType:sdp.type sdp:sdp.description];        
        [peerConnection setLocalDescriptionWithDelegate:self sessionDescription:sessionDescription];
    });
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection didSetSessionDescriptionWithError:(NSError*)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (peerConnection.iceGatheringState == RTCICEGatheringGathering) {
            NSArray* keys = [self.peerConnections allKeysForObject:peerConnection];
            if ([keys count] > 0) {
                NSArray* candidates = [self.peerToICEMap objectForKey:keys[0]];
                for (RTCICECandidate* candidate in candidates) {
                    [peerConnection addICECandidate:candidate];
                }
                [self.peerToICEMap removeObjectForKey:keys[0]];
            }
        }
        
        if (peerConnection.signalingState == RTCSignalingHaveLocalOffer) {
            NSArray* keys = [self.peerConnections allKeysForObject:peerConnection];
            if ([keys count] > 0) {
                [self.signalDelegate sendSDPOffer:peerConnection.localDescription forPeerWithID:keys[0]];
            }
        } else if (peerConnection.signalingState == RTCSignalingHaveRemoteOffer) {
            [peerConnection createAnswerWithDelegate:self constraints:[self mediaConstraints]];
        } else if (peerConnection.signalingState == RTCSignalingStable) {
            NSArray* keys = [self.peerConnections allKeysForObject:peerConnection];
            if ([keys count] > 0) {
                NSString* role = [self.peerToRoleMap objectForKey:keys[0]];
                if (role == TLKPeerConnectionRoleReceiver) {
                    [self.signalDelegate sendSDPAnswer:peerConnection.localDescription forPeerWithID:keys[0]];
                }
            }
        }
    });
}

#pragma mark - String utilities

- (NSString*)stringForSignalingState:(RTCSignalingState)state {
    switch (state) {
        case RTCSignalingStable:
            return @"Stable";
            break;
        case RTCSignalingHaveLocalOffer:
            return @"Have Local Offer";
            break;
        case RTCSignalingHaveRemoteOffer:
            return @"Have Remote Offer";
            break;
        case RTCSignalingClosed:
            return @"Closed";
            break;
        default:
            return @"Other state";
            break;
    }
}

- (NSString*)stringForConnectionState:(RTCICEConnectionState)state {
    switch (state) {
        case RTCICEConnectionNew:
            return @"New";
            break;
        case RTCICEConnectionChecking:
            return @"Checking";
            break;
        case RTCICEConnectionConnected:
            return @"Connected";
            break;
        case RTCICEConnectionCompleted:
            return @"Completed";
            break;
        case RTCICEConnectionFailed:
            return @"Failed";
            break;
        case RTCICEConnectionDisconnected:
            return @"Disconnected";
            break;
        case RTCICEConnectionClosed:
            return @"Closed";
            break;
        default:
            return @"Other state";
            break;
    }
}

- (NSString*)stringForGatheringState:(RTCICEGatheringState)state {
    switch (state) {
        case RTCICEGatheringNew:
            return @"New";
            break;
        case RTCICEGatheringGathering:
            return @"Gathering";
            break;
        case RTCICEGatheringComplete:
            return @"Complete";
            break;
        default:
            return @"Other state";
            break;
    }
}

#pragma mark - RTCPeerConnectionDelegate methods

// Note: all these delegate calls come back on a random background thread inside WebRTC,
// so all are bridged across to the main thread

- (void)peerConnectionOnError:(RTCPeerConnection *)peerConnection {
    dispatch_async(dispatch_get_main_queue(), ^{
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection signalingStateChanged:(RTCSignalingState)stateChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        // I'm seeing this, but not sure what to do with it yet
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection addedStream:(RTCMediaStream *)stream {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.signalDelegate addedStream:stream forPeerWithID:[self identifierForPeer:peerConnection]];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection removedStream:(RTCMediaStream *)stream {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.signalDelegate removedStream:stream forPeerWithID:[self identifierForPeer:peerConnection]];
    });
}

- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    dispatch_async(dispatch_get_main_queue(), ^{
        //    [self.peerConnection createOfferWithDelegate:self constraints:[self mediaConstraints]];
        // Is this delegate called when creating a PC that is going to *receive* an offer and return an answer?
        NSLog(@"peerConnectionOnRenegotiationNeeded ?");
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceConnectionChanged:(RTCICEConnectionState)newState {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.signalDelegate ICEConnectionStateChanged:newState forPeerWithID:[self identifierForPeer:peerConnection]];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceGatheringChanged:(RTCICEGatheringState)newState {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"peerConnection iceGatheringChanged?");
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection gotICECandidate:(RTCICECandidate *)candidate {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSArray* keys = [self.peerConnections allKeysForObject:peerConnection];
        if ([keys count] > 0) {
            [self.signalDelegate sendICECandidate:candidate forPeerWithID:keys[0]];
        }
    });
}

-(void)peerConnection:(RTCPeerConnection *)peerConnection didOpenDataChannel:(RTCDataChannel *)dataChannel {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"peerConnection didOpenDataChannel?");
    });
}

#pragma mark -

- (RTCMediaConstraints*)mediaConstraints {
    RTCPair* audioConstraint = [[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"];
    RTCPair* videoConstraint = [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:self.allowVideo ? @"true" : @"false"];
    RTCPair* sctpConstraint = [[RTCPair alloc] initWithKey:@"internalSctpDataChannels" value:@"true"];
    RTCPair* dtlsConstraint = [[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"];
    
    return [[RTCMediaConstraints alloc] initWithMandatoryConstraints:@[audioConstraint, videoConstraint] optionalConstraints:@[sctpConstraint, dtlsConstraint]];
}

- (void)initLocalStream {
    self.localMediaStream = [self.peerFactory mediaStreamWithLabel:[[NSUUID UUID] UUIDString]];
    
    RTCAudioTrack* audioTrack = [self.peerFactory audioTrackWithID:[[NSUUID UUID] UUIDString]];
    [self.localMediaStream addAudioTrack:audioTrack];
    
    if(self.allowVideo) {
        AVCaptureDevice* device = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] lastObject];
        RTCVideoCapturer* capturer = [RTCVideoCapturer capturerWithDeviceName:[device localizedName]];
        RTCVideoSource *videoSource = [self.peerFactory videoSourceWithCapturer:capturer constraints:nil];
        RTCVideoTrack* videoTrack = [self.peerFactory videoTrackWithID:[[NSUUID UUID] UUIDString] source:videoSource];
        [self.localMediaStream addVideoTrack:videoTrack];
    }
}

@end
