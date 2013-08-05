//
//  COUpload.h
//  CopySDK
//
//  Created by PF Olthof on 01-08-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface COUpload : NSObject

- (void)uploadRequest:(NSURLRequest *)request
             withSize:(long long)size
     andProgressBlock:(void (^)(long long uploadedSoFar, long long contentLength))progressBlock
   andCompletionBlock:(void (^)(BOOL success, NSError *error, NSData *responseData))completionBlock;

- (void)cancel;

@end
