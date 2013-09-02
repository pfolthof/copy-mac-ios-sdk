//
//  COScope.m
//  CopySDK
//
//  Created by PF Olthof on 30-07-13.
//  Copyright (c) 2013 De Voorkant. All rights reserved.
//

#import "COScope.h"

@implementation COScope

- (NSDictionary *)scopeDictionary {
    return @{@"profile":
                @{@"read":@(self.profile_read),
                  @"write":@(self.profile_write),
                  @"email":@{@"read":@(self.profile_email_read)}},
             @"inbox":
                 @{@"read":@(self.inbox_read)},
             @"links":
                 @{@"read":@(self.links_read),
                   @"write:":@(self.links_write)},
             @"filesystem":
                 @{@"read":@(self.filesystem_read),
                   @"write":@(self.filesystem_write)}
             };
}

- (NSString *)scopeJSON {
    return [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:self.scopeDictionary options:0 error:nil] encoding:NSUTF8StringEncoding];
}

- (void)grantAllPermissions {
    self.profile_write = YES;
    self.profile_read = YES;
    self.profile_email_read = YES;
    self.inbox_read = YES;
    self.links_read = YES;
    self.links_write = YES;
    self.filesystem_read = YES;
    self.filesystem_write = YES;
}

- (id)initWithAllPermissions {
    if (self = [super init]) {
        self.profile_write = YES;
        self.profile_read = YES;
        self.profile_email_read = YES;
        self.inbox_read = YES;
        self.links_read = YES;
        self.links_write = YES;
        self.filesystem_read = YES;
        self.filesystem_write = YES;
    }
    return self;
}

+ (id)scopeAllPermissions {
    return [[[self class]alloc]initWithAllPermissions];
}

@end
