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

RCT_REMAP_METHOD(startWorker,
                 name: (NSString *)name
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  if (workers == nil) {
    workers = [[NSMutableDictionary alloc] init];
  }


  NSString *workerId = [[NSUUID UUID] UUIDString];

  NSURL *workerURL = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:name fallbackResource:name];

/*
  NSDictionary *args = @{@"id" : workerId,
                        @"workerURL" : workerURL};
*/
  // [self performSelectorInBackground:@selector(doLoadJs:) withObject: workerURL];

  NSLog(@"starting Worker %@", [workerURL absoluteString]);
  JSContext *context = [[JSContext alloc] initWithVirtualMachine:[[JSVirtualMachine alloc] init]];
  NSString *jsString = [NSString stringWithContentsOfURL:workerURL encoding:NSUTF8StringEncoding error:nil];

  // Redirect console.log statements to xcode
  [context evaluateScript:@"var console = {}"];
  context[@"console"][@"log"] = ^(NSString *message) {
    NSLog(@"Javascript log: %@", message);
  };
  [context evaluateScript:jsString];

  // setup callback from js->objective c
  context[@"postMessage"] = ^(NSString *message) {
    NSLog(@"main js got a message from js : %@", message);
    [self sendEventWithName:workerId body:message];
  };

  NSString *moduleIdStr = [self getModuleId:jsString];

  Worker *w = [[Worker alloc] init];
  [w setModuleId: moduleIdStr];
  [w setWorkerId: workerId];
  [w setContext: context];
  [workers setObject:w forKey:workerId];

  resolve(workerId);
}


// - (void) doLoadJs:(NSURL *)workerURL {
//   RCTBridge *workerBridge = [[RCTBridge alloc] initWithBundleURL:workerURL
//                                                   moduleProvider:nil
//                                                    launchOptions:nil];
//   WorkerSelfManager *workerSelf = [workerBridge moduleForName:@"WorkerSelfManager"];
//   [workerSelf setWorkerId:123];
//   // [workerSelf setParentBridge:self.bridge];
//   [workers setObject:workerBridge forKey:[NSNumber numberWithInt:123]];
// }

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
  [onmessageFunc callWithArguments:@[message]];
}

- (NSString*) getModuleId: (NSString*) jsBundleStr {
  NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"require\\(([0-9]+)"
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

- (dispatch_queue_t)methodQueue
{
  return dispatch_queue_create("com.swingeducation.worker", DISPATCH_QUEUE_SERIAL);
}

- (NSArray<NSString*> *) supportedEvents {
  return [workers allKeys];
}

@end
