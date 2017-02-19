#import "WorkerManager.h"
#import "Worker.h"
#include <stdlib.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import "RCTBridge+Private.h"
#import "RCTEventDispatcher.h"
#import "RCTBundleURLProvider.h"

@implementation WorkerManager

static NSMutableDictionary *workers;
static NSMutableArray *preallocatedWorkerIds;

RCT_EXPORT_MODULE();

RCT_REMAP_METHOD(initJsContext,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    if (workers == nil) {
        workers = [[NSMutableDictionary alloc] init];
    }


    NSString *workerId = [[NSUUID UUID] UUIDString];

    JSContext *context = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];

    // setup callback from js->objective c
    context[@"postMessage"] = ^(NSString *message) {
        NSLog(@"main js got a message from js : %@", message);
        [self sendEventWithName:workerId body:message];
    };

    // Redirect console.log, console.warn, and console.error statements to xcode
    //[context evaluateScript:@"var console = {}"];
    context[@"console"][@"log"] = ^(NSString *message) {
        NSLog(@"Javascript log: %@", message);
    };
    context[@"console"][@"warn"] = ^(NSString *message) {
      NSLog(@"Javascript warn: %@", message);
    };
    context[@"console"][@"error"] = ^(NSString *message) {
      NSLog(@"Javascript error: %@", message);
    };
    context[@"console"][@"info"] = ^(NSString *message) {
      NSLog(@"Javascript info: %@", message);
    };
    context[@"console"][@"debug"] = ^(NSString *message) {
      NSLog(@"Javascript debug: %@", message);
    };

    // Add setTimeout
    // WTF? javascript core doesn't come with setTimeout?
    context[@"setTimeout"] = ^(JSValue* function, JSValue* timeout) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([timeout toInt32] * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
          [function callWithArguments:@[]];
        });
    };

    Worker *w = [[Worker alloc] init];
    [w setWorkerId: workerId];
    [w setContext: context];
    [workers setObject:w forKey:workerId];

    resolve(workerId);
}


RCT_EXPORT_METHOD(startWorker:(NSString *) workerId
                  name: (NSString *)name)
{
  NSURL *workerURL = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:name fallbackResource:name];

  NSLog(@"starting Worker %@", [workerURL absoluteString]);
  NSString *jsString = [NSString stringWithContentsOfURL:workerURL encoding:NSUTF8StringEncoding error:nil];
  Worker *w = workers[workerId];

  NSString *moduleIdStr = [self getModuleId:jsString];

  [w setModuleId: moduleIdStr];
  [workers setObject:w forKey:workerId];

  [[w context] evaluateScript:jsString];
}


RCT_EXPORT_METHOD(stopWorker:(NSString*) workerId)
{
  if (workers == nil) {
    NSLog(@"Empty list of workers. abort stopping worker with id %@", workerId);
    return;
  }

  if (![workers objectForKey:workerId]) {
    NSLog(@"Worker not found. abort stopping worker with id %@", workerId);
    return;
  }

  NSLog(@"Bye, cruel world");
  [workers removeObjectForKey:workerId];
}

RCT_EXPORT_METHOD(postWorkerMessage:(NSString *)workerId message:(NSString *)message)
{
  if (workers == nil) {
    NSLog(@"Empty list of workers. abort posting to worker with id %@", workerId);
    return;
  }

  Worker *w = workers[workerId];
  if (w == nil) {
    NSLog(@"Worker is nil. abort posting to worker with id %@", workerId);
    return;
  }

  NSString *moduleIdStr = [w moduleId];
  JSContext *context = [w context];

  JSValue *onmessageFunc = [context evaluateScript:[NSString stringWithFormat:@"require(%@)['default']", moduleIdStr]];
  if([onmessageFunc isUndefined]){
    onmessageFunc = [context evaluateScript:@"onmessage"];
  }

  if([onmessageFunc isUndefined]) {
    NSLog(@"onmessageFunc is not defined for worker %@", workerId);
  }
  [onmessageFunc callWithArguments:@[message]];
}

- (NSString*) getModuleId: (NSString*) jsBundleStr {
  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@";require\\(([0-9]+)\\);"
                                                                         options:NSRegularExpressionCaseInsensitive error:nil];
  NSArray *matches = [regex matchesInString:jsBundleStr options:0 range:NSMakeRange(0, [jsBundleStr length])];
  NSRange group1 = [matches[0] rangeAtIndex: 1];
  NSString *moduleIdStr = [jsBundleStr substringWithRange:group1];
  return moduleIdStr;
}

- (void)invalidate {
  if (workers == nil) {
    return;
  }

  [workers removeAllObjects];
  workers = nil;
}


- (NSArray<NSString*> *) supportedEvents {
  return [workers allKeys];
}

@end
