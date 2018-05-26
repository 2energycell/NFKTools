//
//  NFKInterfaceAllocBlocker.h
//
//
//  Created by Nikita Fedorenko on 22/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#ifndef NFKInterfaceAllocBlocker_h
#define NFKInterfaceAllocBlocker_h

#import <Foundation/Foundation.h>

/**
 *  @brief Use in order to prevent direct alloc/init in singleton/builder/prototype/etc implementations.
 */
@protocol NFKInterfaceAllocBlocker <NSObject>

@required
+ (null_unspecified instancetype)alloc __attribute__((unavailable("The 'alloc' is not available, use a designated method instead.")));
- (null_unspecified instancetype)init __attribute__((unavailable("The 'init' is not available, use a designated method instead.")));
+ (null_unspecified instancetype)new __attribute__((unavailable("The 'new' is not available, use a designated method instead.")));

@end

#endif /* NFKInterfaceAllocBlocker_h */
