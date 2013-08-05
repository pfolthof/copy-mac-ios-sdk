//
//  COUpload.m
//  CopySDK
//
//  Created by PF Olthof on 01-08-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#import "COUpload.h"


@interface COUpload () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property NSInteger httpStatusCode;

@property long long size;

@property (copy) void (^progressBlock)(long long uploadedSoFar, long long contentLength);
@property (copy) void (^completionBlock)(BOOL success, NSError *error, NSData *responseData);

@property NSURLConnection *urlConnection;
@property NSMutableData *responseData;

@end


@implementation COUpload

- (void)uploadRequest:(NSURLRequest *)request withSize:(long long)size andProgressBlock:(void (^)(long long uploadedSoFar, long long contentLength))progressBlock andCompletionBlock:(void (^)(BOOL success, NSError *error, NSData *responseData))completionBlock {
    
    __weak COUpload *weakSelf = self;
    
    self.size = size;
    
    self.progressBlock = progressBlock;
    self.completionBlock = ^(BOOL success, NSError *error, NSData *responseData) {
        if (error == nil && weakSelf.httpStatusCode >= 400) {
            error = [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)weakSelf.httpStatusCode]}];
        }

        completionBlock(success, error, responseData);
    };
    
    self.responseData = [NSMutableData new];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    });
}

- (void)cancel {
    [self.urlConnection cancel];
}

#pragma NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.completionBlock(NO, error, self.responseData);
}

#pragma NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    self.progressBlock(totalBytesWritten, self.size);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.httpStatusCode = ((NSHTTPURLResponse *)response).statusCode;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.responseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.completionBlock(YES, nil, self.responseData);
}

@end
