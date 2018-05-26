//
//  NFKInterfaceSingleton.h
//
//
//  Created by Nikita Fedorenko on 22/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#ifndef NFKInterfaceSingleton_h
#define NFKInterfaceSingleton_h

#import <Foundation/Foundation.h>

#import "NFKInterfaceAllocBlocker.h"

/**
 *  @brief Use in order to implement a singleton pattern.
 */
@protocol NFKInterfaceSingleton <NFKInterfaceAllocBlocker>

@required
+ (instancetype _Nonnull)sharedInstance;

@end

#endif /* NFKInterfaceSingleton_h */
