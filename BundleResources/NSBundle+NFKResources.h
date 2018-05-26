//
//  NSBundle+NFKResources.h
//
//
//  Created by Nikita Fedorenko on 01/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSBundle (NFKResources)

+ (NSBundle * _Nullable)resourcesForBundleWithName:(NSString * _Nonnull)name;

@end
