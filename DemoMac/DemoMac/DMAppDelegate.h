//
//  DMAppDelegate.h
//  DemoMac
//
//  Created by PF Olthof on 30-07-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface DMAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet WebView *webView;

@end
