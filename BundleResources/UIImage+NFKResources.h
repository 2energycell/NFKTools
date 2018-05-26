//
//  UIImage+NFKResources.h
//
//
//  Created by Nikita Fedorenko on 01/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (NFKResources)

+ (UIImage * _Nullable)imageNamed:(NSString * _Nonnull)imageName inResourcesWithName:(NSString * _Nonnull)resourcesName;

@end
