#ifndef Worker_h
#define Worker_h

//#import <JavaScriptCore/JavaScriptCore.h>
#import <Foundation/Foundation.h>

@class JSContext;
@interface Worker: NSObject
  @property NSString *workerId;
  @property NSString *moduleId;
  @property JSContext *context;
@end

#endif
