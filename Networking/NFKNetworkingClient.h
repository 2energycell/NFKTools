//
//  NFKNetworkingClient.h
//
//
//  Created by Nikita Fedorenko on 01/03/2017.
//  Copyright (c) 2017 Nikita Fedorenko. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NFKInterfaceBuilder.h"
#import "NFKURLSessionManager.h"

@class NFKNetworkingClient;

/**
 *  @brief All the callbacks are invoked on the <b>default global</b> queue.
 */
@protocol NFKNetworkingClientDelegate <NSObject>

@required
- (void)networkingClient:(NFKNetworkingClient * _Nullable)networkingClient succeededWithHTTPStatusCode:(NSInteger)statusCode headers:(NSDictionary * _Nullable)headers data:(NSMutableData * _Nullable)data;
- (void)networkingClient:(NFKNetworkingClient * _Nullable)networkingClient failedWithError:(NSError * _Nullable)error;

@optional
/**
 *  @brief Implement in order to allow/block the redirection. The default return value is YES.
 */
- (BOOL)networkingClient:(NFKNetworkingClient * _Nullable)networkingClient shouldRedirectToURL:(NSURL * _Nullable)newURL;

@end

@protocol NFKNetworkingClientBuilder <NSObject>

@required
@property (nonatomic, weak, nullable) id<NFKNetworkingClientDelegate> delegate;

/**
 *  @brief Timeout in milliseconds. Everything is nonatomic, since these properties must be set at the object creation time.
 */
@property (nonatomic) NSTimeInterval timeout;
@property (nonatomic, strong, nonnull) NSURL *URL;
@property (nonatomic, copy, nonnull) NSString *HTTPMethod;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *headers;
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *queryParams;
@property (nonatomic, strong, nullable) NSData *bodyData;
@property (nonatomic) BOOL disableCaching;
/**
 *  @brief Another way of blocking redirects without the implementation of the callback method.
 */
@property (nonatomic) BOOL shouldBlockRedirect;

@end

/**
 *  @brief Networking Client - NSURLSession manager client.
 * <b>Can be used on any queue, all the callbacks will be invoked on a global default queue, so the flow should be "converted" to the desired queue, inside the callbacks.</b>
 *
 *  @discussion The network request will be performed on a concurrent thread. The response will be returned on a concurrent thread as well.
 * An instance of this class can be used on any queue and thread. <b>IMPORTANT: For each new request - should be created a new instance.</b>
 */
@interface NFKNetworkingClient : NSObject <NFKInterfaceBuilder, NFKNetworkingClientBuilder, NFKURLSessionManagerDelegate>

+ (instancetype _Nullable)build:(void(^ _Nonnull)(id<NFKNetworkingClientBuilder> _Nonnull builder))buildBlock;
- (void)prepareRequest;
- (void)startRequest;
- (void)cancelRequest;

@end
