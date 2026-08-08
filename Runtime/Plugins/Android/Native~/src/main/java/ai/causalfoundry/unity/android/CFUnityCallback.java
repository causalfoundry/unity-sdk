package ai.causalfoundry.unity.android;

/**
 * Stable JNI callback surface implemented by Unity's AndroidJavaProxy.
 * Complex values stay as JSON so the bridge does not expose Kotlin collection types to C#.
 */
public interface CFUnityCallback {
    void onResult(
        String requestId,
        boolean success,
        String payloadJson,
        String errorCode,
        String errorMessage);

    void onActionOpened(String attributesJson);
}
