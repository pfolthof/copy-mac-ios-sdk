copy-mac-ios-sdk
================

Object-C API for www.copy.com (Mac and iOS), derived from code written for the iOS Drag & Drop 2-Panel File Management App Cloud Commander (www.cloud-cdr.com).

The library is based on Mac OS 10.8 or iOS 6.1, using GCD Blocks and ARC. Currently the library does not use any third party libraries.

Opening copy-mac-ios-sdk.xcworkspace in XCode will show the two demo projects DemoMobile (for iOS) and DemoMac as well as the library project CopySDK.

To use the library, the following code needs to be used:

On iOS:
``` Objective-C
#import "CopySDK-iOS/CopySDK.h"
```

On the Mac:
``` Objective-C
#import <CopySDK/CopySDK.h>
```

Declaring a property to keep the COCopyClient alive:
``` Objective-C
@property COCopyClient *theCopyClient;
```

To let the user login to www.copy.com and retrieve the oAuth token and token secret, call:
``` Objective-C
    __weak DMAppDelegate *weakSelf = self; // prevent retain cycle
    
    [self.theCopyClient authenticateWithScope:scope andShowURLBlock:^(NSURL *url, NSURLRequest *(^filterRequestBlock)(NSURLRequest *filterURLRequest)) {
        weakSelf.filterRequestBlock = filterRequestBlock;

        [weakSelf openURLInBrowser:url];
    } andCompletionBlock:^(BOOL success, NSError *error) {
        // The token and token secret can be stored for future use:
        // weakSelf.theCopyClient.oAuthToken
        // weakSelf.theCopyClient.oAuthTokenSecret
    }
```

For the user to be able to login, you need to show the web page in a web browser control. To detect the callback when login has succeeded, filterRequestBlock has to be used in the delegate.

On iOS:
``` Objective-C
- (void)openURLInBrowser:(NSURL *)url {
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
    
    DMViewController *viewController = (DMViewController *)self.window.rootViewController;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [viewController.webView loadRequest:urlRequest];
    });
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    DMAppDelegate *appDelegate = (DMAppDelegate *)[UIApplication sharedApplication].delegate;
    
    NSURLRequest *filteredRequest = appDelegate.filterRequestBlock(request);
    
    return filteredRequest != nil;
}
```

On the Mac:
``` Objective-C
- (void)openURLInBrowser:(NSURL *)url {
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
        
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self.webView mainFrame] loadRequest:urlRequest];
    });
}

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource {
    return self.filterRequestBlock(request);
}
```

Once you have the oAuth token and token secret, you can initialize the COCopyClient with:
``` Objective-C
    self.theCopyClient = [[COCopyClient alloc] initWithToken:oAuthToken andTokenSecret:oAuthTokenSecret];
```

The initialized COCopyClient can be used to call any of the Copy API methods. 

An example of an API call:
``` Objective-C
    [self.theCopyClient requestUserInfoWithCompletionBlock:^(BOOL success, NSError *error, NSDictionary *userInfo) {
        NSLog(@"success: %d, error: %@, user info: %@", success, error, userInfo);
        NSLog(@"first_name: %@", userInfo[@"first_name"]);
    }];
```

For a complete list of supported methods see COCopyClient.h:

``` Objective-C
typedef enum {
    thumbnailSize32 = 32,
    thumbnailSize64 = 64,
    thumbnailSize128 = 128,
    thumbnailSize256 = 256,
    thumbnailSize512 = 512,
    thumbnailSize1024 = 1024
} COThumnailSize;


@interface COCopyClient : NSObject

@property NSString *oAuthToken;
@property NSString *oAuthTokenSecret;

// use either init and authenticateWithScope or initWithToken to initialize oAuth token/secret

- (id)initWithToken:(NSString *)oAuthToken andTokenSecret:(NSString *)oAuthTokenSecret;

- (void)authenticateWithScope:(COScope *)scope
              andShowURLBlock:(void (^)(NSURL *url, NSURLRequest *(^filterRequestBlock)(NSURLRequest *filterURLRequest)))showURLBlock
           andCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

// user info

- (void)requestUserInfoWithCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *userInfo))completionBlock;

- (void)updateUserInfo:(NSDictionary *)userInfo
   withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *userInfo))completionBlock;

// file system

- (void)requestFileSystemInfoWithCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *fileSystemInfo))completionBlock;

- (void)requestFileSystemListingForPath:(NSString *)path
                    withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *fileSystemListing))completionBlock;

- (void)requestActivityForPath:(NSString *)path
           withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *activityInfo))completionBlock;

- (void)requestActivityForPath:(NSString *)path modifiedTime:(NSNumber *)modifiedTime
           withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *activityInfo))completionBlock;

// download / upload

- (void)downloadPath:(NSString *)path
          toFilePath:(NSString *)toFilePath
   withProgressBlock:(void (^)(long long downloadedSoFar, long long expectedContentLength))progressBlock
  andCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

- (void)uploadFilePath:(NSString *)filePath
                toPath:(NSString *)path withProgressBlock:(void (^)(long long uploadedSoFar, long long contentLength))progressBlock
    andCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *fileInfo))completionBlock;

// create folder

- (void)createFolder:(NSString *)path
 withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *folderInfo))completionBlock;

// delete file or folder (all files below the folder being deleted will be removed)

- (void)deleteFileAtPath:(NSString *)path
     withCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

// rename / move (toPath should include target filename)

- (void)renameFileAtPath:(NSString *)path
                 newName:(NSString *)newName
     withCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

- (void)moveFileAtPath:(NSString *)path
                toPath:(NSString *)toPath
   withCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

// download thumbnail

- (void)downloadThumbnailOfSize:(COThumnailSize)size
                        forPath:(NSString *)path
                     toFilePath:(NSString *)toFilePath
            withCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock;


// links

- (void)requestLinkInfoForToken:(NSString *)token
            withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *linkInfo))completionBlock;

- (void)requestLinkListingForToken:(NSString *)token
               withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *linkListing))completionBlock;

- (void)requestLinksWithCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *linksInfo))completionBlock;

- (void)createLinkForPaths:(NSArray *)paths
                makePublic:(BOOL)makePublic
       withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *linksInfo))completionBlock;

- (void)updateRecipients:(NSArray *)recipients
                 forLink:(NSString *)token
     withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *documentInfo))completionBlock;

- (void)deleteLinkForToken:(NSString *)token
       withCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

@end
```
