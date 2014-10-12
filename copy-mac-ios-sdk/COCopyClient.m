//
//  COCopyClient.m
//  CopySDK
//
//  Created by PF Olthof on 18-07-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#if TARGET_OS_IPHONE
#import <MobileCoreServices/MobileCoreServices.h>
#endif

#import "COCopyClient.h"

#import "CODownload.h"
#import "COUpload.h"

#import "NSString+URLEncoding.h"

// oAuth callback URL to be recognized on successful authorization

#define OAUTH_CALLBACK @"http://www.cloud-cdr.com"


@interface COCopyClient ()

@property NSOperationQueue *connectionOperationQueue;

@end


@implementation COCopyClient

#pragma utilities

+ (NSString *)uuidString {
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidStr = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    
    return uuidStr;
}

+ (NSString *)queryStringFromParameters:(NSDictionary *)parameters {
    NSMutableArray *entries = [NSMutableArray array];
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *entry = [NSString stringWithFormat:@"%@=%@", [key URLEncodedString], [obj URLEncodedString]];
        [entries addObject:entry];
    }];
    
    return [entries componentsJoinedByString:@"&"];
}

+ (NSDictionary *)parametersFromQueryString:(NSString *)queryString {
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    NSArray *nameValues = [queryString componentsSeparatedByString:@"&"];
    
    for (NSString *nameValue in nameValues) {
        NSArray *components = [nameValue componentsSeparatedByString:@"="];
        
        if ([components count] == 2) {
            NSString *name = [[components objectAtIndex:0] URLDecodedString];
            NSString *value = [[components objectAtIndex:1] URLDecodedString];
            
            if (name && value) {
                [dict setObject:value forKey:name];
            }
        }
    }
    
    return dict;
}

- (NSString *)authorizationForAuthentication {
    return [NSString stringWithFormat:@"OAuth oauth_version=\"1.0\", oauth_signature_method=\"PLAINTEXT\", oauth_consumer_key=\"%@\", oauth_signature=\"%@&\", oauth_nonce=\"%@\", oauth_timestamp=\"%f\"",
            self.apiKey,
            self.apiSecret,
            [COCopyClient uuidString],
            [[NSDate date] timeIntervalSince1970]];
    
}

- (NSString *)authorizationForToken:(NSString *)token
                     andTokenSecret:(NSString *)tokenSecret {
    return [NSString stringWithFormat:@"OAuth oauth_version=\"1.0\", oauth_signature_method=\"PLAINTEXT\", oauth_consumer_key=\"%@\", oauth_token=\"%@\", oauth_signature=\"%@&%@\", oauth_nonce=\"%@\", oauth_timestamp=\"%f\"",
            self.apiKey,
            token,
            self.apiSecret,
            tokenSecret,
            [COCopyClient uuidString],
            [[NSDate date] timeIntervalSince1970]];

}

#pragma mark init

- (id)init {
    if (self = [super init]) {
        self.connectionOperationQueue = [NSOperationQueue new];
        self.connectionOperationQueue.maxConcurrentOperationCount = 2;
        self.oAuthTokenRedirectUri = OAUTH_CALLBACK;
        
    }
    
    return self;
}

- (id)initWithToken:(NSString *)oAuthToken andTokenSecret:(NSString *)oAuthTokenSecret {
    if (self = [self init]) {
        self.oAuthToken = oAuthToken;
        self.oAuthTokenSecret = oAuthTokenSecret;
    }
    
    return self;
}

#pragma mark Copy API

- (void)authenticateWithScope:(COScope *)scope
              andShowURLBlock:(void (^)(NSURL *url, NSURLRequest *(^filterRequestBlock)(NSURLRequest *filterURLRequest)))showURLBlock
           andCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock {

    __weak COCopyClient *weakSelf = self;
    
    NSString *oAuthRequestURL = [NSString stringWithFormat:@"https://api.copy.com/oauth/request?%@",
                                 [COCopyClient queryStringFromParameters:@{@"oauth_callback":OAUTH_CALLBACK, @"scope":scope.scopeJSON}]];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:oAuthRequestURL]];
    [urlRequest setValue:[self authorizationForAuthentication] forHTTPHeaderField:@"Authorization"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error);
            
            return;
        }
        
        NSDictionary *parameters = [COCopyClient parametersFromQueryString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        
        NSString *oAuthTokenSecret = parameters[@"oauth_token_secret"];
        
        NSDictionary *authParameters = @{@"oauth_token":parameters[@"oauth_token"]};
        NSString *queryString = [COCopyClient queryStringFromParameters:authParameters];
        NSString *url = [NSString stringWithFormat:@"https://www.copy.com/applications/authorize?%@", queryString];

        showURLBlock([NSURL URLWithString:url], ^NSURLRequest *(NSURLRequest *filterURLRequest) { // filterRequestBlock
            NSURL *requestURL = filterURLRequest.URL;
            
            if ([requestURL.absoluteString rangeOfString:OAUTH_CALLBACK].location != NSNotFound) {                
                NSUInteger location = [requestURL.absoluteString rangeOfString:@"?oauth_token="].location;
                
                if (location != NSNotFound) {
                    NSString *queryString = [requestURL.absoluteString substringFromIndex:location + 1];
                    
                    NSDictionary *callbackParameters = [COCopyClient parametersFromQueryString:queryString];
                    
                    NSString *oAuthAccessURL = [NSString stringWithFormat:@"https://api.copy.com/oauth/access?%@",
                                                [COCopyClient queryStringFromParameters:@{@"oauth_verifier":callbackParameters[@"oauth_verifier"]}]];
                    
                    NSMutableURLRequest *accessUrlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:oAuthAccessURL]];
                    [accessUrlRequest setValue:[self authorizationForToken:callbackParameters[@"oauth_token"] andTokenSecret:oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
                    
                    [NSURLConnection sendAsynchronousRequest:accessUrlRequest queue:weakSelf.connectionOperationQueue completionHandler:^(NSURLResponse *accessResponse, NSData *accessData, NSError *accessError) {
                        if (accessError != nil) {
                            completionBlock(NO, accessError);
                            
                            return;
                        }
                        
                        NSDictionary *accessParameters = [COCopyClient parametersFromQueryString:[[NSString alloc] initWithData:accessData encoding:NSUTF8StringEncoding]];
                        
                        self.oAuthToken = accessParameters[@"oauth_token"];
                        self.oAuthTokenSecret = accessParameters[@"oauth_token_secret"];
                        
                        completionBlock(YES, nil);
                    }];
                    
                    return nil; // cancel loading, redirect callback found
                }
            }
            
            return filterURLRequest;
        });
    }];
}

- (void)requestUserInfoWithCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *userInfo))completionBlock {
    NSString *userURL = [NSString stringWithFormat:@"https://api.copy.com/rest/user"];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:userURL]];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)updateUserInfo:(NSDictionary *)userInfo withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *userInfo))completionBlock {
    NSString *userURL = [NSString stringWithFormat:@"https://api.copy.com/rest/user"];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:userURL]];
    [urlRequest setHTTPMethod:@"PUT"];
    [urlRequest setHTTPBody:[NSJSONSerialization dataWithJSONObject:userInfo options:0 error:nil]];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)requestFileSystemInfoWithCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *fileSystemInfo))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/meta"];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:metaURL]];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)requestFileSystemListingForPath:(NSString *)path withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *fileSystemListing))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/meta/copy"];
    NSURL *url = [[NSURL URLWithString:metaURL] URLByAppendingPathComponent:path];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)requestActivityForPath:(NSString *)path withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *activityInfo))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/meta/copy"];
    NSURL *url = [[[NSURL URLWithString:metaURL] URLByAppendingPathComponent:path] URLByAppendingPathComponent:@"@activity"];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)requestActivityForPath:(NSString *)path modifiedTime:(NSNumber *)modifiedTime withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *activityInfo))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/meta/copy"];
    NSURL *url = [[[[NSURL URLWithString:metaURL] URLByAppendingPathComponent:path] URLByAppendingPathComponent:@"@activity"] URLByAppendingPathComponent:[NSString stringWithFormat:@"@time:%@",modifiedTime]];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (CODownload *)downloadPath:(NSString *)path toFilePath:(NSString *)toFilePath withProgressBlock:(void (^)(long long downloadedSoFar, long long expectedContentLength))progressBlock andCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    CODownload *download = [CODownload new];
    
    [self requestFileSystemListingForPath:path withCompletionBlock:^(BOOL success, NSError *error, NSDictionary *fileSystemListing) {
        if (!success) {
            completionBlock(success, error);
            
            return;
        }
        
        NSString *fileURL = [NSString stringWithFormat:@"https://api.copy.com/rest/files"];
        NSURL *url = [[NSURL URLWithString:fileURL] URLByAppendingPathComponent:path];
        
        NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
        [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
        [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
        [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        [download downloadRequest:urlRequest toFilePath:toFilePath withSize:[fileSystemListing[@"size"] longLongValue] andProgressBlock:progressBlock andCompletionBlock:^(BOOL success, NSError *error) {
            CODownload *downloadRef = download; // keep reference to download
            
            completionBlock(success, error);
            
            downloadRef = nil; // release reference to download (unneccesary, but prevents compiler warning about unused variable)
        }];
    }];
    
    return download;
}

- (COUpload *)uploadFilePath:(NSString *)filePath toPath:(NSString *)path withProgressBlock:(void (^)(long long uploadedSoFar, long long contentLength))progressBlock andCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *fileInfo))completionBlock {
    NSString *fileURL = [NSString stringWithFormat:@"https://api.copy.com/rest/files"];
    NSURL *url = [[NSURL URLWithString:fileURL] URLByAppendingPathComponent:[path stringByDeletingLastPathComponent]];
    
    // determine mime type
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)[path pathExtension], NULL);
    NSString *mimeType = (__bridge NSString *)(UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType));
    
    if (mimeType == nil) mimeType = @"application/octet-stream";
    
    // Write the multipart request including file data to a temporary file so NSURLConnection can stream the thing without keeping it all in memory
    NSString *boundary = [NSString stringWithFormat:@"CopySDK%@", [COCopyClient uuidString]];
    
    NSString *authorization = [self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret];
    
    NSString *tempHTTPBodyFile = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", path.lastPathComponent, [COCopyClient uuidString]]];
    
    [[NSFileManager defaultManager] createFileAtPath:tempHTTPBodyFile contents:nil attributes:nil];
   
    // long long fileSize = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil].fileSize;
    
    NSFileHandle *httpBodyFileHandle = [NSFileHandle fileHandleForWritingAtPath:tempHTTPBodyFile];
    
    [httpBodyFileHandle writeData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBodyFileHandle writeData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"filename\"\r\n\r\n%@\r\n", path.lastPathComponent] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [httpBodyFileHandle writeData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBodyFileHandle writeData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", path.lastPathComponent] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBodyFileHandle writeData:[[NSString stringWithFormat:@"Content-Type: %@\r\n", mimeType] dataUsingEncoding:NSUTF8StringEncoding]];
    // [httpBodyFileHandle writeData:[[NSString stringWithFormat:@"Content-Size: %lld\r\n", fileSize] dataUsingEncoding:NSUTF8StringEncoding]];
    [httpBodyFileHandle writeData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    
    NSUInteger chunkSize = 1024 * 64;
    
    NSData *data;
    while ((data = [fileHandle readDataOfLength:chunkSize]) && data.length > 0) {
        [httpBodyFileHandle writeData:data];
    }
    
    [fileHandle closeFile];

    [httpBodyFileHandle writeData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [httpBodyFileHandle closeFile];
    
    long long httpBodySize = [[NSFileManager defaultManager] attributesOfItemAtPath:tempHTTPBodyFile error:nil].fileSize;
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setValue:authorization forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [urlRequest setValue:[NSString stringWithFormat:@"multipart/form-data; charset=utf-8; boundary=%@", boundary] forHTTPHeaderField:@"Content-Type"];
    // [urlRequest setValue:[NSString stringWithFormat:@"%lld", httpBodySize] forHTTPHeaderField:@"Content-Size"];
    [urlRequest setValue:@"close" forHTTPHeaderField:@"Connection"];
    
    // does not currently work because this enables Transfer-Encoding: Chunked, which resuls in errors
    // todo: close stream in completionBlock?
    // NSInputStream *inputStream = [NSInputStream inputStreamWithFileAtPath:tempHTTPBodyFile];
    // [urlRequest setHTTPBodyStream:inputStream];
    [urlRequest setHTTPBody:[NSData dataWithContentsOfFile:tempHTTPBodyFile]];
    
    COUpload *upload = [COUpload new];
    [upload uploadRequest:urlRequest withSize:httpBodySize andProgressBlock:progressBlock andCompletionBlock:^(BOOL success, NSError *error, NSData *responseData) {
        COUpload *uploadRef = upload; // keep reference to upload

        [[NSFileManager defaultManager] removeItemAtPath:tempHTTPBodyFile error:nil];
        
        NSDictionary *fileInfo = nil;
        
        @try {
            fileInfo = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
        }
        @catch (NSException *exception) {
            // ignore
        }
        
        completionBlock(success, error, fileInfo);
        
        uploadRef = nil; // release reference to upload (unneccesary, but prevents compiler warning about unused variable)
    }];
    
    return upload;
}

- (void)createFolder:(NSString *)path withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *folderInfo))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/files"];
    NSURL *url = [[NSURL URLWithString:metaURL] URLByAppendingPathComponent:path];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)deleteFileAtPath:(NSString *)path withCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/files"];
    NSURL *url = [[NSURL URLWithString:metaURL] URLByAppendingPathComponent:path];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setHTTPMethod:@"DELETE"];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}]);
                
                return;
            }
        }
        
        completionBlock(YES, nil);
    }];
}

- (void)renameFileAtPath:(NSString *)path newName:(NSString *)newName withCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/files"];
    NSURL *url = [[NSURL URLWithString:metaURL] URLByAppendingPathComponent:path];
    url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?name=%@", url.absoluteString, [newName stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
        
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setHTTPMethod:@"PUT"];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}]);
                
                return;
            }
        }
        
        completionBlock(YES, nil);
    }];
}

- (void)moveFileAtPath:(NSString *)path toPath:(NSString *)toPath withCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/files"];
    NSURL *url = [[NSURL URLWithString:metaURL] URLByAppendingPathComponent:path];
    url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?path=%@", url.absoluteString, [toPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setHTTPMethod:@"PUT"];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}]);
                
                return;
            }
        }
        
        completionBlock(YES, nil);
    }];
}

- (void)downloadThumbnailOfSize:(COThumnailSize)size forPath:(NSString *)path toFilePath:(NSString *)toFilePath withCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    NSString *fileURL = [NSString stringWithFormat:@"https://api.copy.com/rest/thumbs"];
    NSURL *url = [[NSURL URLWithString:fileURL] URLByAppendingPathComponent:path];
    url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?size=%d", url.absoluteString, size]];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    CODownload *download = [CODownload new];
    [download downloadRequest:urlRequest toFilePath:toFilePath withSize:CO_SIZE_UNKOWN andProgressBlock:^(long long downloadedSoFar, long long expectedContentLength) {
        // ignore progress as the size is not known
    } andCompletionBlock:^(BOOL success, NSError *error) {
        CODownload *downloadRef = download; // keep reference to download
        
        completionBlock(success, error);
        
        downloadRef = nil; // release reference to download (unneccesary, but prevents compiler warning about unused variable)
    }];
}

- (void)requestLinkInfoForToken:(NSString *)token withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *linkInfo))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/links"];
    NSURL *url = [[NSURL URLWithString:metaURL] URLByAppendingPathComponent:token];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)requestLinkListingForToken:(NSString *)token withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *linkListing))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/meta/links"];
    NSURL *url = [[NSURL URLWithString:metaURL] URLByAppendingPathComponent:token];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)requestLinksWithCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *linksInfo))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/links"];
    NSURL *url = [NSURL URLWithString:metaURL];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)createLinkForPaths:(NSArray *)paths makePublic:(BOOL)makePublic withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *linkInfo))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/links"];
    NSURL *url = [NSURL URLWithString:metaURL];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:@{@"public":@(makePublic),@"paths":paths} options:0 error:nil];
    
    [urlRequest setHTTPBody:bodyData];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)updateRecipients:(NSArray *)recipients forLink:(NSString *)token withCompletionBlock:(void (^)(BOOL success, NSError *error, NSDictionary *linkInfo))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/links"];
    NSURL *url = [[NSURL URLWithString:metaURL] URLByAppendingPathComponent:token];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setHTTPMethod:@"PUT"];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSDictionary *updateRecipients = @{@"token":token,@"recipients":recipients};
    
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:updateRecipients options:0 error:nil];
    
    [urlRequest setHTTPBody:bodyData];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error, nil);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                NSLog(@"Warning - updateRecipients response: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}], nil);
                
                return;
            }
        }
        
        completionBlock(YES, nil, [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    }];
}

- (void)deleteLinkForToken:(NSString *)token withCompletionBlock:(void (^)(BOOL success, NSError *error))completionBlock {
    NSString *metaURL = [NSString stringWithFormat:@"https://api.copy.com/rest/links"];
    NSURL *url = [[NSURL URLWithString:metaURL] URLByAppendingPathComponent:token];
    
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url];
    [urlRequest setHTTPMethod:@"DELETE"];
    [urlRequest setValue:[self authorizationForToken:self.oAuthToken andTokenSecret:self.oAuthTokenSecret] forHTTPHeaderField:@"Authorization"];
    [urlRequest setValue:@"1" forHTTPHeaderField:@"X-Api-Version"];
    [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest queue:self.connectionOperationQueue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (error != nil) {
            completionBlock(NO, error);
            
            return;
        } else {
            NSInteger status = ((NSHTTPURLResponse *)response).statusCode;
            
            if (status >= 400) {
                completionBlock(NO, [NSError errorWithDomain:@"nl.devoorkant.CopySDK" code:3 userInfo:@{@"error":[NSString stringWithFormat:@"Server returned status %ld", (long)status]}]);
                
                return;
            }
        }
        
        completionBlock(YES, nil);
    }];
}

@end
