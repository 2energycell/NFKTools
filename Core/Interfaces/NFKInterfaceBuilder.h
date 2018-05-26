//
//  NFKInterfaceBuilder.h
//
//
//  Created by Nikita Fedorenko on 20/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#ifndef NFKInterfaceBuilder_h
#define NFKInterfaceBuilder_h

#import <Foundation/Foundation.h>

#import "NFKInterfaceAllocBlocker.h"

@protocol NFKInterfaceBuilder;

/**
 *  @brief Use in order to implement a builder pattern.
 */
@protocol NFKInterfaceBuilder <NFKInterfaceAllocBlocker>

@required
+ (instancetype _Nullable)build:(void(^ _Nonnull)(id<NFKInterfaceBuilder> _Nonnull builder))buildBlock;

@end

#endif /* NFKInterfaceBuilder_h */
