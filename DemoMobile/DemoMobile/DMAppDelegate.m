//
//  DMAppDelegate.m
//  DemoMobile
//
//  Created by PF Olthof on 05-08-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//


#import "DMAppDelegate.h"

#import "DMViewController.h"

#import "CopySDK-iOS/CopySDK.h"


@interface DMAppDelegate ()

@property COCopyClient *theCopyClient; // naming this property copyClient would trigger ARC errors

@end


@implementation DMAppDelegate

- (void)openURLInBrowser:(NSURL *)url {
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    
    DMViewController *viewController = (DMViewController *)self.window.rootViewController;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [viewController.webView loadRequest:urlRequest];
    });
}

- (void)showAndModifyUserInfo {
    __weak DMAppDelegate *weakSelf = self;
    
    [self.theCopyClient requestUserInfoWithCompletionBlock:^(BOOL success, NSError *error, NSDictionary *userInfo) {
        NSLog(@"success: %d, error: %@, user info: %@", success, error, userInfo);
        NSLog(@"first_name: %@", userInfo[@"first_name"]);
        
        NSString *firstName = userInfo[@"first_name"];
        
        [weakSelf.theCopyClient updateUserInfo:@{@"first_name":@"X"} withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *userInfo) {
            NSLog(@"success: %d, error: %@, user info: %@", success, error, userInfo);
            NSLog(@"first_name: %@", userInfo[@"first_name"]);
            
            [weakSelf.theCopyClient updateUserInfo:@{@"first_name":firstName} withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *userInfo) {
                NSLog(@"success: %d, error: %@, user info: %@", success, error, userInfo);
                NSLog(@"first_name: %@", userInfo[@"first_name"]);
            }];
        }];
        
    }];
}

- (void)showFileSystemInfo {
    [self.theCopyClient requestFileSystemInfoWithCompletionBlock:^(BOOL success, NSError *error, NSDictionary *fileSystemInfo) {
        NSLog(@"success: %d, error: %@, filesystem info: %@", success, error, fileSystemInfo);
    }];
}

- (void)listFilesAndShowActivity {
    __weak DMAppDelegate *weakSelf = self;
    
    NSString *path = @"/";
    
    [self.theCopyClient requestFileSystemListingForPath:path withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *fileSystemListing) {
        NSLog(@"success: %d, error: %@, filesystem listing: %@", success, error, fileSystemListing);
        
        NSArray *children = fileSystemListing[@"children"];
        
        for (NSDictionary *child in children) {
            NSLog(@"-----\n"
                  @"path: %@\n"
                  @"name: %@\n"
                  @"size: %@\n"
                  @"date last synced: %@\n"
                  @"is folder: %d",
                  child[@"path"],
                  child[@"name"],
                  child[@"size"],
                  [NSDate dateWithTimeIntervalSince1970:[child[@"date_last_synced"] doubleValue]],
                  [child[@"type"] isEqual:@"dir"]);
            
            if (![child[@"type"] isEqual:@"dir"]) {
                [weakSelf.theCopyClient requestActivityForPath:child[@"path"] withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *activityInfo) {
                    NSLog(@"success: %d, error: %@, activityInfo: %@", success, error, activityInfo);
                    
                    NSArray *events = activityInfo[@"events"];
                    
                    for (NSDictionary *event in events) {
                        NSNumber *modifiedTime = event[@"modified_time"];
                        
                        [weakSelf.theCopyClient requestActivityForPath:child[@"path"] modifiedTime:modifiedTime withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *activityInfo) {
                            NSLog(@"success: %d, error: %@, activityInfo/time(%@): %@", success, error, modifiedTime, activityInfo);
                        }];
                    }
                }];
            }
        }
    }];
}

- (void)uploadAndDownload {
    NSString *filename = @"測試文件.txt";
    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    
    __weak DMAppDelegate *weakSelf = self;
    
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    
    NSData *testData = [@"This is a line of test data\n" dataUsingEncoding:NSUTF8StringEncoding];
    
    for (int i = 0; i < 100000; i++) {
        [fileHandle writeData:testData];
    }
    
    [fileHandle closeFile];
    
    NSLog(@"Test file size: %lld", [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil].fileSize);
    
    [self.theCopyClient uploadFilePath:filePath toPath:[@"/" stringByAppendingPathComponent:filename] withProgressBlock:^(long long uploadedSoFar, long long contentLength) {
        NSLog(@"Upload progress: %lf (%lld/%lld)", (double)uploadedSoFar / (double)contentLength, uploadedSoFar, contentLength);
    } andCompletionBlock:^(BOOL success, NSError *error, NSDictionary *fileInfo) {
        NSLog(@"Upload success: %d, error: %@, fileInfo: %@", success, error, fileInfo);
        
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        
        /* requires IMG_0001.JPG to be available
         NSString *thumbFilepath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"thumbnail.jpg"];
         
         [weakSelf.theCopyClient downloadThumbnailOfSize:thumbnailSize256 forPath:@"/IMG_0001.JPG" toFilePath:thumbFilepath withCompletionBlock:^(BOOL success, NSError *error) {
         NSLog(@"Download Thumbnail success: %d, error: %@", success, error);
         
         if (success) {
         [[NSWorkspace sharedWorkspace] openFile:thumbFilepath];
         }
         }];
         */
        
        [weakSelf.theCopyClient downloadPath:[@"/" stringByAppendingPathComponent:filename] toFilePath:filePath withProgressBlock:^(long long downloadedSoFar, long long expectedContentLength) {
            NSLog(@"Download progress: %lf (%lld/%lld)", (double)downloadedSoFar / (double)expectedContentLength, downloadedSoFar, expectedContentLength);
        } andCompletionBlock:^(BOOL success, NSError *error) {
            NSLog(@"Download success: %d, error: %@", success, error);
            
            NSLog(@"Download file size: %lld", [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil].fileSize);
            
            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
        }];
    }];
}

- (void)manipulationFunctions {
    __weak DMAppDelegate *weakSelf = self;
    
    [self.theCopyClient createFolder:@"/test folder 123" withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *folderInfo) {
        NSLog(@"success: %d, error: %@, folderInfo: %@", success, error, folderInfo);
        
        [weakSelf.theCopyClient createFolder:@"/test folder 123/subfolder 123" withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *folderInfo) {
            NSLog(@"success: %d, error: %@, folderInfo: %@", success, error, folderInfo);
            
            [weakSelf.theCopyClient renameFileAtPath:@"/test folder 123/subfolder 123" newName:@"subfolder 456" withCompletionBlock:^(BOOL success, NSError *error) {
                NSLog(@"renameFileAtPath success: %d, error: %@", success, error);
                
                [weakSelf.theCopyClient moveFileAtPath:@"/test folder 123/subfolder 456" toPath:@"/test folder 456" withCompletionBlock:^(BOOL success, NSError *error) {
                    NSLog(@"moveFileAtPath success: %d, error: %@", success, error);
                    /*
                     [weakSelf.theCopyClient deleteFileAtPath:@"/test folder 456" withCompletionBlock:^(BOOL success, NSError *error) {
                     NSLog(@"deleteFileAtPath success: %d, error: %@", success, error);
                     }];
                     
                     [weakSelf.theCopyClient deleteFileAtPath:@"/test folder 123" withCompletionBlock:^(BOOL success, NSError *error) {
                     NSLog(@"deleteFileAtPath success: %d, error: %@", success, error);
                     }];
                     */
                }];
            }];
        }];
    }];
}

- (void)links {
    __weak DMAppDelegate *weakSelf = self;
    
    [self.theCopyClient createLinkForPaths:@[@"/Quickstart Guide.pdf"] makePublic:NO withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *linksInfo) {
        NSLog(@"createLinksForPaths - success: %d, error: %@, linksInfo: %@", success, error, linksInfo);
        
        NSString *token = linksInfo[@"id"];
        
        NSLog(@"token: %@", token);
        
        NSArray *updateRecipients = @[@{@"email":@"test@gmail.com",
                                        @"permissions":@"read" //,
                                        // @"remove":@YES
                                        }
                                      ];
        
        // to clear out the recipients, updateRecipients can be set to an empty
        
        [weakSelf.theCopyClient updateRecipients:updateRecipients forLink:token withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *documentInfo) {
            NSLog(@"updateRecipients - success: %d, error: %@, documentInfo: %@", success, error, documentInfo);
        }];
        
        [weakSelf.theCopyClient requestLinkInfoForToken:token withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *linkInfo) {
            NSLog(@"requestLinkInfoForToken - success: %d, error: %@, linkInfo: %@", success, error, linkInfo);
        }];
        
        [weakSelf.theCopyClient requestLinkListingForToken:token withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *linkListing) {
            NSLog(@"requestLinkListingForToken - success: %d, error: %@, linkListing: %@", success, error, linkListing);
        }];
        
        [weakSelf.theCopyClient requestLinksWithCompletionBlock:^(BOOL success, NSError *error, NSDictionary *linksInfo) {
            NSLog(@"requestLinks - success: %d, error: %@, linksInfo: %@", success, error, linksInfo);
        }];
        
        double delayInSeconds = 5.0;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [weakSelf.theCopyClient deleteLinkForToken:token withCompletionBlock:^(BOOL success, NSError *error) {
                NSLog(@"deletelinkForToken - success: %d, error: %@", success, error);
            }];
        });
    }];
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    __weak DMAppDelegate *weakSelf = self;
    
    self.theCopyClient = [COCopyClient new];
    
    COScope *scope = [COScope new];
    scope.filesystem_read = YES;
    
    /*
     self.theCopyClient = [[COCopyClient alloc] initWithToken:@"..." andTokenSecret:@"..."];
     
     [self uploadAndDownload];
     */
    
    [self.theCopyClient authenticateWithScope:scope andShowURLBlock:^(NSURL *url, NSURLRequest *(^filterRequestBlock)(NSURLRequest *filterURLRequest)) {
        weakSelf.filterRequestBlock = filterRequestBlock;
        
        [weakSelf openURLInBrowser:url];
    } andCompletionBlock:^(BOOL success, NSError *error) {
        NSLog(@"success: %d, error: %@, token: %@, secret: %@", success, error, weakSelf.theCopyClient.oAuthToken, weakSelf.theCopyClient.oAuthTokenSecret);
        
//        [weakSelf showAndModifyUserInfo];
//        [weakSelf showFileSystemInfo];
//        [weakSelf listFilesAndShowActivity];
        [weakSelf uploadAndDownload];
//        [weakSelf manipulationFunctions];
//        [weakSelf links];
    }];

    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
