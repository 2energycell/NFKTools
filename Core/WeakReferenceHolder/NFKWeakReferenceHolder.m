//
//  NFKWeakReferenceHolder.m
//
//
//  Created by Nikita Fedorenko on 01/03/2017.
//  Copyright © 2017 Nikita Fedorenko. All rights reserved.
//

#import "NFKWeakReferenceHolder.h"

@interface NFKWeakReferenceHolder ()

#pragma mark - Public redefinition
@property (nonatomic, weak, readwrite, nullable) NSObject *object;
#pragma mark -

@end

@implementation NFKWeakReferenceHolder {}

+ (instancetype _Nonnull)weakReferenceHolderForObject:(NSObject * _Nonnull)object {
    NFKWeakReferenceHolder *instance = [[self.class allocWithZone:nil] init];
    
    instance.object = object;
    
    return instance;
}

#pragma mark - Dispose

- (void)dealloc {
#ifdef DEBUG
    NSLog(@"%@ deallocated.\nIt's object was: %@", NSStringFromClass(self.class), NSStringFromClass(_object.class));
#endif
}

@end
