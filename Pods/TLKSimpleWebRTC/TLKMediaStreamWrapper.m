//
//  TLKMediaStreamWrapper.m
//  Copyright (c) 2014 &yet, LLC and TLKWebRTC contributors
//


#import "TLKMediaStreamWrapper.h"

@interface TLKMediaStreamWrapper ()
@property (readwrite) RTCMediaStream* stream;
@property (readwrite) NSString* peerID;
@property (readwrite) BOOL videoMuted;
@property (readwrite) BOOL audioMuted;
@end

@implementation TLKMediaStreamWrapper

@end
