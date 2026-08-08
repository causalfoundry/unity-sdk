using System;

namespace CausalFoundry.Unity.Internal
{
    /// <summary>
    /// Contract implemented by each native platform bridge. JSON is UTF-16 managed text containing
    /// UTF-8-compatible JSON. Every supplied completion must be invoked at most once on Unity's main
    /// thread. Identify and Track success means locally accepted; catalog success means
    /// validated and dispatched to the native SDK. None of these acknowledgements means uploaded.
    /// </summary>
    internal interface INativeCFBridge
    {
        bool IsSupported { get; }

        /// <summary>Full native action-open attributes encoded as one JSON object.</summary>
        event Action<string> ActionOpenedJson;

        void RequestNotificationPermission(Action<NativeBridgeResult> completion);

        void Initialize(string sdkKey, string optionsJson, Action<NativeBridgeResult> completion);

        void Identify(
            string userId,
            string action,
            string attributesJson,
            Action<NativeBridgeResult> completion);

        void LogUserCatalog(
            string userId,
            string catalogJson,
            Action<NativeBridgeResult> completion);

        void LogOtherCatalog(
            string subjectId,
            string catalogJson,
            Action<NativeBridgeResult> completion);

        void Track(
            string eventName,
            string propertiesJson,
            Action<NativeBridgeResult> completion);

        void FetchActions(
            string actionType,
            string renderMethod,
            string deliveryMode,
            string attributesJson,
            Action<NativeBridgeResult> completion);

        void ShowInAppMessage(string screen, Action<NativeBridgeResult> completion);

        void SetPaused(bool paused, Action<NativeBridgeResult> completion);
    }

    /// <summary>Native-to-managed completion envelope shared by both platform bridges.</summary>
    internal sealed class NativeBridgeResult
    {
        private NativeBridgeResult(
            bool isSuccess,
            string payloadJson,
            string errorCode,
            string errorMessage)
        {
            IsSuccess = isSuccess;
            PayloadJson = payloadJson;
            ErrorCode = errorCode;
            ErrorMessage = errorMessage;
        }

        internal bool IsSuccess { get; private set; }

        internal string PayloadJson { get; private set; }

        internal string ErrorCode { get; private set; }

        internal string ErrorMessage { get; private set; }

        internal static NativeBridgeResult Success(string payloadJson)
        {
            return new NativeBridgeResult(true, payloadJson, null, null);
        }

        internal static NativeBridgeResult Success()
        {
            return Success(null);
        }

        internal static NativeBridgeResult Failure(string errorCode, string errorMessage)
        {
            return new NativeBridgeResult(false, null, errorCode, errorMessage);
        }
    }

    internal static class NativeCFBridgeFactory
    {
        internal static INativeCFBridge Create()
        {
            try
            {
#if UNITY_ANDROID && !UNITY_EDITOR
                return new AndroidCFBridge();
#elif UNITY_IOS && !UNITY_EDITOR
                return new IosCFBridge();
#else
                return new NoOpCFBridge();
#endif
            }
            catch (Exception exception)
            {
                return new UnavailableCFBridge(exception);
            }
        }
    }

    /// <summary>Non-throwing fallback when a mobile native bridge cannot be constructed.</summary>
    internal sealed class UnavailableCFBridge : INativeCFBridge
    {
        private readonly string message;

        internal UnavailableCFBridge(Exception exception)
        {
            message = "The Causal Foundry native bridge could not be loaded.";
            if (exception != null && !string.IsNullOrEmpty(exception.Message))
            {
                message += " " + exception.Message;
            }
        }

        public bool IsSupported
        {
            get { return true; }
        }

        public event Action<string> ActionOpenedJson
        {
            add { }
            remove { }
        }

        public void RequestNotificationPermission(Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void Initialize(string sdkKey, string optionsJson, Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void Identify(
            string userId,
            string action,
            string attributesJson,
            Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void LogUserCatalog(
            string userId,
            string catalogJson,
            Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void LogOtherCatalog(
            string subjectId,
            string catalogJson,
            Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void Track(
            string eventName,
            string propertiesJson,
            Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void FetchActions(
            string actionType,
            string renderMethod,
            string deliveryMode,
            string attributesJson,
            Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void ShowInAppMessage(string screen, Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void SetPaused(bool paused, Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        private void Complete(Action<NativeBridgeResult> completion)
        {
            if (completion != null)
            {
                completion(NativeBridgeResult.Failure("bridge_unavailable", message));
            }
        }
    }

    /// <summary>
    /// Intentional fallback for the Unity Editor and non-mobile players. It preserves the public
    /// SDK lifecycle and callback contract without invoking native Android or iOS code.
    /// </summary>
    internal sealed class NoOpCFBridge : INativeCFBridge
    {
        public bool IsSupported
        {
            get { return true; }
        }

        public event Action<string> ActionOpenedJson
        {
            add { }
            remove { }
        }

        public void RequestNotificationPermission(Action<NativeBridgeResult> completion)
        {
            if (completion != null)
            {
                completion(NativeBridgeResult.Success("{\"status\":\"not_required\"}"));
            }
        }

        public void Initialize(string sdkKey, string optionsJson, Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void Identify(
            string userId,
            string action,
            string attributesJson,
            Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void LogUserCatalog(
            string userId,
            string catalogJson,
            Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void LogOtherCatalog(
            string subjectId,
            string catalogJson,
            Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void Track(
            string eventName,
            string propertiesJson,
            Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void FetchActions(
            string actionType,
            string renderMethod,
            string deliveryMode,
            string attributesJson,
            Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void ShowInAppMessage(string screen, Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        public void SetPaused(bool paused, Action<NativeBridgeResult> completion)
        {
            Complete(completion);
        }

        private static void Complete(Action<NativeBridgeResult> completion)
        {
            if (completion != null)
            {
                completion(NativeBridgeResult.Success());
            }
        }
    }
}
