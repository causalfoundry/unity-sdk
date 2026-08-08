#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

extern "C" void CFU_EarlyBootstrap(void);
extern "C" void CFU_InstallNotificationDelegate(void);

typedef void (*CFUSetDelegateImplementation)(UIApplication *, SEL, id<UIApplicationDelegate>);
typedef BOOL (*CFUDidFinishImplementation)(
    id<UIApplicationDelegate>,
    SEL,
    UIApplication *,
    NSDictionary *);

static CFUSetDelegateImplementation CFUOriginalSetDelegate;
static CFUDidFinishImplementation CFUOriginalDidFinish;
static id CFUDidFinishFallbackObserver;

static BOOL CFUApplicationDidFinishLaunching(
    id<UIApplicationDelegate> delegate,
    SEL selector,
    UIApplication *application,
    NSDictionary *launchOptions)
{
    // The native SDK registers its UIApplicationDidFinishLaunching observer here, before the
    // delegate returns and UIKit posts that notification. This preserves its app-open event and
    // lets it register BGTaskScheduler identifiers within Apple's launch-time window.
    CFU_EarlyBootstrap();

    BOOL result = YES;
    if (CFUOriginalDidFinish != NULL)
    {
        result = CFUOriginalDidFinish(delegate, selector, application, launchOptions);
    }

    // A host plugin may assign UNUserNotificationCenter.delegate from its launch callback. Install
    // Kenkai after that callback so the bridge can retain and forward to the host delegate while
    // still completing setup before application launch returns.
    CFU_InstallNotificationDelegate();
    return result;
}

static void CFUHookApplicationDelegate(id<UIApplicationDelegate> delegate)
{
    if (delegate == nil)
    {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class delegateClass = object_getClass(delegate);
        SEL selector = @selector(application:didFinishLaunchingWithOptions:);
        Method method = class_getInstanceMethod(delegateClass, selector);
        if (method == NULL)
        {
            return;
        }

        CFUOriginalDidFinish =
            (CFUDidFinishImplementation)method_getImplementation(method);
        const char *types = method_getTypeEncoding(method);

        // class_getInstanceMethod can return an inherited implementation. Add an override when
        // possible so this shim does not alter a base delegate class used elsewhere.
        if (!class_addMethod(
                delegateClass,
                selector,
                (IMP)CFUApplicationDidFinishLaunching,
                types))
        {
            method_setImplementation(method, (IMP)CFUApplicationDidFinishLaunching);
        }
    });
}

static void CFUSetApplicationDelegate(
    UIApplication *application,
    SEL selector,
    id<UIApplicationDelegate> delegate)
{
    CFUHookApplicationDelegate(delegate);
    CFUOriginalSetDelegate(application, selector, delegate);
}

__attribute__((constructor))
static void CFUInstallEarlyBootstrapObserver(void)
{
    @autoreleasepool
    {
        Method setDelegateMethod = class_getInstanceMethod(
            [UIApplication class],
            @selector(setDelegate:));
        if (setDelegateMethod != NULL)
        {
            CFUOriginalSetDelegate =
                (CFUSetDelegateImplementation)method_setImplementation(
                    setDelegateMethod,
                    (IMP)CFUSetApplicationDelegate);
        }

        // Defensive fallback for non-standard hosts that bypass UIApplication.setDelegate:.
        // CFU_EarlyBootstrap is idempotent, so this is harmless after the launch delegate hook.
        CFUDidFinishFallbackObserver =
            [[NSNotificationCenter defaultCenter]
                addObserverForName:UIApplicationDidFinishLaunchingNotification
                            object:nil
                             queue:[NSOperationQueue mainQueue]
                        usingBlock:^(__unused NSNotification *notification)
                        {
                            CFU_EarlyBootstrap();
                            CFU_InstallNotificationDelegate();
                            if (CFUDidFinishFallbackObserver != nil)
                            {
                                [[NSNotificationCenter defaultCenter]
                                    removeObserver:CFUDidFinishFallbackObserver];
                                CFUDidFinishFallbackObserver = nil;
                            }
                        }];
    }
}
