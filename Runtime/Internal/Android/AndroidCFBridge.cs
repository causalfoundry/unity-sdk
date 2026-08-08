#if UNITY_ANDROID && !UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.Globalization;
using System.Threading;
using UnityEngine;
using UnityEngine.Scripting;

namespace CausalFoundry.Unity.Internal
{
    /// <summary>Android JNI implementation backed by the Java-only facade AAR.</summary>
    [Preserve]
    internal sealed class AndroidCFBridge : INativeCFBridge
    {
        private const string JavaBridgeClass =
            "ai.causalfoundry.unity.android.CFUnityBridge";
        private const string JavaCallbackInterface =
            "ai.causalfoundry.unity.android.CFUnityCallback";
        private const string UnityPlayerClass = "com.unity3d.player.UnityPlayer";

        private readonly object sync = new object();
        private readonly Dictionary<string, Action<NativeBridgeResult>> pending =
            new Dictionary<string, Action<NativeBridgeResult>>();
        private readonly AndroidJavaClass javaBridge;
        private readonly CallbackProxy callbackProxy;
        private long nextRequestId;

        internal AndroidCFBridge()
        {
            javaBridge = new AndroidJavaClass(JavaBridgeClass);
            callbackProxy = new CallbackProxy(this);
        }

        public bool IsSupported
        {
            get { return true; }
        }

        public event Action<string> ActionOpenedJson;

        public void RequestNotificationPermission(Action<NativeBridgeResult> completion)
        {
            string requestId = Register(completion);
            try
            {
                using (var unityPlayer = new AndroidJavaClass(UnityPlayerClass))
                using (AndroidJavaObject activity =
                    unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
                {
                    if (activity == null)
                    {
                        throw new InvalidOperationException(
                            "UnityPlayer.currentActivity is not available.");
                    }

                    javaBridge.CallStatic(
                        "requestNotificationPermission",
                        activity,
                        requestId,
                        callbackProxy);
                }
            }
            catch (Exception exception)
            {
                FailJniCall(requestId, "request notification permission", exception);
            }
        }

        public void Initialize(
            string sdkKey,
            string optionsJson,
            Action<NativeBridgeResult> completion)
        {
            string requestId = Register(completion);
            try
            {
                using (var unityPlayer = new AndroidJavaClass(UnityPlayerClass))
                using (AndroidJavaObject activity =
                    unityPlayer.GetStatic<AndroidJavaObject>("currentActivity"))
                {
                    if (activity == null)
                    {
                        throw new InvalidOperationException(
                            "UnityPlayer.currentActivity is not available.");
                    }
                    javaBridge.CallStatic(
                        "configure",
                        activity,
                        requestId,
                        sdkKey ?? string.Empty,
                        NormalizeJson(optionsJson),
                        callbackProxy);
                }
            }
            catch (Exception exception)
            {
                FailJniCall(requestId, "initialize", exception);
            }
        }

        public void Identify(
            string userId,
            string action,
            string attributesJson,
            Action<NativeBridgeResult> completion)
        {
            string requestId = Register(completion);
            try
            {
                javaBridge.CallStatic(
                    "identify",
                    requestId,
                    userId ?? string.Empty,
                    action ?? string.Empty,
                    NormalizeJson(attributesJson));
            }
            catch (Exception exception)
            {
                FailJniCall(requestId, "identify", exception);
            }
        }

        public void LogUserCatalog(
            string userId,
            string catalogJson,
            Action<NativeBridgeResult> completion)
        {
            string requestId = Register(completion);
            try
            {
                javaBridge.CallStatic(
                    "logUserCatalog",
                    requestId,
                    userId ?? string.Empty,
                    NormalizeJson(catalogJson));
            }
            catch (Exception exception)
            {
                FailJniCall(requestId, "log user catalog", exception);
            }
        }

        public void LogOtherCatalog(
            string subjectId,
            string catalogJson,
            Action<NativeBridgeResult> completion)
        {
            string requestId = Register(completion);
            try
            {
                javaBridge.CallStatic(
                    "logOtherCatalog",
                    requestId,
                    subjectId ?? string.Empty,
                    NormalizeJson(catalogJson));
            }
            catch (Exception exception)
            {
                FailJniCall(requestId, "log other catalog", exception);
            }
        }

        public void Track(
            string eventName,
            string propertiesJson,
            Action<NativeBridgeResult> completion)
        {
            string requestId = Register(completion);
            try
            {
                javaBridge.CallStatic(
                    "track",
                    requestId,
                    eventName ?? string.Empty,
                    NormalizeJson(propertiesJson));
            }
            catch (Exception exception)
            {
                FailJniCall(requestId, "track", exception);
            }
        }

        public void FetchActions(
            string actionType,
            string renderMethod,
            string deliveryMode,
            string attributesJson,
            Action<NativeBridgeResult> completion)
        {
            string requestId = Register(completion);
            try
            {
                javaBridge.CallStatic(
                    "fetchActions",
                    requestId,
                    actionType ?? string.Empty,
                    renderMethod ?? string.Empty,
                    deliveryMode ?? string.Empty,
                    NormalizeJson(attributesJson));
            }
            catch (Exception exception)
            {
                FailJniCall(requestId, "fetch actions", exception);
            }
        }

        public void ShowInAppMessage(
            string screen,
            Action<NativeBridgeResult> completion)
        {
            string requestId = Register(completion);
            try
            {
                // Empty is the native Core SDK's default/None screen.
                javaBridge.CallStatic("showInAppMessage", requestId, screen ?? string.Empty);
            }
            catch (Exception exception)
            {
                FailJniCall(requestId, "show in-app message", exception);
            }
        }

        public void SetPaused(bool paused, Action<NativeBridgeResult> completion)
        {
            string requestId = Register(completion);
            try
            {
                javaBridge.CallStatic("setPaused", requestId, paused);
            }
            catch (Exception exception)
            {
                FailJniCall(requestId, paused ? "pause the SDK" : "resume the SDK", exception);
            }
        }

        private string Register(Action<NativeBridgeResult> completion)
        {
            string requestId = Interlocked.Increment(ref nextRequestId)
                .ToString(CultureInfo.InvariantCulture);
            if (completion != null)
            {
                lock (sync)
                {
                    pending[requestId] = completion;
                }
            }
            return requestId;
        }

        private void HandleResult(
            string requestId,
            bool success,
            string payloadJson,
            string errorCode,
            string errorMessage)
        {
            Action<NativeBridgeResult> completion;
            lock (sync)
            {
                if (!pending.TryGetValue(requestId ?? string.Empty, out completion))
                {
                    return;
                }
                pending.Remove(requestId);
            }

            NativeBridgeResult result = success
                ? NativeBridgeResult.Success(payloadJson)
                : NativeBridgeResult.Failure(
                    string.IsNullOrEmpty(errorCode) ? "native_error" : errorCode,
                    string.IsNullOrEmpty(errorMessage)
                        ? "The Android Core SDK call failed."
                        : errorMessage);
            PostToUnityThread(delegate { completion(result); });
        }

        private void HandleActionOpened(string attributesJson)
        {
            string safeJson = NormalizeJson(attributesJson);
            PostToUnityThread(
                delegate
                {
                    Action<string> handlers = ActionOpenedJson;
                    if (handlers != null)
                    {
                        handlers(safeJson);
                    }
                });
        }

        private void FailJniCall(string requestId, string operation, Exception exception)
        {
            Action<NativeBridgeResult> completion;
            lock (sync)
            {
                if (!pending.TryGetValue(requestId, out completion))
                {
                    return;
                }
                pending.Remove(requestId);
            }

            string message = "Android JNI could not " + operation + ": " + exception.Message;
            PostToUnityThread(
                delegate
                {
                    completion(NativeBridgeResult.Failure("jni_exception", message));
                });
        }

        private void PostToUnityThread(Action action)
        {
            UnityCallbackDispatcher.Run(action);
        }

        private static string NormalizeJson(string json)
        {
            return string.IsNullOrEmpty(json) ? "{}" : json;
        }

        [Preserve]
        private sealed class CallbackProxy : AndroidJavaProxy
        {
            private readonly AndroidCFBridge owner;

            internal CallbackProxy(AndroidCFBridge owner)
                : base(JavaCallbackInterface)
            {
                this.owner = owner;
            }

            [Preserve]
            public void onResult(
                string requestId,
                bool success,
                string payloadJson,
                string errorCode,
                string errorMessage)
            {
                owner.HandleResult(
                    requestId,
                    success,
                    payloadJson,
                    errorCode,
                    errorMessage);
            }

            [Preserve]
            public void onActionOpened(string attributesJson)
            {
                owner.HandleActionOpened(attributesJson);
            }
        }
    }
}
#endif
