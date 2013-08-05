//
//  CODownload.m
//  CopySDK
//
//  Created by PF Olthof on 01-08-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#import "CODownload.h"


@interface CODownload () <NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property NSURLConnection *urlConnection;

@property long long expectedContentLength;
@property long long downloadedSoFar;

@property NSInteger httpStatusCode;

@property long long size;

@property NSFileHandle *fileHandle;

@property (copy) void (^progressBlock)(long long downloadedSoFar, long long expectedContentLength);
@property (copy) void (^completionBlock)(BOOL success, NSError *error);

@end


@implementation CODownload

- (void)downloadRequest:(NSURLRequest *)request toFilePath:(NSString *)filePath withSize:(long long)size andProgressBlock:(void (^)(long long downloadedSoFar, long long expectedContentLength))progressBlock andCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock {

    __weak CODownload *weakSelf = self;
    
    self.size = size;
    
    self.progressBlock = progressBlock;
    self.completionBlock = ^(BOOL success, NSError *error) {
        [weakSelf.fileHandle closeFile];
        
        if (error == nil && weakSelf.httpStatusCode >= 400) {
            error = [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)weakSelf.httpStatusCode]}];
        }
        
        completionBlock(success, error);
    };
    
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    });
}

- (void)cancel {
    [self.urlConnection cancel];
}

#pragma NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.completionBlock(NO, error);
}

#pragma NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
    self.expectedContentLength = response.expectedContentLength;
    
    self.httpStatusCode = response.statusCode;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    self.downloadedSoFar += data.length;
    
    self.progressBlock(self.downloadedSoFar, self.size == CO_SIZE_UNKOWN ? self.expectedContentLength : self.size);
    
    [self.fileHandle writeData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.completionBlock(YES, nil);
}

@end
