//
//  COCopyClient.h
//  CopySDK
//
//  Created by PF Olthof on 18-07-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

// For detailed documentation of the www.copy.com API, please visit https://www.copy.com/developer/documentation


#import <Foundation/Foundation.h>

#import "COScope.h"


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
