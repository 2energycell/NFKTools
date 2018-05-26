//
//  NFKWeakReferenceHolder.h
//
//
//  Created by Nikita Fedorenko on 01/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NFKInterfaceAllocBlocker.h"

/**
 *  @brief Use in order to add an object to a collection without retaining it.
 *
 *  @discussion This class is a thread-safe. Supports generics.
 */
@interface NFKWeakReferenceHolder<__covariant ObjectType> : NSObject <NFKInterfaceAllocBlocker>

@property (nonatomic, weak, readonly, nullable) NSObject *object;

+ (instancetype _Nonnull)weakReferenceHolderForObject:(ObjectType _Nonnull)object;

@end
