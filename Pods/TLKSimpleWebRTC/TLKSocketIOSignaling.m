//
//  TLKSocketIOSignaling.m
//  Copyright (c) 2014 &yet, LLC and TLKWebRTC contributors
//


#import "TLKSocketIOSignaling.h"
#import "AZSocketIO.h"
#import "RTCMediaStream.h"
#import "RTCICEServer.h"
#import "RTCVideoTrack.h"
#import "RTCAudioTrack.h"
#import "TLKMediaStreamWrapper.h"
#import "TLKSocketIOSignalingDelegate.h"

// Need to be able to set these values from here, so duplicate the internal write properties from
// the implimentation. TODO: figure out a better way to handle this
@interface TLKMediaStreamWrapper ()
@property (readwrite) RTCMediaStream* stream;
@property (readwrite) NSString* peerID;
@property (readwrite) BOOL videoMuted;
@property (readwrite) BOOL audioMuted;
@end

@interface TLKSocketIOSignaling () {
    BOOL _localAudioMuted;
    BOOL _localVideoMuted;
}

@property (nonatomic, strong) AZSocketIO* socket;
@property (nonatomic, strong) TLKWebRTC* webRTC;

@property (nonatomic, readwrite) NSString* roomName;
@property (nonatomic, readwrite) NSString* roomKey;

@property (strong, readwrite, nonatomic) RTCMediaStream* localMediaStream;
@property (strong, readwrite, nonatomic) NSArray* remoteMediaStreamWrappers;

@property (strong, nonatomic) NSMutableSet* currentClients;

@end


@implementation TLKSocketIOSignaling

- (id)initAllowingVideo:(BOOL)allowVideo {
    self = [super init];
    if (self) {
        self->_allowVideo = allowVideo;
        self.currentClients = [[NSMutableSet alloc] init];
    }
    return self;
}


- (BOOL)roomIsLocked {
    return [self.roomKey length] > 0;
}

+ (NSSet*)keyPathsForValuesAffectingRoomIsLocked {
    return [NSSet setWithObject:@"roomKey"];
}

-(void)connectToServer:(NSString*)apiServer success:(void(^)(void))successCallback failure:(void(^)(NSError*))failureCallback {
    [self connectToServer:apiServer port:8888 secure:YES success:successCallback failure:failureCallback];
}

-(void)connectToServer:(NSString*)apiServer port:(int)port secure:(BOOL)secure success:(void(^)(void))successCallback failure:(void(^)(NSError*))failureCallback {
    
    if (self.socket) {
        [self disconnectSocket];
    }
    
    __weak TLKSocketIOSignaling* weakSelf = self;

    self.socket = [[AZSocketIO alloc] initWithHost:apiServer andPort:[NSString stringWithFormat:@"%d",port] secure:secure];

    NSString* originURL = [NSString stringWithFormat:@"https://%@:%d", apiServer, port];
    [self.socket setValue:originURL forHTTPHeaderField:@"Origin"];

    self.socket.messageRecievedBlock = ^(id data) { [weakSelf messageReceived:data]; };
    self.socket.eventRecievedBlock = ^(NSString* eventName, id data) { [weakSelf eventReceived:eventName withData:data]; };
    self.socket.disconnectedBlock = ^() { [weakSelf socketDisconnected]; };
    self.socket.errorBlock = ^(NSError* error) { [weakSelf socketReceivedError:error]; };
    
    self.socket.reconnectionLimit = 5.0f;
    
    
    [self.socket connectWithSuccess:^{
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            if (!weakSelf.webRTC) {
                weakSelf.webRTC = [[TLKWebRTC alloc] initAllowingVideo:weakSelf.allowVideo != 0];
                [weakSelf.webRTC setSignalDelegate:weakSelf];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.localMediaStream = weakSelf.webRTC.localMediaStream;
                
                if (successCallback) {
                    successCallback();
                }
            });
        });
    } andFailure:^(NSError *error) {
        NSLog(@"Failed to connect socket.io: %@", error);
        if (failureCallback) {
            failureCallback(error);
        }
    }];
 }

-(void)disconnectSocket {
    [self.socket disconnect];
    self.socket = nil;
}

-(TLKMediaStreamWrapper*)streamWrapperForIdentifier:(NSString*)peerIdentifier {
    __block TLKMediaStreamWrapper* found = nil;
    
    [self.remoteMediaStreamWrappers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if([((TLKMediaStreamWrapper*)obj).peerID isEqualToString:peerIdentifier]) {
            found = obj;
            *stop = YES;
        }
    }];
    
    return found;
}

-(void)peerDisconnectedForID:(NSString*)peerID {
    NSMutableArray* mutable = [self.remoteMediaStreamWrappers mutableCopy];
    NSMutableIndexSet* toRemove = [NSMutableIndexSet new];
    
    [mutable enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if([((TLKMediaStreamWrapper*)obj).peerID isEqualToString:peerID]) {
            [toRemove addIndex:idx];
        }
    }];
    
    NSArray* objects = [self.remoteMediaStreamWrappers objectsAtIndexes:toRemove];
    
    [mutable removeObjectsAtIndexes:toRemove];
    
    self.remoteMediaStreamWrappers = mutable;
    
    if([self.delegate respondsToSelector:@selector(removedStream:)]) {
        for(TLKMediaStreamWrapper* wrapper in objects) {
            [self.delegate removedStream:wrapper];
        }
    }
}

-(void)joinRoom:(NSString*)room withKey:(NSString*)key success:(void(^)(void))successCallback failure:(void(^)(void))failureCallback {
    NSError* error;
    id args;
    if (key) {
        args = @{@"name": room, @"key": key};
    } else {
        args = room;
    }
    [self.socket emit:@"join" args:args error:&error ackWithArgs:^(NSArray *data) {
        if (data[0] == [NSNull null]) {
            NSDictionary* clients = data[1][@"clients"];
            
            [[clients allKeys] enumerateObjectsUsingBlock:^(id peerID, NSUInteger idx, BOOL *stop) {
                [self.webRTC addPeerConnectionForID:peerID];
                [self.webRTC createOfferForPeerWithID:peerID];
                
                [self.currentClients addObject:peerID];
            }];
            
            self.roomName = room;
            self.roomKey = key;
            
            if(successCallback) {
                successCallback();
            }
        } else {
            NSLog(@"Error: %@", data[0]);
            failureCallback();
        }
    }];
    if(error) {
        NSLog(@"Error: %@", error);
        failureCallback();
    }
}

-(void)joinRoom:(NSString*)room success:(void(^)(void))successCallback failure:(void(^)(void))failureCallback {
    [self joinRoom:room withKey:nil success:successCallback failure:failureCallback];
}

-(void)leaveRoom {
    [[self.currentClients allObjects] enumerateObjectsUsingBlock:^(id peerID, NSUInteger idx, BOOL *stop) {
        [self.webRTC removePeerConnectionForID:peerID];
        [self peerDisconnectedForID:peerID];
    }];
    
    self.currentClients = [[NSMutableSet alloc] init];
    
    [self disconnectSocket];
}

-(void)lockRoomWithKey:(NSString*)key success:(void(^)(void))successCallback failure:(void(^)(void))failureCallback {
    NSError* error;
    [self.socket emit:@"lockRoom" args:key error:&error ackWithArgs:^(NSArray *data) {
        if (data[0] == [NSNull null]) {
            if(successCallback) {
                successCallback();
            }
        } else {
            NSLog(@"Error: %@", data[0]);
            if(failureCallback) {
                failureCallback();
            }
        }
    }];
    if(error) {
        NSLog(@"Error: %@", error);
        if(failureCallback) {
            failureCallback();
        }
    }
}

-(void)unlockRoomWithSuccess:(void(^)(void))successCallback failure:(void(^)(void))failureCallback {
    NSError* error;
    [self.socket emit:@"unlockRoom" args:nil error:&error ackWithArgs:^(NSArray *data) {
        if (data[0] == [NSNull null]) {
            if(successCallback) {
                successCallback();
            }
        } else {
            NSLog(@"Error: %@", data[0]);
            if(failureCallback) {
                failureCallback();
            }
        }
    }];
    if(error) {
        NSLog(@"Error: %@", error);
        if(failureCallback) {
            failureCallback();
        }
    }
}

#pragma mark - SocketIO methods

- (void)messageReceived:(id)data {
}

- (void)eventReceived:(NSString*)eventName withData:(id)data {
    NSDictionary* dictionary;
    
    if ([eventName isEqualToString:@"locked"]) {
        self.roomKey = (NSString*)[data objectAtIndex:0];
        if([self.delegate respondsToSelector:@selector(lockChange:)]) {
            [self.delegate lockChange:TRUE];
        }
    } else if ([eventName isEqualToString:@"unlocked"]) {
        self.roomKey = nil;
        if([self.delegate respondsToSelector:@selector(lockChange:)]) {
            [self.delegate lockChange:FALSE];
        }
    } else if ([eventName isEqualToString:@"passwordRequired"]) {
        if([self.delegate respondsToSelector:@selector(serverRequiresPassword:)]) {
            [self.delegate serverRequiresPassword:self];
        }
    } else if ([eventName isEqualToString:@"stunservers"] || [eventName isEqualToString:@"turnservers"]) {
        NSArray* serverList = data[0];
        for(NSDictionary* info in serverList) {
            NSString* username = info[@"username"] ? info[@"username"] : @"";
            NSString* password = info[@"credential"] ? info[@"credential"] : @"";
            RTCICEServer* server = [[RTCICEServer alloc] initWithURI:[NSURL URLWithString:info[@"url"]] username:username password:password];
            [self.webRTC addICEServer:server];
        }
    } else {
        dictionary = data[0];
        
        if(![dictionary isKindOfClass:[NSDictionary class]]) {
            dictionary = nil;
        }
    }
    
    if ([dictionary[@"type"] isEqualToString:@"iceFailed"]) {
        [[[UIAlertView alloc] initWithTitle:@"Connection Failed" message:@"Talky could not establish a connection to a participant in this chat. Please try again later." delegate:nil cancelButtonTitle:@"Continue" otherButtonTitles:nil] show];
    } else if ([dictionary[@"type"] isEqualToString:@"candidate"]) {
        
        RTCICECandidate* candidate = [[RTCICECandidate alloc] initWithMid:dictionary[@"payload"][@"candidate"][@"sdpMid"]
                                                                    index:[dictionary[@"payload"][@"candidate"][@"sdpMLineIndex"] integerValue]
                                                                      sdp:dictionary[@"payload"][@"candidate"][@"candidate"]];
        
        [self.webRTC addICECandidate:candidate forPeerWithID:dictionary[@"from"]];
        
        
        
    } else if ([dictionary[@"type"] isEqualToString:@"answer"]) {
        
        RTCSessionDescription* remoteSDP = [[RTCSessionDescription alloc] initWithType:dictionary[@"payload"][@"type"]
                                                                                   sdp:dictionary[@"payload"][@"sdp"]];
        
        [self.webRTC setRemoteDescription:remoteSDP forPeerWithID:dictionary[@"from"] receiver:NO];
        
    } else if ([dictionary[@"type"] isEqualToString:@"offer"]) {
        
        [self.webRTC addPeerConnectionForID:dictionary[@"from"]];
        [self.currentClients addObject:dictionary[@"from"]];
        
        // Fix for browser-to-app connection crash using beta API.
        NSString* origSDP = dictionary[@"payload"][@"sdp"];
        NSError* error;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"m=application \\d+ DTLS/SCTP 5000 *"
                                                                               options:0
                                                                                 error:&error];
        
        NSString* sdp = [regex stringByReplacingMatchesInString:origSDP options:0 range:NSMakeRange(0, [origSDP length]) withTemplate:@"m=application 0 DTLS/SCTP 5000"];
        
        RTCSessionDescription* remoteSDP = [[RTCSessionDescription alloc] initWithType:dictionary[@"payload"][@"type"]
                                                                                   sdp:sdp];
        
        [self.webRTC setRemoteDescription:remoteSDP forPeerWithID:dictionary[@"from"] receiver:YES];
        
    } else if ([eventName isEqualToString:@"remove"]) {
        
        [self.webRTC removePeerConnectionForID:dictionary[@"id"]];
        [self peerDisconnectedForID:dictionary[@"id"]];
        
        [self.currentClients removeObject:dictionary[@"id"]];
        
    } else if ([dictionary[@"payload"][@"name"] isEqualToString:@"audio"]) {
        TLKMediaStreamWrapper* stream = [self streamWrapperForIdentifier:dictionary[@"from"]];
        stream.audioMuted = [dictionary[@"type"] isEqualToString:@"mute"];
        if([self.delegate respondsToSelector:@selector(peer:toggledAudioMute:)]) {
            [self.delegate peer:dictionary[@"from"] toggledAudioMute:stream.audioMuted];
        }
    } else if ([dictionary[@"payload"][@"name"] isEqualToString:@"video"]) {
        TLKMediaStreamWrapper* stream = [self streamWrapperForIdentifier:dictionary[@"from"]];
        stream.videoMuted = [dictionary[@"type"] isEqualToString:@"mute"];
        if([self.delegate respondsToSelector:@selector(peer:toggledVideoMute:)]) {
            [self.delegate peer:dictionary[@"from"] toggledVideoMute:stream.videoMuted];
        }
    }
}

- (void)socketDisconnected {
}

- (void)socketReceivedError:(NSError*)error {
}

#pragma mark - TLKSignalDelegate methods

- (void)sendICECandidate:(RTCICECandidate *)candidate forPeerWithID:(NSString *)peerID {
    NSDictionary* args = @{@"to": peerID,
                           @"roomType": @"video",
                           @"type": @"candidate",
                           @"payload": @{ @"candidate" : @{@"sdpMid": candidate.sdpMid,
                                                           @"sdpMLineIndex": [NSString stringWithFormat:@"%d", candidate.sdpMLineIndex],
                                                           @"candidate": candidate.sdp}}};
    NSError* error;
    [self.socket emit:@"message" args:@[args] error:&error];
}

- (void)sendSDPOffer:(RTCSessionDescription *)offer forPeerWithID:(NSString *)peerID {
    NSDictionary* args = @{@"to": peerID,
                           @"roomType": @"video",
                           @"type": offer.type,
                           @"payload": @{@"type": offer.type, @"sdp": offer.description}};
    NSError* error;
    [self.socket emit:@"message" args:@[args] error:&error];
}

- (void)sendSDPAnswer:(RTCSessionDescription *)answer forPeerWithID:(NSString *)peerID {
    NSDictionary* args = @{@"to": peerID,
                           @"roomType": @"video",
                           @"type": answer.type,
                           @"payload": @{@"type": answer.type, @"sdp": answer.description}};
    NSError* error;
    [self.socket emit:@"message" args:@[args] error:&error];
}

- (void)ICEConnectionStateChanged:(RTCICEConnectionState)state forPeerWithID:(NSString*)peerID {
    if((state == RTCICEConnectionConnected) || (state == RTCICEConnectionClosed)) {
        [self broadcastMuteStates];
    }
    else if (state == RTCICEConnectionFailed) {
        NSDictionary* args = @{@"to": peerID,
                               @"type": @"iceFailed"};
        NSError* error;
        [self.socket emit:@"message" args:@[args] error:&error];
        [[[UIAlertView alloc] initWithTitle:@"Connection Failed" message:@"Talky could not establish a connection to a participant in this chat. Please try again later." delegate:nil cancelButtonTitle:@"Continue" otherButtonTitles:nil] show];
    }
}

#pragma mark - TLKStreamDelegate methods

- (void)addedStream:(RTCMediaStream *)stream forPeerWithID:(NSString *)peerID {
    TLKMediaStreamWrapper* wrapper = [TLKMediaStreamWrapper new];
    wrapper.stream = stream;
    wrapper.peerID = peerID;
    
    if(!self.remoteMediaStreamWrappers) {
        self.remoteMediaStreamWrappers = @[wrapper];
    }
    else {
        self.remoteMediaStreamWrappers = [self.remoteMediaStreamWrappers arrayByAddingObject:wrapper];
    }
    
    if([self.delegate respondsToSelector:@selector(addedStream:)]) {
        [self.delegate addedStream:wrapper];
    }
}

- (void)removedStream:(RTCMediaStream *)stream forPeerWithID:(NSString *)peerID {
    NSMutableArray* mutable = [self.remoteMediaStreamWrappers mutableCopy];
    NSMutableIndexSet* toRemove = [NSMutableIndexSet new];
    
    [mutable enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if(((TLKMediaStreamWrapper*)obj).stream == stream) {
            [toRemove addIndex:idx];
        }
    }];
    
    NSArray* objects = [self.remoteMediaStreamWrappers objectsAtIndexes:toRemove];
    
    [mutable removeObjectsAtIndexes:toRemove];
    
    self.remoteMediaStreamWrappers = mutable;
    
    if([self.delegate respondsToSelector:@selector(removedStream:)]) {
        for(TLKMediaStreamWrapper* wrapper in objects) {
            [self.delegate removedStream:wrapper];
        }
    }
}

#pragma mark - Mute/Unmute Status

-(void)sendMuteMessagesForTrack:(NSString*)trackString mute:(BOOL)mute {
    NSError* error;

    for (NSString* peerID in self.currentClients) {
        [self.socket emit:@"message"
                     args:@{@"to":peerID,
                            @"type" : mute ? @"mute" : @"unmute",
                            @"payload": @{@"name":trackString}}
                    error:&error];
    }
}

-(BOOL)localAudioMuted {
    if(self.localMediaStream.audioTracks.count) {
        RTCAudioTrack* audioTrack = self.localMediaStream.audioTracks[0];
        return !audioTrack.isEnabled;
    }
    
    return YES;
}

-(void)setLocalAudioMuted:(BOOL)localAudioMuted {
    if(self.localMediaStream.audioTracks.count) {
        RTCAudioTrack* audioTrack = self.localMediaStream.audioTracks[0];
        [audioTrack setEnabled:!localAudioMuted];
        [self sendMuteMessagesForTrack:@"audio" mute:localAudioMuted];
    }
}

-(BOOL)localVideoMuted {
    if(self.localMediaStream.videoTracks.count) {
        RTCVideoTrack* videoTrack = self.localMediaStream.videoTracks[0];
        return !videoTrack.isEnabled;
    }
    
    return YES;
}

-(void)setLocalVideoMuted:(BOOL)localVideoMuted {
    if(self.localMediaStream.videoTracks.count) {
        RTCVideoTrack* videoTrack = self.localMediaStream.videoTracks[0];
        [videoTrack setEnabled:!localVideoMuted];
        [self sendMuteMessagesForTrack:@"video" mute:localVideoMuted];
    }
}

-(void)broadcastMuteStates {
    [self sendMuteMessagesForTrack:@"audio" mute:self.localAudioMuted];
    [self sendMuteMessagesForTrack:@"video" mute:self.localVideoMuted];
}

@end
