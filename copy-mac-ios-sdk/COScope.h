//
//  COScope.h
//  CopySDK
//
//  Created by PF Olthof on 30-07-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface COScope : NSObject

@property BOOL profile_read;
@property BOOL profile_write;
@property BOOL profile_email_read;

@property BOOL inbox_read;

@property BOOL links_read;
@property BOOL links_write;

@property BOOL filesystem_read;
@property BOOL filesystem_write;

- (NSDictionary *)scopeDictionary;
- (NSString *)scopeJSON;

@end
