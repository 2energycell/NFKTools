//
//  NSBundle+NFKResources.m
//
//
//  Created by Nikita Fedorenko on 01/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import "NSBundle+NFKResources.h"

@implementation NSBundle (NFKResources)

+ (NSBundle * _Nullable)resourcesForBundleWithName:(NSString * _Nonnull)name {
    if (!name.length) {
        NSLog(@"<nfktools> `resourcesForBundleWithName:` requires a bundle name.");
        return nil;
    }
    
    NSURL *URL = [NSBundle.mainBundle URLForResource:name withExtension:@"bundle"];
    NSBundle *resources = nil;
    
    if (URL) {
        resources = [NSBundle bundleWithURL:URL];
    } else {
        NSLog(@"<nfktools> bundle was not loaded, please ensure it is added to the project.");
    }
    
    return resources;
}

@end
