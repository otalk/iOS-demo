//
//  TLKMediaStreamWrapper.h
//  Copyright (c) 2014 &yet, LLC and TLKWebRTC contributors
//

#import <Foundation/Foundation.h>

@class RTCMediaStream;

// Simple structure to hold the actual media stream an some useful associated data
// Contents of remoteMediaStreamWrappers in TLKSocketIOSignaling are of this type
@interface TLKMediaStreamWrapper : NSObject
@property (readonly) RTCMediaStream* stream;
@property (readonly) NSString* peerID;
@property (readonly) BOOL videoMuted;
@property (readonly) BOOL audioMuted;
@end
