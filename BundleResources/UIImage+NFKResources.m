//
//  UIImage+NFKResources.m
//
//
//  Created by Nikita Fedorenko on 01/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import "UIImage+NFKResources.h"

#import "NSBundle+NFKResources.h"

@implementation UIImage (NFKResources)

+ (UIImage * _Nullable)imageNamed:(NSString * _Nonnull)imageName inResourcesWithName:(NSString * _Nonnull)resourcesName {
    // loading image directly from file (iOS8+ && without assets catalog):
    NSBundle *bundle = [NSBundle resourcesForBundleWithName:resourcesName];
    NSString *filePath = nil;
    UIImage *image = nil;
    
    if (bundle && imageName.length) {
        filePath = [[bundle resourcePath] stringByAppendingPathComponent:imageName];
    }
    
    if (filePath.length) {
        image = [UIImage imageWithContentsOfFile:filePath];
        
        if (!image) {
            if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0f) {
                // if no image, probably there is assets file, so use iOS8+ method to load image from "asset.car" file:
                image = [UIImage imageNamed:imageName inBundle:bundle compatibleWithTraitCollection:nil];
            }
            
            if (!image) {
                // if still is no image, use trick:
                image = [self imageForPath:filePath scale:UIScreen.mainScreen.scale];
            }
            
            if (!image) {
                // if there is no image with the correct scale, search for another:
                NSUInteger scale = 3;
                
                while ((scale > 0) && !image) {
                    if (scale != (NSUInteger)UIScreen.mainScreen.scale) { // do not check the correct scale, already checked;
                        image = [self imageForPath:filePath scale:(CGFloat)scale];
                    }
                    
                    --scale;
                }
            }
        }
    }
    
    return image;
}

+ (UIImage *)imageForPath:(NSString *)filePath scale:(CGFloat)scale {
    filePath = [filePath stringByAppendingString:[self suffixForScale:scale]];
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:filePath];
    UIImage *image = [UIImage imageWithData:data scale:scale];
    
    return image;
}

+ (NSString *)suffixForScale:(CGFloat)scale {
    NSMutableString *suffix = [NSMutableString string];
    
    if (scale > 1.0f) {
        [suffix appendFormat:@"@%0dx", (int)scale];
    }
    
    [suffix appendString:@".png"];
    
    return suffix;
}

@end
