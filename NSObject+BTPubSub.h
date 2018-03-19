//
//  NSObject+BTPubSub.h
//  GoodLawyer_UserClient
//
//  Created by truestyle on 16/5/11.


/*
  灵感来自于Glow.Inc团队的PubSub Category.
 
  1.BTPubSub是一款基于NSNotification的消息通信机制，作用于NSObject及其子类上。
  它可以解决自上至下消息传递的困难：view->viewController viewController->ViewModel，
  让双向传递和跨层传递（虽然并不推荐这样做）变的更加容易。
 
  2.'订阅-发布' 的设计模式，让NSObject及其子类有发布和订阅消息的能力，并处理相关的参数和事件。
  同时，它也支持仅仅订阅一次消息。订阅时，可以逐条订阅，也可以组合订阅（推荐）
  
  3.基于block和selector（推荐）的回调方式：
  '(BTEventHandler)handler' 函数参数中实现该block即可接受消息传递
  '- (void)handlePublishedEvent:(BTEvent *)event' 在类中实现该方法即可接受消息的传递
  注意：当你同时实现两种回调时，两者（block和selector）都会被触发
  
  4.无需在dealloc里取消订阅。当然，也提供了手动取消订阅的方法，以供更灵活的使用。
  需要注意的是，基于block使用回调时，需要确保消除循环引用，推荐使用@weakify @strongify的宏去打破retain cycle
 
  5.由于它基于NSNoticationCenter的defaultCenter工作，同样支持系统消息，例如：
  UIApplicationDidEnterBackgroundNotification 等消息的订阅。回调中Event的data属性为notification的userInfo字段
 */

#import <Foundation/Foundation.h>

@class BTEvent;

#define eventCase(x) [event.name isEqualToString:x] 

typedef void (^BTEventHandler)(BTEvent *event);

/**
 *  BTEvent
 *
 *  回调时的事件类。
 *  对于系统消息：UIApplicationDidEnterBackgroundNotification等，data为系统的userInfo字段
 */
@interface BTEvent : NSObject

/**
 *  事件名
 */
@property (nonatomic, copy) NSString *name;

/**
 *  发送事件方
 */
@property (nonatomic, strong) id obj;

/**
 *  携带的数据
 */
@property (nonatomic, strong) id data;

- (id)initWithName:(NSString *)name obj:(id)obj data:(id)data;

@end

@interface NSObject (BTPubSub)

#pragma mark - Class Methods

/**
 *  设置接收消息的线程 mainQueue/currentQueue 
 *  由于NSNotification发送时，如不设置接受线程，回调会触发在发送时的线程。
 *  在做UI相关操作时，要设置回主线程。（如果发布消息时在子线程的话）
 *  默认在原线程接收消息
 *
 *  @param queue 设置的队列 [NSOperationQueue mainQueue] 或 [NSOperationQueue currentQueue]
 */
+ (void)setPubSubQueue:(NSOperationQueue *)queue;

#pragma mark - Publish Methods

/**
 *  发布一条消息
 *
 *  @param eventName 消息名
 */
- (void)publish:(NSString *)eventName;

/**
 *  发布一条消息并携带参数
 *
 *  @param eventName 消息名
 *  @param data      携带的参数
 */
- (void)publish:(NSString *)eventName data:(id)data;

#pragma mark - Subscribe Methods With Selector

/**
 *  订阅一条消息
 *
 *  @param eventName 消息名
 */
- (void)subscribeEvent:(NSString *)eventName;

/**
 *  订阅多条消息
 *
 *  @param eventNameArray 消息名，NSString类型。已做类型保护，错误参数不会进行任何操作
 */
- (void)subscribeEvents:(NSArray<NSString *> *)eventNameArray;

/**
 *  订阅某条消息一次，该消息多次被发送时，回调只会触发一次
 *
 *  @param eventName 消息名
 */
- (void)subscribeOnceEvent:(NSString *)eventName;

/**
 *  订阅多条消息一次，该消息多次被发送时，回调只会触发一次
 *
 *  @param eventNameArray 消息名称
 */
- (void)subscribeOnceEvents:(NSArray<NSString *> *)eventNameArray;

/**
 *  收到消息的回调（建议使用此种方式，代码比较简洁明了，block造成代码过度堆积）
 *  在NSObject的子类中实现该方法即可接收回调，不实现不会回调
 *
 *  @param event 相关事件
 */
- (void)handlePublishedEvent:(BTEvent *)event;

#pragma mark - Subscribe Methods with Block

//下面的方法和上面一致，采用block的方式

- (void)subscribeEvent:(NSString *)eventName handler:(BTEventHandler)handler;

- (void)subscribeEvents:(NSArray<NSString *> *)eventNameArray handler:(BTEventHandler)handler;

- (void)subscribeOnceEvent:(NSString *)eventName handler:(BTEventHandler)handler;

- (void)subscribeOnceEvents:(NSArray<NSString *> *)eventNameArray handler:(BTEventHandler)handler;

#pragma mark - Unsubscribe Methods

/**
 *  取消订阅某条消息
 *
 *  @param eventName 消息名称
 */
- (void)unsubscribeEvent:(NSString *)eventName;

/**
 *  取消订阅所有消息。在需要时候调用，当该类dealloc时，会自动调用此方法。
 */
- (void)unsubscribeAllEvents;

@end
