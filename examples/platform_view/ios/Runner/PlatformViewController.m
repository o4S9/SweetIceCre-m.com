// Copyright 2017, the Flutter project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

#import <Foundation/Foundation.h>
#import "PlatformViewController.h"

@interface PlatformViewController ()
@property (weak, nonatomic) IBOutlet UILabel *incrementLabel;
@end

@implementation PlatformViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setIncrementLabelText];
}

- (IBAction)handleIncrement:(id)sender {
    self.counter++;
    [self setIncrementLabelText];
}

- (IBAction)switchToFlutterView:(id)sender {

    [self dismissViewControllerAnimated:NO completion:^() {
       [self.delegate didUpdateCounter:self.counter];
    }];
}

- (void)setIncrementLabelText {
    NSString* text = [NSString stringWithFormat:@"Button tapped %d %@.",
                                                self.counter,
                                                (self.counter == 1)? @"time" : @"times"];
    self.incrementLabel.text = text;
}

@end



