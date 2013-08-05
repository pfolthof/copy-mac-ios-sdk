//
//  DMViewController.m
//  DemoMobile
//
//  Created by PF Olthof on 05-08-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#import "DMViewController.h"

#import "DMAppDelegate.h"

#import "CopySDK-iOS/CopySDK.h"

@interface DMViewController () <UIWebViewDelegate>

@end


@implementation DMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    DMAppDelegate *appDelegate = (DMAppDelegate *)[UIApplication sharedApplication].delegate;
    
    NSURLRequest *filteredRequest = appDelegate.filterRequestBlock(request);
    
    return filteredRequest != nil;
}

@end
