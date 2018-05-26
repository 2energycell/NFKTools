//
//  NFKWeakTimer.m
//
//
//  Created by Nikita Fedorenko on 27/02/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import "NFKWeakTimer.h"

@interface NFKWeakTimer ()

#pragma mark - Public redefinition
@property (nonatomic, strong, nullable, readwrite) id userInfo;
#pragma mark -

@property (nonatomic, weak, nullable) id target;
@property (nonatomic, nullable) SEL selector;

@property (atomic, strong, nullable) NSTimer *timer;

/**
 *  @discussion According to Apple, invalidation of the timer must happen on same thread it was created on.
 */
@property (nonatomic) NSString *threadID;

@end

@implementation NFKWeakTimer {}

#pragma mark - Inits

+ (instancetype _Nullable)scheduledTimerWithTimeInterval:(NSTimeInterval)timeInterval
                                                  target:(id _Nonnull)aTarget
                                                selector:(SEL _Nonnull)aSelector
                                                userInfo:(id _Nullable)userInfo
                                                 repeats:(BOOL)yesOrNo {
    NFKWeakTimer *_instance = [[self.class allocWithZone:nil] init];
    
    if (_instance) {
        _threadID = [NSString stringWithFormat:@"%p", NSThread.currentThread];
        _instance.target = aTarget;
        _instance.selector = aSelector;
        _instance.userInfo = userInfo;
        _instance.timer = [NSTimer scheduledTimerWithTimeInterval:timeInterval target:_instance selector:@selector(timerFired) userInfo:userInfo repeats:yesOrNo];
    }
    
    return _instance;
}

#pragma mark - Service

- (void)timerFired {
    __strong id target = self.target;
    SEL selector = self.selector;
    
    if (target && selector) {
        NSMethodSignature *methodSignature = [target methodSignatureForSelector:selector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
        const int defaultNumberOfArguments = 2;
        const int numberOfArgumentsWithSelf = 3;
        
        invocation.target = target;
        invocation.selector = selector;
        
        if (methodSignature.numberOfArguments >= defaultNumberOfArguments) {
            if (methodSignature.numberOfArguments == numberOfArgumentsWithSelf) {
                [invocation setArgument:&self atIndex:defaultNumberOfArguments];
            }
            
            if (target && selector) {
                [invocation invoke];
                // just ensuring the target is preserved during the invocation:
                target = nil;
            }
        }
    } else {
        [self invalidate];
    }
}

#pragma mark - API

- (BOOL)isValid {
    return (self.timer && self.timer.isValid);
}

- (void)invalidate {
    if ([_threadID isEqualToString:NSThread.currentThread]) {
        if (_timer.isValid) {
            [_timer invalidate];
        }
        
        _timer = nil;
        _target = nil;
        _selector = NULL;
        _userInfo = nil;
    }
}

- (void)addToMainRunLoopCommonModes {
    NSTimer *timer = self.timer;
    
    if (timer) {
        [NSRunLoop.mainRunLoop addTimer:timer forMode:NSRunLoopCommonModes];
    }
}

#pragma mark - Dispose

- (void)dealloc {
    [self invalidate];
    
#ifdef DEBUG
    NSLog(@"%@ deallocated.", NSStringFromClass(self.class));
#endif
}

@end
