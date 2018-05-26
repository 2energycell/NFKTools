//
//  NSBundle+NFKResources.m
//
//
//  Created by Nikita Fedorenko on 01/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import "NSBundle+NFKResources.h"

@implementation NSBundle (NFKResources)

+ (NSBundle * _Nullable)resourcesForBundleWithName:(NSString * _Nonnull)firstTimeInvocationOnlyName {
    if (!firstTimeInvocationOnlyName.length) {
        NSLog(@"<nfktools> `resourcesForBundleWithName:` requires a bundle name on the first invocation.");
        return;
    }
    
    static NSBundle *sharedNFKResources = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        NSURL *URL = [[NSBundle mainBundle] URLForResource:firstTimeInvocationOnlyName withExtension:@"bundle"];
        
        if (URL) {
            sharedNFKResources = [NSBundle bundleWithURL:URL];
        } else {
            NSLog(@"<nfktools> bundle was not loaded, please ensure it is added to the project.");
        }
    });
    
    return sharedNFKResources;
}

@end
