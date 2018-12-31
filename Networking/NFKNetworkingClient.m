//
//  NFKNetworkingClient.m
//
//
//  Created by Nikita Fedorenko on 01/03/2017.
//  Copyright (c) 2017 Nikita Fedorenko. All rights reserved.
//

#import "NFKNetworkingClient.h"

#import "NFKURLSessionManager.h"
#import "NFKWeakTimer.h"

@interface NFKNetworkingClient ()

@property (nonatomic, weak) dispatch_queue_t queue; // nonatomic, since the write to the property happens only at the init time;

@property (atomic, strong) NSURLSessionDataTask *currentTask;
@property (atomic, strong) dispatch_source_t timer;

@property (atomic, strong) NSMutableData *responseData;
@property (atomic, strong) NSDictionary *responseHeaders;
@property (atomic) NSInteger responseStatusCode;

@property (nonatomic, strong) dispatch_queue_t resultSyncQueue;

#pragma mark - Readonly redefinition
@property (atomic, strong, readwrite) NSURLRequest *originalRequest;

@end

@implementation NFKNetworkingClient {}

#pragma mark - Statics

static NSString * _Nonnull const kIAEscapeCharsForQueryStringValue = @"!*'();:@+$,/?%#[]<>&"; // URL query string value encoding escape chars;

#pragma mark - Builder

@synthesize delegate = _delegate;
@synthesize timeout = _timeout;
@synthesize URL = _URL;
@synthesize HTTPMethod = _HTTPMethod;
@synthesize headers = _headers;
@synthesize queryParams = _queryParams;
@synthesize bodyData = _bodyData;
@synthesize disableCaching = _disableCaching;
@synthesize shouldBlockRedirect = _shouldBlockRedirect;

+ (instancetype _Nullable)build:(void(^ _Nonnull)(id<NFKNetworkingClientBuilder> _Nonnull builder))buildBlock {
    NFKNetworkingClient *object = [[self allocWithZone:nil] init];
    
    if (buildBlock) {
        buildBlock(object);
        
        object.queue = NFKURLSessionManager.sharedInstance.queue.underlyingQueue;
        object.resultSyncQueue = dispatch_queue_create("com.nfktools.networking.client.resultSyncQueue", DISPATCH_QUEUE_SERIAL);
    }
    
    return object;
}

#pragma mark - API

- (void)prepareRequest {
    if (self.URL && !self.currentTask) {
        // set Query params:
        NSMutableString *URLWithQueryString = [NSMutableString stringWithString:self.URL.absoluteString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        __block NSInteger index = 0;
        
        if (self.queryParams.count) {
            [URLWithQueryString appendString:@"?"];
        }
        
        [self.queryParams enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if (index > 0) {
                [URLWithQueryString appendString:@"&"];
            }
            
            [URLWithQueryString appendString:[NSString stringWithFormat:@"%@=%@", key, [self.class escapeQueryStringValue:[NSString stringWithFormat:@"%@", obj]]]];
            ++index;
        }];
        
        NSMutableURLRequest *mutableRequest =
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[URLWithQueryString]];
         
        self.originalRequest = mutableRequest;
        
        // set HTTP method:
        if (self.HTTPMethod.length) {
            mutableRequest.HTTPMethod = self.HTTPMethod;
        }
        
        // set Header fields:
        [self.headers enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, NSString * _Nonnull valuesAsString, BOOL * _Nonnull stop) {
			[mutableRequest setValue:valuesAsString forHTTPHeaderField:key];
        }];
        
        // set HTTP body:
        if (self.bodyData) {
            [mutableRequest setHTTPBody:self.bodyData];
        }
        
        if (self.disableCaching) {
            [mutableRequest setCachePolicy:NSURLRequestReloadIgnoringCacheData];
        }
        
        self.currentTask = [NFKURLSessionManager.sharedInstance dataTaskWithRequest:mutableRequest delegate:self];
    }
}

- (void)startRequest {
    NSLog(@"<nfktools> networking client will start a new connection to a resource: %@;", self.URL.resourceSpecifier);
    [self startTimer];
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(self.queue, ^{
        [weakSelf.currentTask resume];
    });
}

- (void)cancelRequest {
    if (self.timer) {
        dispatch_sync(self.resultSyncQueue, ^{
            // dispatch_source_cancel must be synced, since it will crash in case it gets a nil;
            [self cancelTimer];
        });
    }
    
    [self removeDataTask:self.currentTask];
    
    self.responseData = nil;
    self.responseHeaders = nil;
    self.responseStatusCode = 0;
}
         
#pragma mark - Class API
         
 + (NSString * _Nullable)escapeQueryStringValue:(NSString * _Nonnull)queryStringVal {
     NSString *queryStringRetVal =
     (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)queryStringVal, NULL, (CFStringRef)kIAEscapeCharsForQueryStringValue, kCFStringEncodingUTF8));
     
     return queryStringRetVal;
 }

#pragma mark - NFKURLSessionManagerDelegate
#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(self.resultSyncQueue, ^{ // the critical section; we do not need here sync, we can use async and we do not need to preserve the 'self';
        if (weakSelf.currentTask) {
#ifdef DEBUG
            NSLog(@"<nfktools> finished networking task for client: %@ and thread: %@\n", weakSelf, NSThread.currentThread);
#endif
            [weakSelf cancelTimer];
            [weakSelf removeDataTask:task];
            
            if (error) {
                [weakSelf.delegate networkingClient:weakSelf failedWithError:error];
            } else {
                if ([task.response isKindOfClass:NSHTTPURLResponse.class]) {
                    NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];
                    NSDictionary *headers = [(NSHTTPURLResponse *)task.response allHeaderFields];
                    const BOOL blockedRedirectIntentionaly = ((statusCode >= 300) && (statusCode <= 302)) && weakSelf.shouldBlockRedirect;
                    
                    if ((statusCode >= 200) && ((statusCode < 300) || blockedRedirectIntentionaly)) {
                        weakSelf.responseHeaders = headers;
                        weakSelf.responseStatusCode = statusCode;
                        [weakSelf.delegate networkingClient:weakSelf succeededWithHTTPStatusCode:weakSelf.responseStatusCode headers:weakSelf.responseHeaders data:weakSelf.responseData];
                    } else {
                        [weakSelf.delegate networkingClient:weakSelf failedWithError:[NSError errorWithDomain:@"error" code:statusCode userInfo:nil]];
                    }
                } else {
                    [weakSelf.delegate networkingClient:weakSelf failedWithError:[NSError errorWithDomain:@"response is not kind of class 'NSHTTPURLResponse'" code:0 userInfo:nil]];
                }
            }
        }
    });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler {
    __weak typeof(self) weakSelf = self;
    BOOL shouldRedirect = YES;
    
    if (weakSelf.shouldBlockRedirect) {
        shouldRedirect = NO;
    } else if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(networkingClient:shouldRedirectToURL:)]) {
        shouldRedirect = [weakSelf.delegate networkingClient:weakSelf shouldRedirectToURL:request.URL];
    }
    
    if (shouldRedirect) {
        completionHandler(request);
    } else {
        completionHandler(NULL);
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler{
    // allowing self-signed certificates:
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
		
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    __weak typeof(self) weakSelf = self;
    
    if ([response respondsToSelector:@selector(statusCode)]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        
        if (statusCode >= 400) {
            completionHandler(NSURLSessionResponseCancel);
            return;
        }
    }
    
    weakSelf.responseData = [NSMutableData data];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    // the lock on the `responseData` object is not needed here, since all the URL session manager's callbacks are invoked in a serial way;
    [self.responseData appendData:data];
#ifdef DEBUG
    NSLog(@"<nfktools> appended data of networking task for client: %@ and thread: %@\n", self, NSThread.currentThread);
#endif
}

#pragma mark - Service

- (void)removeDataTask:(NSURLSessionTask *)task {
    [NFKURLSessionManager.sharedInstance cancelDataTask:task];
    self.currentTask = nil;
}

#pragma mark - Timer

- (void)startTimer {
    if (self.timeout > 0) {
        self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.resultSyncQueue);
        
        if (self.timer) {
            dispatch_source_set_timer(
                                      self.timer,
                                      dispatch_time(DISPATCH_TIME_NOW, self.timeout * (double)NSEC_PER_SEC),
                                      self.timeout * (double)NSEC_PER_SEC,
                                      (double)(1ull * NSEC_PER_SEC) / 10.0);
            __weak typeof(self) weakSelf = self;
            
            dispatch_source_set_event_handler(self.timer, ^{
                [weakSelf timeoutTimerFired];
            });
            dispatch_resume(self.timer);
        }
    }
}

// the timer is running on the resultSyncQueue, it grants a critical section for whole a method:
- (void)timeoutTimerFired {
    if (self.currentTask) {
        [self cancelTimer];
        [self removeDataTask:self.currentTask];
        
        __weak typeof(self) weakSelf = self;
        
        [weakSelf.delegate networkingClient:weakSelf failedWithError:[NSError errorWithDomain:@"timeout" code:0 userInfo:nil]];
    }
}

- (void)cancelTimer {
    if (self.timer) {
        dispatch_source_cancel(self.timer);
        self.timer = nil;
    }
}

#pragma mark - Dispose

- (void)dealloc {
    [self cancelRequest];
    
#ifdef DEBUG
    NSLog(@"%@ deallocated.", NSStringFromClass(self.class));
#endif
}

@end
