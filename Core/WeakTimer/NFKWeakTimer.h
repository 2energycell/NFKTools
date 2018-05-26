//
//  NFKWeakTimer.h
//
//
//  Created by Nikita Fedorenko on 27/02/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  @brief Class responsibility:
 *
 * 1. Encapsulates the NSTimer basic logic.
 *
 * 2. Does NOT retain the target.
 *
 *  @discussion This class is a thread-safe with one exclusion: it must be released on a same thread it was created on.
 * This is due to Apple requirement to invoke the `invalidate` method on a same thread the timer was created on.
 */
@interface NFKWeakTimer : NSObject

@property (nonatomic, strong, nullable, readonly) id userInfo;

+ (instancetype _Nullable)scheduledTimerWithTimeInterval:(NSTimeInterval)timeInterval
                                                  target:(id _Nonnull)aTarget
                                                selector:(SEL _Nonnull)aSelector
                                                userInfo:(id _Nullable)userInfo
                                                 repeats:(BOOL)yesOrNo;

- (BOOL)isValid;
- (void)invalidate;
- (void)addToMainRunLoopCommonModes;

@end
