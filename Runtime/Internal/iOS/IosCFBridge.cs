#if UNITY_IOS && !UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using AOT;
using UnityEngine;

namespace CausalFoundry.Unity.Internal
{
    internal sealed class IosCFBridge : INativeCFBridge
    {
        private const string NativeLibrary = "__Internal";
        private const int MaximumPendingActionOpens = 32;

        private static readonly object StaticGate = new object();
        private static readonly IDictionary<ulong, Action<NativeBridgeResult>> Completions =
            new Dictionary<ulong, Action<NativeBridgeResult>>();
        private static readonly NativeResultCallback ResultCallback = HandleNativeResult;
        private static readonly NativeActionOpenedCallback ActionCallback = HandleNativeActionOpened;

        private static long nextRequestId;
        private static bool callbacksRegistered;
        private static IosCFBridge activeBridge;

        private readonly object actionGate = new object();
        private readonly Queue<string> pendingActionOpens = new Queue<string>();
        private Action<string> actionOpenedJson;

        internal IosCFBridge()
        {
            bool registerCallbacks = false;
            lock (StaticGate)
            {
                activeBridge = this;
                if (!callbacksRegistered)
                {
                    callbacksRegistered = true;
                    registerCallbacks = true;
                }
            }

            // Register outside StaticGate: native registration can synchronously flush an action
            // that was opened before managed startup, and that callback also takes StaticGate.
            if (registerCallbacks)
            {
                CFU_RegisterCallbacks(ResultCallback, ActionCallback);
            }
        }

        public bool IsSupported
        {
            get { return CFU_IsSupported() != 0; }
        }

        public event Action<string> ActionOpenedJson
        {
            add
            {
                if (value == null)
                {
                    return;
                }

                string[] pending;
                lock (actionGate)
                {
                    actionOpenedJson += value;
                    pending = pendingActionOpens.ToArray();
                    pendingActionOpens.Clear();
                }

                for (int i = 0; i < pending.Length; i++)
                {
                    InvokeActionSubscriber(value, pending[i]);
                }
            }
            remove
            {
                lock (actionGate)
                {
                    actionOpenedJson -= value;
                }
            }
        }

        public void RequestNotificationPermission(Action<NativeBridgeResult> completion)
        {
            ulong requestId = AddCompletion(completion);
            CFU_RequestNotificationPermission(requestId);
        }

        public void Initialize(string sdkKey, string optionsJson, Action<NativeBridgeResult> completion)
        {
            ulong requestId = AddCompletion(completion);
            using (var nativeSdkKey = new NativeUtf8String(sdkKey))
            using (var nativeOptions = new NativeUtf8String(optionsJson))
            {
                CFU_Initialize(requestId, nativeSdkKey.Pointer, nativeOptions.Pointer);
            }
        }

        public void Identify(
            string userId,
            string action,
            string attributesJson,
            Action<NativeBridgeResult> completion)
        {
            ulong requestId = AddCompletion(completion);
            using (var nativeUserId = new NativeUtf8String(userId))
            using (var nativeAction = new NativeUtf8String(action))
            using (var nativeAttributes = new NativeUtf8String(attributesJson))
            {
                CFU_Identify(
                    requestId,
                    nativeUserId.Pointer,
                    nativeAction.Pointer,
                    nativeAttributes.Pointer);
            }
        }

        public void LogUserCatalog(
            string userId,
            string catalogJson,
            Action<NativeBridgeResult> completion)
        {
            ulong requestId = AddCompletion(completion);
            using (var nativeUserId = new NativeUtf8String(userId))
            using (var nativeCatalog = new NativeUtf8String(catalogJson))
            {
                CFU_LogUserCatalog(
                    requestId,
                    nativeUserId.Pointer,
                    nativeCatalog.Pointer);
            }
        }

        public void LogOtherCatalog(
            string subjectId,
            string catalogJson,
            Action<NativeBridgeResult> completion)
        {
            ulong requestId = AddCompletion(completion);
            using (var nativeSubjectId = new NativeUtf8String(subjectId))
            using (var nativeCatalog = new NativeUtf8String(catalogJson))
            {
                CFU_LogOtherCatalog(
                    requestId,
                    nativeSubjectId.Pointer,
                    nativeCatalog.Pointer);
            }
        }

        public void Track(
            string eventName,
            string propertiesJson,
            Action<NativeBridgeResult> completion)
        {
            ulong requestId = AddCompletion(completion);
            using (var nativeEventName = new NativeUtf8String(eventName))
            using (var nativeProperties = new NativeUtf8String(propertiesJson))
            {
                CFU_Track(requestId, nativeEventName.Pointer, nativeProperties.Pointer);
            }
        }

        public void FetchActions(
            string actionType,
            string renderMethod,
            string deliveryMode,
            string attributesJson,
            Action<NativeBridgeResult> completion)
        {
            ulong requestId = AddCompletion(completion);
            using (var nativeType = new NativeUtf8String(actionType))
            using (var nativeRender = new NativeUtf8String(renderMethod))
            using (var nativeDelivery = new NativeUtf8String(deliveryMode))
            using (var nativeAttributes = new NativeUtf8String(attributesJson))
            {
                CFU_FetchActions(
                    requestId,
                    nativeType.Pointer,
                    nativeRender.Pointer,
                    nativeDelivery.Pointer,
                    nativeAttributes.Pointer);
            }
        }

        public void ShowInAppMessage(string screen, Action<NativeBridgeResult> completion)
        {
            ulong requestId = AddCompletion(completion);
            using (var nativeScreen = new NativeUtf8String(screen))
            {
                CFU_ShowInAppMessage(requestId, nativeScreen.Pointer);
            }
        }

        public void SetPaused(bool paused, Action<NativeBridgeResult> completion)
        {
            ulong requestId = AddCompletion(completion);
            CFU_SetPaused(requestId, paused ? 1 : 0);
        }

        private static ulong AddCompletion(Action<NativeBridgeResult> completion)
        {
            ulong requestId = unchecked((ulong)Interlocked.Increment(ref nextRequestId));
            if (requestId == 0)
            {
                requestId = unchecked((ulong)Interlocked.Increment(ref nextRequestId));
            }

            lock (StaticGate)
            {
                Completions[requestId] = completion;
            }
            return requestId;
        }

        [MonoPInvokeCallback(typeof(NativeResultCallback))]
        private static void HandleNativeResult(
            ulong requestId,
            int status,
            IntPtr payload,
            IntPtr errorCode,
            IntPtr errorMessage)
        {
            Action<NativeBridgeResult> completion;
            lock (StaticGate)
            {
                if (!Completions.TryGetValue(requestId, out completion))
                {
                    return;
                }
                Completions.Remove(requestId);
            }

            if (completion == null)
            {
                return;
            }

            NativeBridgeResult result = status == 0
                ? NativeBridgeResult.Success(Utf8FromNative(payload))
                : NativeBridgeResult.Failure(
                    Utf8FromNative(errorCode) ?? "native_failure",
                    Utf8FromNative(errorMessage) ?? "The native iOS SDK operation failed.");

            try
            {
                completion(result);
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
        }

        [MonoPInvokeCallback(typeof(NativeActionOpenedCallback))]
        private static void HandleNativeActionOpened(IntPtr attributesJson)
        {
            string json = Utf8FromNative(attributesJson) ?? "{}";
            IosCFBridge bridge;
            lock (StaticGate)
            {
                bridge = activeBridge;
            }
            if (bridge != null)
            {
                bridge.ReceiveActionOpened(json);
            }
        }

        private void ReceiveActionOpened(string json)
        {
            Action<string> subscriber;
            lock (actionGate)
            {
                subscriber = actionOpenedJson;
                if (subscriber == null)
                {
                    if (pendingActionOpens.Count == MaximumPendingActionOpens)
                    {
                        pendingActionOpens.Dequeue();
                    }
                    pendingActionOpens.Enqueue(json);
                    return;
                }
            }
            InvokeActionSubscriber(subscriber, json);
        }

        private static void InvokeActionSubscriber(Action<string> subscriber, string json)
        {
            try
            {
                subscriber(json);
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
        }

        private static string Utf8FromNative(IntPtr pointer)
        {
            if (pointer == IntPtr.Zero)
            {
                return null;
            }

            int length = 0;
            while (Marshal.ReadByte(pointer, length) != 0)
            {
                length++;
            }
            if (length == 0)
            {
                return string.Empty;
            }

            var bytes = new byte[length];
            Marshal.Copy(pointer, bytes, 0, length);
            return Encoding.UTF8.GetString(bytes, 0, bytes.Length);
        }

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void NativeResultCallback(
            ulong requestId,
            int status,
            IntPtr payload,
            IntPtr errorCode,
            IntPtr errorMessage);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
        private delegate void NativeActionOpenedCallback(IntPtr attributesJson);

        private sealed class NativeUtf8String : IDisposable
        {
            internal NativeUtf8String(string value)
            {
                byte[] bytes = Encoding.UTF8.GetBytes(value ?? string.Empty);
                Pointer = Marshal.AllocHGlobal(bytes.Length + 1);
                Marshal.Copy(bytes, 0, Pointer, bytes.Length);
                Marshal.WriteByte(Pointer, bytes.Length, 0);
            }

            internal IntPtr Pointer { get; private set; }

            public void Dispose()
            {
                if (Pointer != IntPtr.Zero)
                {
                    Marshal.FreeHGlobal(Pointer);
                    Pointer = IntPtr.Zero;
                }
            }
        }

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern int CFU_IsSupported();

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern void CFU_RegisterCallbacks(
            NativeResultCallback resultCallback,
            NativeActionOpenedCallback actionOpenedCallback);

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern void CFU_Initialize(ulong requestId, IntPtr sdkKey, IntPtr optionsJson);

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern void CFU_RequestNotificationPermission(ulong requestId);

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern void CFU_Identify(
            ulong requestId,
            IntPtr userId,
            IntPtr action,
            IntPtr attributesJson);

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern void CFU_LogUserCatalog(
            ulong requestId,
            IntPtr userId,
            IntPtr catalogJson);

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern void CFU_LogOtherCatalog(
            ulong requestId,
            IntPtr subjectId,
            IntPtr catalogJson);

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern void CFU_Track(ulong requestId, IntPtr eventName, IntPtr propertiesJson);

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern void CFU_FetchActions(
            ulong requestId,
            IntPtr actionType,
            IntPtr renderMethod,
            IntPtr deliveryMode,
            IntPtr attributesJson);

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern void CFU_ShowInAppMessage(ulong requestId, IntPtr screen);

        [DllImport(NativeLibrary, CallingConvention = CallingConvention.Cdecl)]
        private static extern void CFU_SetPaused(ulong requestId, int paused);
    }
}
#endif
