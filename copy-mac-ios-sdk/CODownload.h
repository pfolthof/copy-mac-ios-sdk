//
//  CODownload.h
//  CopySDK
//
//  Created by PF Olthof on 01-08-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#import <Foundation/Foundation.h>


#define CO_SIZE_UNKOWN -1


@interface CODownload : NSObject

- (void)downloadRequest:(NSURLRequest *)request
             toFilePath:(NSString *)path
               withSize:(long long)size
       andProgressBlock:(void (^)(long long downloadedSoFar, long long expectedContentLength))progressBlock
     andCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock;

- (void)cancel;

@end
