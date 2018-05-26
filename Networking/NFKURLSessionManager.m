//
//  NFKURLSessionManager.m
//
//
//  Created by Nikita Fedorenko on 1/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import "NFKURLSessionManager.h"

#import "NFKWeakReferenceHolder.h"

// concerns:
// since this networking module supports a work from multiple threads simultaneously and the URLSession instance is a single and is shared, in this design,
// we need to manage the syncronisation of the `tasksDelegates`; we can solve this by:
// - lock (recursive), other memory barrier or serial queues;
// - using a serial custom queue instead of concurent, for the requests? don't think so; it will not block the UI, but can be risky, and is conceptually wrong;
// - removing this singleton manager and creating a new URLSession inside the `NFKNetworkingClient` for each `NFKNetworkingClient` instance,
// but then we loose an advantage of using the URLSession (probably in the real-world scenario, there is no big advantage);
// eventually, a dedicated serial queue is used to implement a memory barrier, as by Apple recommendations;

@interface NFKURLSessionManager () <NSURLSessionDelegate, NSURLSessionDataDelegate>

@property (atomic) BOOL sessionIsValid; // atomic, since a setter and getter can be accessed at the same time from a different threads;
// nonatomic, since a setter is accessed only one time, at init time:
@property (nonatomic, strong) NSMutableDictionary<NSString *, NFKWeakReferenceHolder<id<NFKURLSessionManagerDelegate>> *> *tasksDelegates;

@end

@implementation NFKURLSessionManager {
    @private
    NSURLSession *_session; // although the atomic property is needed here, there is a custom getter implementation that syncs the threads;
    volatile BOOL _sessionIsValid; // volatile is to prevent compiler optimisation in the double-checked locking;
    
    dispatch_queue_t _sessionGetterSyncQueue; // this queue is a serial, intented to substitute locks;
    dispatch_queue_t _tasksDelegatesSyncQueue; // this queue is a serial, intented to substitute locks;
}

@synthesize sessionIsValid = _sessionIsValid;

#pragma mark - Singleton

+ (instancetype _Nonnull)sharedInstance {
    static NFKURLSessionManager *_sharedInstance = nil;
    static dispatch_once_t token = 0;
    
    dispatch_once(&token, ^{
        _sharedInstance = [[self.class allocWithZone:nil] init];
        
        NSOperationQueue *queue = [NSOperationQueue new];
        
        queue.underlyingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0ul);
        queue.name = @"com.nfktools.networking.session.privateClientsOperationQueue";
        queue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
        queue.qualityOfService = NSQualityOfServiceDefault; // equals DISPATCH_QUEUE_PRIORITY_DEFAULT;
        
        _sharedInstance->_queue = queue;
        _sharedInstance->_session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration delegate:_sharedInstance delegateQueue:_sharedInstance->_queue];
        _sharedInstance->_sessionIsValid = YES;
        _sharedInstance->_sessionGetterSyncQueue = dispatch_queue_create("com.nfktools.networking.session.privateSessionGetterSyncQueue", DISPATCH_QUEUE_SERIAL);
        
        _sharedInstance.tasksDelegates = [NSMutableDictionary<NSString *, NFKWeakReferenceHolder<id<NFKURLSessionManagerDelegate>> *> dictionary];
        // we need a synchronisation for a modification, since several threads simultaneously can access the `tasksDelegates`;
        _sharedInstance->_tasksDelegatesSyncQueue = dispatch_queue_create("com.nfktools.networking.session.privateTasksDelegateSyncQueue", DISPATCH_QUEUE_SERIAL);
    });
    
    return _sharedInstance;
}

#pragma mark - API

- (NSURLSessionDataTask * _Nullable)dataTaskWithRequest:(NSURLRequest * _Nonnull)request completionHandler:(NFKURLSessionManagerCompletionBlock _Nullable)completionHandler {
    return [self dataTaskWithRequest:request delegate:nil completionHandler:completionHandler];
}

- (NSURLSessionDataTask * _Nullable)dataTaskWithRequest:(NSURLRequest * _Nonnull)request delegate:(id <NSURLSessionDelegate, NSURLSessionDataDelegate> _Nonnull)delegate {
    return [self dataTaskWithRequest:request delegate:delegate completionHandler:nil];
}

- (void)cancelDataTask:(NSURLSessionTask * _Nonnull)dataTask {
    if (dataTask) {
        NSString *key = [self keyForTask:dataTask];
        
        dispatch_sync(_tasksDelegatesSyncQueue, ^{
            [self.tasksDelegates removeObjectForKey:key];
        });
        
        [dataTask cancel];
    }
}

#pragma mark - Setters / Getters

- (NSURLSession * _Nonnull)session {
    // double-checked lock:
    if (!self.sessionIsValid) { // 3rd: the outer `if` - if we have a valid session, do not arrive to a mem-barrier at all;
        // since the dispatch is sync, no need for weakSelf anyway, moreover, we want to keep the self at least until the end of the critical section, and the self is a singleton anyway;
        dispatch_sync(_sessionGetterSyncQueue, ^{ // 2nd: threads sync (the critical section);
            if (!self.sessionIsValid) { // 1st: the inner `if` - create a new session ONLY if needed (on invalidation);
                self->_session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration delegate:self delegateQueue:self.queue];
                self.sessionIsValid = YES;
            }
        });
    }
    
    return _session;
}

#pragma mark - Service

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                                     delegate:(id<NSURLSessionDelegate, NSURLSessionDataDelegate>)delegate
                            completionHandler:(NFKURLSessionManagerCompletionBlock)completionHandler {
    NSURLSessionDataTask *task = nil;
    
    if (completionHandler) {
        task = [self.session dataTaskWithRequest:request completionHandler:completionHandler];
    } else {
        task = [self.session dataTaskWithRequest:request];
    }

    if (task && delegate) {
        NFKWeakReferenceHolder<id<NFKURLSessionManagerDelegate>> *retainPreventionWrapper = [NFKWeakReferenceHolder weakReferenceHolderForObject:delegate];
        NSString *key = [self keyForTask:task];
        
        dispatch_sync(_tasksDelegatesSyncQueue, ^{
            self.tasksDelegates[key] = retainPreventionWrapper;
        });
    }
    
	return task;
}

- (id<NFKURLSessionManagerDelegate>)delegateByTask:(NSURLSessionTask *)task {
    return [self delegateByKey:[self keyForTask:task]];
}

- (id<NFKURLSessionManagerDelegate>)delegateByKey:(NSString * _Nonnull)key {
    __block NFKWeakReferenceHolder *retainPreventionWrapper = nil;
    
    dispatch_sync(_tasksDelegatesSyncQueue, ^{
        retainPreventionWrapper = self.tasksDelegates[key];
    });
    
    return (id<NFKURLSessionManagerDelegate>)retainPreventionWrapper.object;
}

- (NSString * _Nonnull)keyForTask:(NSURLSessionTask *)task {
    // get a pointer value of the task object (aka mem-address as string), it is a dictionary key;
    NSString *key = [NSString stringWithFormat:@"%p", task];
    
    return key;
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error {
    self.sessionIsValid = NO;
    NSAssert(self.sessionIsValid, @"<nfktools> error: session was invalidated, something went wrong.");
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    NSString *key = [self keyForTask:task];
    id delegate = [self delegateByKey:key];
    
    if (delegate && [delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [delegate URLSession:session task:task didCompleteWithError:error];
    }
    
    dispatch_sync(_tasksDelegatesSyncQueue, ^{
        [self.tasksDelegates removeObjectForKey:key];
    });
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request
 completionHandler:(void (^)(NSURLRequest *))completionHandler{
    id delegate = [self delegateByTask:task];
    
    if (delegate && [delegate respondsToSelector:@selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)]) {
        [delegate URLSession:session task:task willPerformHTTPRedirection:response newRequest:request completionHandler:completionHandler];
    } else {
        completionHandler(request);
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    id delegate = [self delegateByTask:task];
    
    if (delegate && [delegate respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [delegate URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    id delegate = [self delegateByTask:dataTask];
    
    if (delegate && [delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [delegate URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
    } else {
        completionHandler(NSURLSessionResponseAllow); // means: if the delegate implements this callback, pass it, else allow it as by default;
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    id delegate = [self delegateByTask:dataTask];
    
    if (delegate && [delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [delegate URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

@end
