//
//  NSObject+BTPubSub.m
//  GoodLawyer_UserClient
//
//  Created by truestyle on 16/5/11.
//

#import "NSObject+BTPubSub.h"
#import <objc/runtime.h>

#pragma mark - Utilities

static BOOL isEmptyString(NSString *string)
{
    return (![string isKindOfClass:[NSString class]] ||
            !string ||
            [string isEqual:[NSNull null]] ||
            ([string isKindOfClass:[NSString class]] && [@"" isEqualToString:[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]));
}

static void swizzlingMethods(NSString *originalSelectorName, NSString *swizzledSelectorName, id obj){
    if(!obj)
        return;
    if(isEmptyString(originalSelectorName) || isEmptyString(swizzledSelectorName)){
        return;
    }
    
    Class aClass = [obj class];
    
    SEL originalSelector = NSSelectorFromString(originalSelectorName);
    SEL swizzledSelector = NSSelectorFromString(swizzledSelectorName);
    
    Method originalMethod = class_getInstanceMethod(aClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(aClass, swizzledSelector);
    
    BOOL success = class_addMethod(aClass, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
    if (success) {
        class_replaceMethod(aClass, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
    
}

@implementation BTEvent

- (id)initWithName:(NSString *)name obj:(id)obj data:(id)data {
    if (self = [super init]) {
        self.name = name;
        self.obj = obj;
        self.data = data;
    }
    return self;
}

@end

#define weakify(o) autoreleasepool{} __weak typeof(o) o##Weak = o;
#define strongify(o) autoreleasepool{} __strong typeof(o) o = o##Weak;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation NSObject(BTPubSub)

static NSOperationQueue *_pubSubQueue = nil;
static NSString * const kBTPubSubDataKey = @"BTPubSubData";
static char kBTPubSubSubscriptionsKey;

#pragma mark - Class Methods

+ (void)load{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzlingMethods(@"dealloc",@"bt_dealloc",self);
    });
}

+ (void)setPubSubQueue:(NSOperationQueue *)queue {
    _pubSubQueue = queue;
}

#pragma mark - Publish Methods
- (void)publish:(NSString *)name {
    [self publish:name data:nil];
}

- (void)publish:(NSString *)name data:(id)data {
    if(isEmptyString(name))
        return;
    NSDictionary *userInfo = nil;
    if (data != nil) {
        userInfo = @{kBTPubSubDataKey: data};
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:userInfo];
}

- (void)subscribeEvent:(NSString *)eventName{
    if(!isEmptyString(eventName))
        [self subscribeEvents:@[eventName]];
}

- (void)subscribeEvents:(NSArray<NSString *> *)eventNameArray{
    if(nil == eventNameArray){
        return;
    }
    for(NSString *eventName in eventNameArray){
        if(isEmptyString(eventName))
            break;
        @autoreleasepool{
            @weakify(self);
            id observer =  [[NSNotificationCenter defaultCenter] addObserverForName:eventName object:nil queue:_pubSubQueue usingBlock:^(NSNotification *note) {
                @strongify(self);
                id data = [note.userInfo objectForKey:kBTPubSubDataKey] ? [note.userInfo objectForKey:kBTPubSubDataKey] : note.userInfo;
                BTEvent *event = [[BTEvent alloc] initWithName:eventName obj:note.object data:data];
                if([self respondsToSelector:@selector(handlePublishedEvent:)])
                [self handlePublishedEvent:event];
            }];
            NSMutableDictionary *subscriptions = (NSMutableDictionary *)objc_getAssociatedObject(self, &kBTPubSubSubscriptionsKey);
                if (!subscriptions) {
                    subscriptions = [[NSMutableDictionary alloc] init];
                    objc_setAssociatedObject(self, &kBTPubSubSubscriptionsKey, subscriptions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            NSMutableSet *observers = [subscriptions objectForKey:eventName];
            if (!observers) {
                observers = [[NSMutableSet alloc] init];
                [subscriptions setObject:observers forKey:eventName];
            }
            [observers addObject:observer];
        }
    }
}

- (void)subscribeOnceEvent:(NSString *)eventName{
    if(!isEmptyString(eventName))
        [self subscribeOnceEvents:@[eventName]];
}

- (void)subscribeOnceEvents:(NSArray<NSString *> *)eventNameArray{
    if(nil == eventNameArray){
        return;
    }
    for(NSString *eventName in eventNameArray){
        if(isEmptyString(eventName))
            break;
        @autoreleasepool{
            @weakify(self);
            id observer =  [[NSNotificationCenter defaultCenter] addObserverForName:eventName object:nil queue:_pubSubQueue usingBlock:^(NSNotification *note) {
                @strongify(self);
                id data = [note.userInfo objectForKey:kBTPubSubDataKey] ? [note.userInfo objectForKey:kBTPubSubDataKey] : note.userInfo;
                BTEvent *event = [[BTEvent alloc] initWithName:eventName obj:note.object data:data];
                if([self respondsToSelector:@selector(handlePublishedEvent:)]){
                    [self handlePublishedEvent:event];
                    [self unsubscribeEvent:event.name];
                }
            }];
            NSMutableDictionary *subscriptions = (NSMutableDictionary *)objc_getAssociatedObject(self, &kBTPubSubSubscriptionsKey);
            if (!subscriptions) {
                subscriptions = [[NSMutableDictionary alloc] init];
                objc_setAssociatedObject(self, &kBTPubSubSubscriptionsKey, subscriptions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            NSMutableSet *observers = [subscriptions objectForKey:eventName];
            if (!observers) {
                observers = [[NSMutableSet alloc] init];
                [subscriptions setObject:observers forKey:eventName];
            }
            [observers addObject:observer];
        }
    }
    
}

- (void)subscribeEvent:(NSString *)eventName handler:(BTEventHandler)handler{
    if(!isEmptyString(eventName))
        [self subscribeEvents:@[eventName] handler:handler];
}


- (void)subscribeEvents:(NSArray<NSString *> *)eventNameArray handler:(BTEventHandler)handler{
    if(nil == eventNameArray){
        return;
    }
    for(NSString *eventName in eventNameArray){
        if(isEmptyString(eventName))
            break;
        @autoreleasepool{
            id observer =  [[NSNotificationCenter defaultCenter] addObserverForName:eventName object:nil queue:_pubSubQueue usingBlock:^(NSNotification *note) {
                id data = [note.userInfo objectForKey:kBTPubSubDataKey] ? [note.userInfo objectForKey:kBTPubSubDataKey] : note.userInfo;
                BTEvent *event = [[BTEvent alloc] initWithName:eventName obj:note.object data:data];
                if(handler){
                    handler(event);
                }
            }];
            NSMutableDictionary *subscriptions = (NSMutableDictionary *)objc_getAssociatedObject(self, &kBTPubSubSubscriptionsKey);
            if (!subscriptions) {
                subscriptions = [[NSMutableDictionary alloc] init];
                objc_setAssociatedObject(self, &kBTPubSubSubscriptionsKey, subscriptions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            NSMutableSet *observers = [subscriptions objectForKey:eventName];
            if (!observers) {
                observers = [[NSMutableSet alloc] init];
                [subscriptions setObject:observers forKey:eventName];
            }
            [observers addObject:observer];
        }
    }
}

- (void)subscribeOnceEvent:(NSString *)eventName handler:(BTEventHandler)handler{
    if(!isEmptyString(eventName))
        [self subscribeOnceEvents:@[eventName] handler:handler];
}


- (void)subscribeOnceEvents:(NSArray<NSString *> *)eventNameArray handler:(BTEventHandler)handler{
    if(nil == eventNameArray){
        return;
    }
    for(NSString *eventName in eventNameArray){
        if(isEmptyString(eventName))
            break;
        @autoreleasepool{
            @weakify(self);
            id observer =  [[NSNotificationCenter defaultCenter] addObserverForName:eventName object:nil queue:_pubSubQueue usingBlock:^(NSNotification *note) {
                @strongify(self);
                id data = [note.userInfo objectForKey:kBTPubSubDataKey] ? [note.userInfo objectForKey:kBTPubSubDataKey] : note.userInfo;
                BTEvent *event = [[BTEvent alloc] initWithName:eventName obj:note.object data:data];
                if(handler){
                    handler(event);
                    [self unsubscribeEvent:event.name];
                }
            }];
            NSMutableDictionary *subscriptions = (NSMutableDictionary *)objc_getAssociatedObject(self, &kBTPubSubSubscriptionsKey);
            if (!subscriptions) {
                subscriptions = [[NSMutableDictionary alloc] init];
                objc_setAssociatedObject(self, &kBTPubSubSubscriptionsKey, subscriptions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            NSMutableSet *observers = [subscriptions objectForKey:eventName];
            if (!observers) {
                observers = [[NSMutableSet alloc] init];
                [subscriptions setObject:observers forKey:eventName];
            }
            [observers addObject:observer];
        }
    }
}

- (void)unsubscribeEvent:(NSString *)eventName{
    NSMutableDictionary *subscriptions = (NSMutableDictionary *)objc_getAssociatedObject(self, &kBTPubSubSubscriptionsKey);
    if (!subscriptions)
        return;
    NSMutableSet *observers = [subscriptions objectForKey:eventName];
    if (observers) {
        for (id observer in observers) {
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        }
        [subscriptions removeObjectForKey:eventName];
    }
}

- (void)unsubscribeAllEvents{
    NSMutableDictionary *subscriptions = (NSMutableDictionary *)objc_getAssociatedObject(self, &kBTPubSubSubscriptionsKey);
    if (!subscriptions)
        return;
    for (NSString *eventName in subscriptions) {
        NSMutableSet *observers = [subscriptions objectForKey:eventName];
        for (id observer in observers) {
            [[NSNotificationCenter defaultCenter] removeObserver:observer];
        }
    }
    [subscriptions removeAllObjects];
}

- (void)bt_dealloc{
    [self unsubscribeAllEvents];
    [self bt_dealloc];
}

@end

#pragma clang diagnostic pop
