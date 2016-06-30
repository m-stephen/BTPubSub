# BTPubSub
之前写的一个关于消息传递的私有pod，最近开源出来实践一下

##  灵感来自于Glow.Inc团队的PubSub Category.
 
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
  
  
