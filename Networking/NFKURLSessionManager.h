//
//  NFKURLSessionManager.h
//
//
//  Created by Nikita Fedorenko on 1/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NFKInterfaceSingleton.h"

typedef void (^ _Nullable NFKURLSessionManagerCompletionBlock)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);

/**
 *  @brief All the callbacks are invoked on the <b>default global</b> queue.
 * <b>The data tasks delegates will not be retained.</b>
 * <b>The default networking timeout is 60 seconds for the `timeoutIntervalForRequest`, so it should be increased if one of the clients needs it.</b>
 * For the `timeoutIntervalForResource`, the default value is 7 days.
 * This class is a thread-safe.
 */
@protocol NFKURLSessionManagerDelegate <NSURLSessionDelegate, NSURLSessionDataDelegate> @end

@interface NFKURLSessionManager : NSObject <NFKInterfaceSingleton>

@property (nonatomic, strong, readonly, nonnull) NSOperationQueue *queue;
@property (nonatomic, strong, readonly, nonnull) NSURLSession *session;

+ (instancetype _Nonnull)sharedInstance;

- (NSURLSessionDataTask * _Nullable)dataTaskWithRequest:(NSURLRequest * _Nonnull)request completionHandler:(NFKURLSessionManagerCompletionBlock _Nullable)completionHandler;

/**
 *  @brief The delegate is not retained.
 */
- (NSURLSessionDataTask * _Nullable)dataTaskWithRequest:(NSURLRequest * _Nonnull)request delegate:(id <NFKURLSessionManagerDelegate> _Nonnull)delegate;

- (void)cancelDataTask:(NSURLSessionTask * _Nonnull)dataTask;

@end
