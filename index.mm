#include <node_api.h>
#include <napi-macros.h>
#include <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include <LocalAuthentication/LocalAuthentication.h>
#include <Security/Security.h>
#include <string.h>

#define NAPI_RETURN_THROWS(call, message) \
  if ((call)) { \
    napi_throw_error(env, NULL, message); \
    return NULL; \
  }

#define NAPI_RETURN_BOOLEAN(name) \
  napi_value return_bool; \
  NAPI_STATUS_THROWS(napi_get_boolean(env, name, &return_bool)) \
  return return_bool;

#define NAPI_RETURN_UNDEFINED() \
  napi_value return_undefined; \
  NAPI_STATUS_THROWS(napi_get_undefined(env, &return_undefined)) \
  return return_undefined;

#define NAPI_ASSERT_ARGV_MIN(n) \
  NAPI_RETURN_THROWS(argc < n, "Unsufficient arguments provided. Expected " #n)

#define TOUCHID_UNDEFINED -1
#define TOUCHID_AVAILABLE 1
#define TOUCHID_NOT_AVAILABLE 0

typedef enum {
    kTouchIDResultWaiting,
    kTouchIDResultAllowed,
    kTouchIDResultFailed
} TouchIDResult;

NAPI_METHOD(canAuthenticate) {
  LAContext* context = [[LAContext alloc] init];
  NSError* error = nil;
  bool can_authenticate = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error];
  [context release];

  if (error == nil) {
    NAPI_RETURN_BOOLEAN(can_authenticate);
  } else {
    NAPI_RETURN_UNDEFINED();
  }
}

typedef struct async_authenticate_request {
  napi_async_work task;
  napi_ref cb;

  NSString* message;
  BOOL result;
  char * error;
  size_t len;
  const char * exception;
} async_read_timeout_request;

void async_authenticate_execute (napi_env env, void* req_v) {
  async_authenticate_request * req = (async_authenticate_request *)req_v;

  @try {
      LAContext* context = [[LAContext alloc] init];
      __block TouchIDResult result = kTouchIDResultWaiting;
      [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
          localizedReason:req->message reply:^(BOOL success, NSError* error) {

          if (error != nil) {
            const char * msg = [[error localizedDescription] UTF8String];
            size_t len = strlen(msg) + 1;
            req->error = (char *) malloc(len);
            strncpy(req->error, msg, len);
          }

          result = success ? kTouchIDResultAllowed : kTouchIDResultFailed;
          CFRunLoopWakeUp(CFRunLoopGetCurrent());
      }];

      while (result == kTouchIDResultWaiting)
          CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);

      req->result = result == kTouchIDResultAllowed;
  }
  @catch (NSException* exception) {
      req->exception = [exception.reason UTF8String];
  }
}

void async_authenticate_complete(napi_env env, napi_status status, void* req_v) {
  async_authenticate_request * req = (async_authenticate_request *)req_v;
  NAPI_STATUS_THROWS(status);

  if (req->exception != NULL) {
    napi_throw_error(env, NULL, req->exception);
    goto cleanup;
  }

  napi_value global;
  NAPI_STATUS_THROWS(napi_get_global(env, &global));

  napi_value argv[2];
  if (req->error != NULL) {
    napi_value err_msg;
    NAPI_STATUS_THROWS(napi_create_string_utf8(env, (const char *) req->error, NAPI_AUTO_LENGTH, &err_msg));
    free(req->error);
    req->error = NULL;
    NAPI_STATUS_THROWS(napi_create_error(env, NULL, err_msg, &argv[0]));
    NAPI_STATUS_THROWS(napi_get_undefined(env, &argv[1]));
  } else {
    NAPI_STATUS_THROWS(napi_get_null(env, &argv[0]));
    NAPI_STATUS_THROWS(napi_get_boolean(env, req->result, &argv[1]));
  }

  napi_value callback;
  NAPI_STATUS_THROWS(napi_get_reference_value(env, req->cb, &callback));

  napi_value return_val;
  NAPI_STATUS_THROWS(napi_call_function(env, global, callback, 2, argv, &return_val));
cleanup:
  NAPI_STATUS_THROWS(napi_delete_reference(env, req->cb));
  NAPI_STATUS_THROWS(napi_delete_async_work(env, req->task));
  free(req);
  return void();
}

NAPI_METHOD(authenticate) {
  NAPI_ARGV(2)
  NAPI_ASSERT_ARGV_MIN(2)
  NAPI_ARGV_UTF8(message, 256, 0)
  napi_value cb = argv[1];

  async_authenticate_request * req = (async_authenticate_request *) malloc(sizeof(async_authenticate_request));
  req->message = [NSString stringWithUTF8String:message];
  req->error = NULL;
  req->exception = NULL;

  NAPI_STATUS_THROWS(napi_create_reference(env, cb, 1, &req->cb));

  napi_value async_resource_name;
  NAPI_STATUS_THROWS(napi_create_string_utf8(env, "touchid:authenticate", NAPI_AUTO_LENGTH, &async_resource_name))
  napi_create_async_work(env, NULL, async_resource_name,
                                   async_authenticate_execute,
                                   async_authenticate_complete,
                                   (void*)req, &req->task);

  NAPI_STATUS_THROWS(napi_queue_async_work(env, req->task))

  return NULL;
}

NAPI_INIT() {
  NAPI_EXPORT_FUNCTION(canAuthenticate)
  NAPI_EXPORT_FUNCTION(authenticate)
}
