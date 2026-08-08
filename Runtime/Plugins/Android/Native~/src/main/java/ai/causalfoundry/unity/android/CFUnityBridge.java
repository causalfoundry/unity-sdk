package ai.causalfoundry.unity.android;

import android.app.Activity;

/** Public, Java-only JNI facade used by the managed Unity bridge. */
public final class CFUnityBridge {
    private CFUnityBridge() {
    }

    /**
     * Normal path. The Startup initializer has already retained the Application instance.
     */
    public static void configure(
        String requestId,
        String sdkKey,
        String optionsJson,
        CFUnityCallback callback) {
        CFNativeState.setCallback(callback);
        CFNativeState.configure(requestId, sdkKey, optionsJson);
    }

    /**
     * Defensive fallback for hosts that deliberately disable AndroidX Startup discovery.
     * This cannot recover Activity lifecycle events that occurred before this call.
     */
    public static void configure(
        Activity activity,
        String requestId,
        String sdkKey,
        String optionsJson,
        CFUnityCallback callback) {
        if (activity != null && activity.getApplication() != null) {
            CFNativeState.startup(activity.getApplication());
        }
        configure(requestId, sdkKey, optionsJson, callback);
    }

    public static void identify(
        String requestId,
        String userId,
        String action,
        String attributesJson) {
        CFNativeState.identify(requestId, userId, action, attributesJson);
    }

    public static void logUserCatalog(
        String requestId,
        String userId,
        String catalogJson) {
        CFNativeState.logUserCatalog(requestId, userId, catalogJson);
    }

    public static void logOtherCatalog(
        String requestId,
        String subjectId,
        String catalogJson) {
        CFNativeState.logOtherCatalog(requestId, subjectId, catalogJson);
    }

    public static void track(
        String requestId,
        String eventName,
        String propertiesJson) {
        CFNativeState.track(requestId, eventName, propertiesJson);
    }

    public static void fetchActions(
        String requestId,
        String actionType,
        String renderMethod,
        String deliveryMode,
        String attributesJson) {
        CFNativeState.fetchActions(
            requestId,
            actionType,
            renderMethod,
            deliveryMode,
            attributesJson);
    }

    public static void showInAppMessage(String requestId, String screen) {
        CFNativeState.showInAppMessage(requestId, screen);
    }

    public static void setPaused(String requestId, boolean paused) {
        CFNativeState.setPaused(requestId, paused);
    }

    /**
     * Requests the Android 13 notification permission from the current host Activity. Calls made
     * while one prompt is active share that prompt and each receive exactly one result.
     */
    public static void requestNotificationPermission(
        Activity activity,
        String requestId,
        CFUnityCallback callback) {
        CFNotificationPermissionFragment.request(activity, requestId, callback);
    }
}
