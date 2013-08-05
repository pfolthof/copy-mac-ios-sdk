//
//  NSString+URLEncoding.h
//  CopySDK
//
//  Created by PF Olthof on 30-07-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (URLEncoding)

- (NSString *)URLEncodedString;
- (NSString *)URLDecodedString;

@end
