//
//  FirstViewController.m
//  ios-demo
//

#import "FirstViewController.h"
#import "TLKSocketIOSignaling.h"
#import "TLKSocketIOSignalingDelegate.h"
#import "ViewController.h"

@interface FirstViewController () <TLKSocketIOSignalingDelegate>

@property (nonatomic, weak) IBOutlet UITextField *textField;
@property (nonatomic, strong) TLKSocketIOSignaling* signaling;
@property (nonatomic, weak) ViewController* viewController;

@end

@implementation FirstViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.signaling = [[TLKSocketIOSignaling alloc] initAllowingVideo:YES];
    self.signaling.delegate = self;
}

- (IBAction)go:(id)sender {
    __weak FirstViewController* weakSelf = self;
    [self.signaling connectToServer:@"signaling.simplewebrtc.com" port:80 secure:NO success:^{
        FirstViewController* strongSelf = weakSelf;
        [strongSelf.signaling joinRoom:strongSelf.textField.text success:^{
            FirstViewController* strongSelf = weakSelf;
            [strongSelf performSegueWithIdentifier:@"modalSegue" sender:nil];
        } failure:^{
            NSLog(@"join failure");
        }];
        NSLog(@"connect success");
    } failure:^(NSError* error){
        NSLog(@"connect failure");
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"modalSegue"]) {
        self.viewController = (ViewController*)segue.destinationViewController;
    }
}

- (IBAction)unwindToFirstViewController:(UIStoryboardSegue*)segue {
    [self.signaling leaveRoom];
}

- (void)addedStream:(TLKMediaStreamWrapper *)stream {
    [self.viewController addedStream:stream];
}

@end
