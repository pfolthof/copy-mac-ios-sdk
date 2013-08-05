//
//  DMAppDelegate.h
//  DemoMobile
//
//  Created by PF Olthof on 05-08-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DMAppDelegate : UIResponder <UIApplicationDelegate>

@property (copy) NSURLRequest *(^filterRequestBlock)(NSURLRequest *filterURLRequest);

@property (strong, nonatomic) UIWindow *window;

@end
