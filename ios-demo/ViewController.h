//
//  ViewController.h
//  Copyright (c) 2014 &yet, LLC and otalk contributors
//

#import <UIKit/UIKit.h>

@class TLKMediaStreamWrapper;

@interface ViewController : UIViewController

-(void)addedStream:(TLKMediaStreamWrapper *)stream;

@end
