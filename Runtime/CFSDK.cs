using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Threading;
using CausalFoundry.Unity.Internal;
using UnityEngine;

namespace CausalFoundry.Unity
{
    /// <summary>Platform-neutral entry point for the Causal Foundry Android and iOS Core SDKs.</summary>
    public static class CFSDK
    {
        private static readonly object Sync = new object();
        private static readonly List<Action<CFResult>> InitializationCallbacks =
            new List<Action<CFResult>>();
        private static readonly Queue<ActionOpenedEvent> PendingOpenedActions =
            new Queue<ActionOpenedEvent>();
        private const int MaximumPendingOpenedActions = 32;
        internal const string PackageVersion = "1.0.7";

        private static INativeCFBridge bridge;
        private static bool initialized;
        private static bool initializing;
        private static string activeSdkKey;
        private static string activeOptionsJson;
        private static Action<ActionOpenedEvent> actionOpenedHandlers;
        private static int bridgeGeneration;

        private static readonly string[] ReservedTrackEventNames =
        {
            CFEventNames.App,
            CFEventNames.Page,
            CFEventNames.Identify,
            CFEventNames.Media,
            CFEventNames.Search,
            CFEventNames.Rate,
            CFEventNames.ModuleSelection,
            CFEventNames.Track,
            CFEventNames.ActionResponse,
            CFEventNames.NudgeResponse,
            CFEventNames.Item,
            CFEventNames.Delivery,
            CFEventNames.Checkout,
            CFEventNames.Cart,
            CFEventNames.CancelCheckout,
            CFEventNames.ItemReport,
            CFEventNames.ItemRequest,
            CFEventNames.Module,
            CFEventNames.Exam,
            CFEventNames.Question,
            CFEventNames.Level,
            CFEventNames.Milestone,
            CFEventNames.Promo,
            CFEventNames.Survey,
            CFEventNames.Reward,
            CFEventNames.Payment,
            CFEventNames.Patient,
            CFEventNames.Encounter,
            CFEventNames.Appointment,
            CFEventNames.Diagnosis
        };

        private static readonly string[] ReservedCatalogNames =
        {
            "user",
            "media",
            "user_chw",
            "site",
            "patient",
            "drug",
            "grocery",
            "blood",
            "oxygen",
            "medical_equipment",
            "facility",
            "survey",
            "reward",
            "other"
        };

        static CFSDK()
        {
            ReplaceBridge(NativeCFBridgeFactory.Create(), false);
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        private static void ResetAtSubsystemRegistration()
        {
            // Enter Play Mode can keep static fields when domain reload is disabled. Recreate the
            // bridge and clear the managed lifecycle so a previous play session cannot leak its
            // key, callbacks, or queued actions into the next one.
            ReplaceBridge(NativeCFBridgeFactory.Create(), true);
        }

        /// <summary>
        /// Raised on Unity's main thread when a notification or in-app action is opened. Native
        /// bridges retain a cold-start action until this managed subscriber can receive it.
        /// </summary>
        public static event Action<ActionOpenedEvent> ActionOpened
        {
            add
            {
                if (value == null)
                {
                    return;
                }

                UnityCallbackDispatcher.Run(delegate { AddActionOpenedHandler(value); });
            }
            remove
            {
                if (value == null)
                {
                    return;
                }

                UnityCallbackDispatcher.Run(
                    delegate
                    {
                        lock (Sync)
                        {
                            actionOpenedHandlers -= value;
                        }
                    });
            }
        }

        public static bool IsInitialized
        {
            get
            {
                lock (Sync)
                {
                    return initialized;
                }
            }
        }

        /// <summary>
        /// Requests permission to present local notifications. Call this from a user-facing context;
        /// the method does not require SDK initialization. Android 12 and older return NotRequired.
        /// </summary>
        public static void RequestNotificationPermission(
            Action<CFResult<NotificationPermissionStatus>> completion = null)
        {
            INativeCFBridge bridgeSnapshot;
            lock (Sync)
            {
                bridgeSnapshot = bridge;
            }

            var gate = new NativeCompletionGate(
                delegate(NativeBridgeResult nativeResult)
                {
                    Complete(completion, ConvertNotificationPermissionResult(nativeResult));
                });

            try
            {
                if (bridgeSnapshot == null || !bridgeSnapshot.IsSupported)
                {
                    gate.Invoke(
                        NativeBridgeResult.Failure(
                            "unsupported_platform",
                            "Notification permission is available only in Android and iOS player builds."));
                    return;
                }

                bridgeSnapshot.RequestNotificationPermission(gate.Invoke);
            }
            catch (Exception exception)
            {
                gate.Invoke(NativeExceptionResult("request notification permission", exception));
            }
        }

        /// <summary>
        /// Initializes or verifies the native Core SDK. Repeating this call with the same key and
        /// options is idempotent. Mobile lifecycle bootstrap may already have initialized the native
        /// SDK from CFSettings before managed code starts.
        /// </summary>
        public static void Initialize(
            string sdkKey,
            CFOptions options = null,
            Action<CFResult> completion = null)
        {
            string normalizedSdkKey = NormalizeSdkKey(sdkKey);
            if (IsBlank(normalizedSdkKey))
            {
                Complete(
                    completion,
                    CFResult.Failed(
                        CFErrorCode.InvalidArgument,
                        "SDK key cannot be null, empty, or whitespace.",
                        null));
                return;
            }

            CFOptions resolvedOptions = options ?? new CFOptions();
            string optionsJson;
            string serializationError;
            if (!CFJson.TrySerialize(
                    resolvedOptions.ToJsonObject(),
                    out optionsJson,
                    out serializationError))
            {
                Complete(
                    completion,
                    CFResult.Failed(
                        CFErrorCode.SerializationFailure,
                        "Could not serialize SDK options: " + serializationError,
                        null));
                return;
            }

            INativeCFBridge bridgeSnapshot;
            int initializationBridgeGeneration = 0;
            CFResult immediateResult = null;
            lock (Sync)
            {
                if (initialized)
                {
                    bool sameConfiguration =
                        string.Equals(activeSdkKey, normalizedSdkKey, StringComparison.Ordinal) &&
                        string.Equals(activeOptionsJson, optionsJson, StringComparison.Ordinal);
                    immediateResult = sameConfiguration
                        ? CFResult.Succeeded()
                        : CFResult.Failed(
                            CFErrorCode.AlreadyInitialized,
                            "The SDK is already initialized with a different key or options.",
                            null);
                    bridgeSnapshot = null;
                }
                else if (initializing)
                {
                    bool sameConfiguration =
                        string.Equals(activeSdkKey, normalizedSdkKey, StringComparison.Ordinal) &&
                        string.Equals(activeOptionsJson, optionsJson, StringComparison.Ordinal);
                    if (!sameConfiguration)
                    {
                        immediateResult = CFResult.Failed(
                            CFErrorCode.InitializationInProgress,
                            "Initialization is already in progress with a different key or options.",
                            null);
                    }
                    else if (completion != null)
                    {
                        InitializationCallbacks.Add(completion);
                    }

                    bridgeSnapshot = null;
                }
                else
                {
                    initializing = true;
                    activeSdkKey = normalizedSdkKey;
                    activeOptionsJson = optionsJson;
                    if (completion != null)
                    {
                        InitializationCallbacks.Add(completion);
                    }

                    bridgeSnapshot = bridge;
                    initializationBridgeGeneration = bridgeGeneration;
                }
            }

            if (immediateResult != null)
            {
                Complete(completion, immediateResult);
                return;
            }

            if (bridgeSnapshot == null)
            {
                return;
            }

            var gate = new NativeCompletionGate(
                delegate(NativeBridgeResult nativeResult)
                {
                    FinishInitialization(nativeResult, initializationBridgeGeneration);
                });
            try
            {
                bridgeSnapshot.Initialize(normalizedSdkKey, optionsJson, gate.Invoke);
            }
            catch (Exception exception)
            {
                gate.Invoke(NativeExceptionResult("initialize", exception));
            }
        }

        /// <summary>
        /// Loads <see cref="CFSettings"/>, initializes the SDK, identifies the user, and
        /// optionally logs string-valued user-catalog metadata in order.
        /// </summary>
        /// <param name="userId">A stable, unique user identifier supplied by the host application.</param>
        /// <param name="identityAction">
        /// The identity transition to record. Use the lower-level <see cref="Identify"/> method for
        /// <see cref="IdentityAction.Blocked"/> and <see cref="IdentityAction.Unblocked"/>, which
        /// require a blocked reason.
        /// </param>
        /// <param name="userCatalog">
        /// Optional string-valued user dimensions. Null or empty skips the catalog step.
        /// </param>
        /// <param name="completion">
        /// Invoked on Unity's main thread with the first failure, or with success after every
        /// requested operation is accepted by the native SDK.
        /// </param>
        /// <remarks>
        /// Call this method from Unity's main thread because it loads the Resources settings asset.
        /// A successful result confirms native acceptance or dispatch, not server delivery. The
        /// operations are not rolled back: if the catalog step fails, Identify has already succeeded,
        /// so retry <see cref="LogUserCatalog"/> directly instead of retrying this entire method.
        /// </remarks>
        public static void InitializeAndIdentify(
            string userId,
            IdentityAction identityAction,
            IDictionary<string, string> userCatalog = null,
            Action<CFResult> completion = null)
        {
            IDictionary<string, string> catalogSnapshot;
            CFResult catalogFailure;
            if (!TrySnapshotUserCatalog(userCatalog, out catalogSnapshot, out catalogFailure))
            {
                Complete(completion, catalogFailure);
                return;
            }

            UnityCallbackDispatcher.Run(
                delegate
                {
                    CFSettings settings;
                    try
                    {
                        settings = CFSettings.LoadFromResources();
                    }
                    catch (Exception exception)
                    {
                        Complete(
                            completion,
                            InvalidArgument(
                                "Could not load CFSettings from Resources: " +
                                exception.Message));
                        return;
                    }

                    InitializeAndIdentify(
                        settings,
                        userId,
                        identityAction,
                        catalogSnapshot,
                        completion);
                });
        }

        internal static void InitializeAndIdentify(
            CFSettings settings,
            string userId,
            IdentityAction identityAction,
            IDictionary<string, string> userCatalog,
            Action<CFResult> completion)
        {
            if (settings == null)
            {
                Complete(
                    completion,
                    InvalidArgument(
                        "CFSettings is missing. Create " +
                        "Assets/Resources/CausalFoundrySettings.asset before calling this method."));
                return;
            }

            if (IsBlank(settings.SdkKey))
            {
                Complete(
                    completion,
                    InvalidArgument("CFSettings must contain a non-empty SDK key."));
                return;
            }

            if (IsBlank(userId))
            {
                Complete(completion, InvalidArgument("User ID cannot be null, empty, or whitespace."));
                return;
            }

            string unusedWireAction;
            if (!IdentityActionWireValue.TryGet(identityAction, out unusedWireAction))
            {
                Complete(completion, InvalidArgument("Identity action is not a defined value."));
                return;
            }

            if (identityAction == IdentityAction.Blocked ||
                identityAction == IdentityAction.Unblocked)
            {
                Complete(
                    completion,
                    InvalidArgument(
                        "InitializeAndIdentify does not support blocked or unblocked actions because " +
                        "they require IdentifyOptions.BlockedReason. Use Initialize followed by " +
                        "Identify for these actions."));
                return;
            }

            IDictionary<string, string> catalogSnapshot;
            CFResult catalogFailure;
            if (!TrySnapshotUserCatalog(userCatalog, out catalogSnapshot, out catalogFailure))
            {
                Complete(completion, catalogFailure);
                return;
            }

            Initialize(
                settings.SdkKey,
                settings.CreateOptions(),
                delegate(CFResult initialization)
                {
                    if (initialization == null || !initialization.IsSuccess)
                    {
                        Complete(
                            completion,
                            initialization ?? CFResult.Failed(
                                CFErrorCode.Unknown,
                                "Initialization completed without a result.",
                                null));
                        return;
                    }

                    Identify(
                        userId,
                        identityAction,
                        null,
                        delegate(CFResult identity)
                        {
                            if (identity == null || !identity.IsSuccess)
                            {
                                Complete(
                                    completion,
                                    identity ?? CFResult.Failed(
                                        CFErrorCode.Unknown,
                                        "Identify completed without a result.",
                                        null));
                                return;
                            }

                            if (catalogSnapshot == null)
                            {
                                Complete(completion, identity);
                                return;
                            }

                            LogUserCatalog(
                                userId,
                                new UserCatalogOptions { Metadata = catalogSnapshot },
                                completion);
                        });
                });
        }

        /// <summary>
        /// Records a user identity transition. A successful completion means the event was accepted
        /// by the native SDK; native Core SDKs do not expose server-delivery acknowledgement.
        /// </summary>
        public static void Identify(
            string userId,
            IdentityAction action,
            IdentifyOptions options = null,
            Action<CFResult> completion = null)
        {
            if (IsBlank(userId))
            {
                Complete(completion, InvalidArgument("User ID cannot be null, empty, or whitespace."));
                return;
            }

            string wireAction;
            if (!IdentityActionWireValue.TryGet(action, out wireAction))
            {
                Complete(completion, InvalidArgument("Identity action is not a defined value."));
                return;
            }

            IdentifyOptions resolvedOptions = options ?? new IdentifyOptions();
            if ((action == IdentityAction.Blocked || action == IdentityAction.Unblocked) &&
                IsBlank(resolvedOptions.BlockedReason))
            {
                Complete(
                    completion,
                    InvalidArgument("BlockedReason is required for blocked and unblocked identity actions."));
                return;
            }

            string attributesJson;
            CFResult serializationFailure;
            if (!TrySerializeInput(
                    resolvedOptions.ToJsonObject(),
                    "identify options",
                    out attributesJson,
                    out serializationFailure))
            {
                Complete(completion, serializationFailure);
                return;
            }

            INativeCFBridge readyBridge;
            CFResult readinessFailure;
            if (!TryGetReadyBridge(out readyBridge, out readinessFailure))
            {
                Complete(completion, readinessFailure);
                return;
            }

            InvokeSimple(
                completion,
                "identify",
                delegate(Action<NativeBridgeResult> nativeCompletion)
                {
                    readyBridge.Identify(userId, wireAction, attributesJson, nativeCompletion);
                });
        }

        /// <summary>
        /// Logs or updates the Core user catalog (user dimensions) for an identified user. A
        /// successful completion means the catalog was validated and dispatched to the native SDK;
        /// it does not acknowledge server delivery.
        /// </summary>
        public static void LogUserCatalog(
            string userId,
            UserCatalogOptions options = null,
            Action<CFResult> completion = null)
        {
            if (IsBlank(userId))
            {
                Complete(completion, InvalidArgument("User ID cannot be null, empty, or whitespace."));
                return;
            }

            UserCatalogOptions resolvedOptions = options ?? new UserCatalogOptions();
            string catalogJson;
            CFResult serializationFailure;
            if (!TrySerializeInput(
                    resolvedOptions.ToJsonObject(),
                    "user catalog",
                    out catalogJson,
                    out serializationFailure))
            {
                Complete(completion, serializationFailure);
                return;
            }

            INativeCFBridge readyBridge;
            CFResult readinessFailure;
            if (!TryGetReadyBridge(out readyBridge, out readinessFailure))
            {
                Complete(completion, readinessFailure);
                return;
            }

            InvokeSimple(
                completion,
                "log user catalog",
                delegate(Action<NativeBridgeResult> nativeCompletion)
                {
                    readyBridge.LogUserCatalog(userId, catalogJson, nativeCompletion);
                });
        }

        /// <summary>
        /// Logs or updates a custom Core catalog. Metadata must contain at least one
        /// JSON-compatible value. Catalog names reserved by a built-in SDK catalog are rejected.
        /// </summary>
        public static void LogOtherCatalog(
            string subjectId,
            string catalogName,
            IDictionary<string, object> metadata,
            Action<CFResult> completion = null)
        {
            if (IsBlank(subjectId))
            {
                Complete(completion, InvalidArgument("Subject ID cannot be null, empty, or whitespace."));
                return;
            }

            string normalizedCatalogName = NormalizeCatalogName(catalogName);
            if (normalizedCatalogName.Length == 0)
            {
                Complete(completion, InvalidArgument("Catalog name cannot be null, empty, or whitespace."));
                return;
            }
            if (IsReservedCatalogName(normalizedCatalogName))
            {
                Complete(
                    completion,
                    InvalidArgument(
                        "'" + catalogName + "' normalizes to a name reserved by the native SDK."));
                return;
            }
            if (metadata == null || metadata.Count == 0)
            {
                Complete(completion, InvalidArgument("Other catalog metadata must contain at least one value."));
                return;
            }

            string catalogJson;
            CFResult serializationFailure;
            if (!TrySerializeInput(
                    new Dictionary<string, object>
                    {
                        { "name", catalogName },
                        { "meta", metadata }
                    },
                    "other catalog",
                    out catalogJson,
                    out serializationFailure))
            {
                Complete(completion, serializationFailure);
                return;
            }

            INativeCFBridge readyBridge;
            CFResult readinessFailure;
            if (!TryGetReadyBridge(out readyBridge, out readinessFailure))
            {
                Complete(completion, readinessFailure);
                return;
            }

            InvokeSimple(
                completion,
                "log other catalog",
                delegate(Action<NativeBridgeResult> nativeCompletion)
                {
                    readyBridge.LogOtherCatalog(subjectId, catalogJson, nativeCompletion);
                });
        }

        /// <summary>
        /// Records a custom event. A successful completion means the event was accepted by the
        /// native SDK; it does not mean the event has reached the server.
        /// </summary>
        public static void Track(
            string eventName,
            TrackOptions options = null,
            Action<CFResult> completion = null)
        {
            if (IsBlank(eventName))
            {
                Complete(completion, InvalidArgument("Event name cannot be null, empty, or whitespace."));
                return;
            }

            string normalizedEventName = NormalizeTrackEventName(eventName);
            if (IsReservedTrackEventName(normalizedEventName))
            {
                Complete(
                    completion,
                    InvalidArgument(
                        "'" + eventName + "' normalizes to a name reserved by the native SDK and cannot be used as a custom Track event name."));
                return;
            }

            TrackOptions resolvedOptions = options ?? new TrackOptions();
            string propertiesJson;
            CFResult serializationFailure;
            if (!TrySerializeInput(
                    resolvedOptions.ToJsonObject(),
                    "track options",
                    out propertiesJson,
                    out serializationFailure))
            {
                Complete(completion, serializationFailure);
                return;
            }

            INativeCFBridge readyBridge;
            CFResult readinessFailure;
            if (!TryGetReadyBridge(out readyBridge, out readinessFailure))
            {
                Complete(completion, readinessFailure);
                return;
            }

            InvokeSimple(
                completion,
                "track",
                delegate(Action<NativeBridgeResult> nativeCompletion)
                {
                    readyBridge.Track(normalizedEventName, propertiesJson, nativeCompletion);
                });
        }

        /// <summary>Fetches one-off custom actions that the host renders as in-app components.</summary>
        /// <param name="attributes">
        /// Optional string attributes used to filter matching actions. Pass null or an empty
        /// dictionary to fetch without attribute filters.
        /// </param>
        /// <param name="completion">
        /// Required callback invoked on Unity's main thread with the fetched actions or an error.
        /// </param>
        /// <remarks>
        /// This is equivalent to <see cref="FetchActions"/> with
        /// <see cref="ActionTypes.Custom"/>, <see cref="ActionRenderMethods.InAppComponent"/>, and
        /// <see cref="ActionDeliveryModes.OneOff"/>. Returned actions are not rendered
        /// automatically. The SDK must be initialized before calling this method.
        /// </remarks>
        public static void FetchCustomActions(
            IDictionary<string, string> attributes,
            Action<CFResult<IList<CFAction>>> completion)
        {
            FetchActions(
                ActionTypes.Custom,
                ActionRenderMethods.InAppComponent,
                ActionDeliveryModes.OneOff,
                attributes,
                completion);
        }

        /// <summary>
        /// Fetches actions using the native Core parameter shape without requiring an
        /// <see cref="ActionQuery"/> instance.
        /// </summary>
        /// <param name="invActionType">Use a value from <see cref="ActionTypes"/>.</param>
        /// <param name="actionRenderMethodType">
        /// Use a value from <see cref="ActionRenderMethods"/>.
        /// </param>
        /// <param name="deliveryMode">Use a value from <see cref="ActionDeliveryModes"/>.</param>
        /// <param name="actionAttributes">
        /// Optional string properties used to filter matching actions. Pass null or an empty
        /// dictionary to fetch without attribute filters.
        /// </param>
        /// <param name="completion">
        /// Required callback invoked on Unity's main thread with the fetched actions or an error.
        /// </param>
        public static void FetchActions(
            string invActionType,
            string actionRenderMethodType,
            string deliveryMode,
            IDictionary<string, string> actionAttributes,
            Action<CFResult<IList<CFAction>>> completion)
        {
            FetchActions(
                new ActionQuery(
                    invActionType,
                    actionRenderMethodType,
                    deliveryMode)
                {
                    Attributes = actionAttributes
                },
                completion);
        }

        /// <summary>Fetches matching actions using string-based type, render, and delivery values.</summary>
        public static void FetchActions(
            ActionQuery query,
            Action<CFResult<IList<CFAction>>> completion)
        {
            if (completion == null)
            {
                Debug.LogError("Causal Foundry FetchActions requires a completion callback.");
                return;
            }

            if (query == null)
            {
                Complete(completion, ActionFailure(CFErrorCode.InvalidArgument, "Query cannot be null."));
                return;
            }

            if (IsBlank(query.Type) || IsBlank(query.RenderMethod) || IsBlank(query.DeliveryMode))
            {
                Complete(
                    completion,
                    ActionFailure(
                        CFErrorCode.InvalidArgument,
                        "Action type, render method, and delivery mode are required."));
                return;
            }

            string normalizedType = NormalizeWireValue(query.Type);
            string normalizedRenderMethod = NormalizeWireValue(query.RenderMethod);
            string normalizedDeliveryMode = NormalizeWireValue(query.DeliveryMode);

            string attributesJson;
            string serializationError;
            object attributes = query.Attributes ?? new Dictionary<string, string>();
            if (!CFJson.TrySerialize(attributes, out attributesJson, out serializationError))
            {
                Complete(
                    completion,
                    ActionFailure(
                        CFErrorCode.SerializationFailure,
                        "Could not serialize action attributes: " + serializationError));
                return;
            }

            INativeCFBridge readyBridge;
            CFResult readinessFailure;
            if (!TryGetReadyBridge(out readyBridge, out readinessFailure))
            {
                Complete(completion, ConvertActionFailure(readinessFailure));
                return;
            }

            var gate = new NativeCompletionGate(
                delegate(NativeBridgeResult nativeResult)
                {
                    if (nativeResult == null || !nativeResult.IsSuccess)
                    {
                        Complete(completion, ConvertActionFailure(ConvertNativeResult(nativeResult)));
                        return;
                    }

                    IList<CFAction> actions;
                    string parseError;
                    if (!ActionResponseParser.TryParseActions(
                            nativeResult.PayloadJson,
                            out actions,
                            out parseError))
                    {
                        Complete(
                            completion,
                            ActionFailure(
                                CFErrorCode.InvalidResponse,
                                "Could not decode the native action response: " + parseError));
                        return;
                    }

                    Complete(completion, CFResult<IList<CFAction>>.Succeeded(actions));
                });

            try
            {
                readyBridge.FetchActions(
                    normalizedType,
                    normalizedRenderMethod,
                    normalizedDeliveryMode,
                    attributesJson,
                    gate.Invoke);
            }
            catch (Exception exception)
            {
                gate.Invoke(NativeExceptionResult("fetch actions", exception));
            }
        }

        /// <summary>
        /// Asks the native SDK to display a queued in-app message for a screen. Pass
        /// ActionScreens.Default (or null) when no screen filter is needed.
        /// </summary>
        public static void ShowInAppMessage(
            string screen,
            Action<CFResult> completion = null)
        {
            INativeCFBridge readyBridge;
            CFResult readinessFailure;
            if (!TryGetReadyBridge(out readyBridge, out readinessFailure))
            {
                Complete(completion, readinessFailure);
                return;
            }

            string resolvedScreen = screen == null
                ? ActionScreens.Default
                : NormalizeWireValue(screen);
            InvokeSimple(
                completion,
                "show in-app message",
                delegate(Action<NativeBridgeResult> nativeCompletion)
                {
                    readyBridge.ShowInAppMessage(resolvedScreen, nativeCompletion);
                });
        }

        /// <summary>
        /// Pauses or resumes native event logging after initialization. iOS automatic action
        /// polling is also gated; Android action scheduling has native Core limitations documented
        /// in the package's native-integration guide and is not a network-silence boundary.
        /// </summary>
        public static void SetPaused(
            bool paused,
            Action<CFResult> completion = null)
        {
            INativeCFBridge readyBridge;
            CFResult readinessFailure;
            if (!TryGetReadyBridge(out readyBridge, out readinessFailure))
            {
                Complete(completion, readinessFailure);
                return;
            }

            InvokeSimple(
                completion,
                paused ? "pause the SDK" : "resume the SDK",
                delegate(Action<NativeBridgeResult> nativeCompletion)
                {
                    readyBridge.SetPaused(paused, nativeCompletion);
                });
        }

        /// <summary>
        /// Direct reverse-call entrypoint for native shims that cannot raise the bridge event.
        /// Prefer raising INativeCFBridge.ActionOpenedJson when possible.
        /// </summary>
        internal static void HandleNativeActionOpened(string attributesJson)
        {
            UnityCallbackDispatcher.Run(delegate { DispatchNativeActionOpened(attributesJson); });
        }

        private static void DispatchNativeActionOpened(string attributesJson)
        {
            ActionOpenedEvent openedAction;
            string parseError;
            if (!ActionResponseParser.TryParseOpenedAction(
                    attributesJson,
                    out openedAction,
                    out parseError))
            {
                Debug.LogError("Causal Foundry ignored malformed action-open data: " + parseError);
                return;
            }

            Action<ActionOpenedEvent> handlers;
            lock (Sync)
            {
                handlers = actionOpenedHandlers;
                if (handlers == null)
                {
                    if (PendingOpenedActions.Count == MaximumPendingOpenedActions)
                    {
                        PendingOpenedActions.Dequeue();
                    }

                    PendingOpenedActions.Enqueue(openedAction);
                    return;
                }
            }

            InvokeActionOpenedHandlers(handlers, openedAction);
        }

        private static void AddActionOpenedHandler(Action<ActionOpenedEvent> handler)
        {
            ActionOpenedEvent[] pending;
            Action<ActionOpenedEvent> handlers;
            lock (Sync)
            {
                actionOpenedHandlers += handler;
                handlers = actionOpenedHandlers;
                pending = PendingOpenedActions.ToArray();
                PendingOpenedActions.Clear();
            }

            for (int i = 0; i < pending.Length; i++)
            {
                InvokeActionOpenedHandlers(handlers, pending[i]);
            }
        }

        private static void InvokeActionOpenedHandlers(
            Action<ActionOpenedEvent> handlers,
            ActionOpenedEvent openedAction)
        {
            Delegate[] invocationList = handlers.GetInvocationList();
            for (int i = 0; i < invocationList.Length; i++)
            {
                try
                {
                    ((Action<ActionOpenedEvent>)invocationList[i])(openedAction);
                }
                catch (Exception exception)
                {
                    Debug.LogException(exception);
                }
            }
        }

        internal static void SetBridgeForTesting(INativeCFBridge replacement)
        {
            ReplaceBridge(replacement, true);
        }

        private static void ReplaceBridge(INativeCFBridge replacement, bool resetState)
        {
            if (replacement == null)
            {
                replacement = new NoOpCFBridge();
            }

            INativeCFBridge previous;
            lock (Sync)
            {
                previous = bridge;
                bridge = replacement;
                unchecked
                {
                    bridgeGeneration++;
                }
                if (resetState)
                {
                    initialized = false;
                    initializing = false;
                    activeSdkKey = null;
                    activeOptionsJson = null;
                    InitializationCallbacks.Clear();
                    actionOpenedHandlers = null;
                    PendingOpenedActions.Clear();
                }
            }

            if (previous != null)
            {
                try
                {
                    previous.ActionOpenedJson -= HandleNativeActionOpened;
                }
                catch (Exception exception)
                {
                    Debug.LogException(exception);
                }
            }

            try
            {
                replacement.ActionOpenedJson += HandleNativeActionOpened;
            }
            catch (Exception exception)
            {
                Debug.LogException(exception);
            }
        }

        private static void FinishInitialization(
            NativeBridgeResult nativeResult,
            int initializationBridgeGeneration)
        {
            // Both native bridges report success when an early bootstrap already uses the exact
            // requested configuration. An already_initialized failure therefore means there is a
            // real key/options conflict and must never be promoted to managed success.
            CFResult result = ConvertNativeResult(nativeResult);

            Action<CFResult>[] callbacks;
            lock (Sync)
            {
                // A bridge can still complete after a domain-reload-free Play Mode reset. Never
                // let that stale callback initialize the replacement bridge or consume its state.
                if (initializationBridgeGeneration != bridgeGeneration)
                {
                    return;
                }

                initialized = result.IsSuccess;
                initializing = false;
                if (!result.IsSuccess)
                {
                    activeSdkKey = null;
                    activeOptionsJson = null;
                }

                callbacks = InitializationCallbacks.ToArray();
                InitializationCallbacks.Clear();
            }

            for (int i = 0; i < callbacks.Length; i++)
            {
                Complete(callbacks[i], result);
            }
        }

        private static bool TryGetReadyBridge(
            out INativeCFBridge readyBridge,
            out CFResult failure)
        {
            bool isInitialized;
            bool isInitializing;
            lock (Sync)
            {
                readyBridge = bridge;
                isInitialized = initialized;
                isInitializing = initializing;
            }

            try
            {
                if (readyBridge == null || !readyBridge.IsSupported)
                {
                    failure = CFResult.Failed(
                        CFErrorCode.UnsupportedPlatform,
                        "The Causal Foundry native SDK is available only in Android and iOS player builds.",
                        "unsupported_platform");
                    return false;
                }
            }
            catch (Exception exception)
            {
                failure = ConvertNativeResult(NativeExceptionResult("check platform support", exception));
                return false;
            }

            if (!isInitialized)
            {
                failure = isInitializing
                    ? CFResult.Failed(
                        CFErrorCode.InitializationInProgress,
                        "Causal Foundry initialization is still in progress.",
                        "initialization_in_progress")
                    : CFResult.Failed(
                        CFErrorCode.NotInitialized,
                        "Initialize the Causal Foundry SDK before calling this method.",
                        "not_initialized");
                return false;
            }

            failure = null;
            return true;
        }

        private static void InvokeSimple(
            Action<CFResult> completion,
            string operationName,
            NativeOperation operation)
        {
            var gate = new NativeCompletionGate(
                delegate(NativeBridgeResult result)
                {
                    Complete(completion, ConvertNativeResult(result));
                });

            try
            {
                operation(gate.Invoke);
            }
            catch (Exception exception)
            {
                gate.Invoke(NativeExceptionResult(operationName, exception));
            }
        }

        private static bool TrySerializeInput(
            object value,
            string label,
            out string json,
            out CFResult failure)
        {
            string error;
            if (CFJson.TrySerialize(value, out json, out error))
            {
                failure = null;
                return true;
            }

            failure = CFResult.Failed(
                CFErrorCode.SerializationFailure,
                "Could not serialize " + label + ": " + error,
                null);
            return false;
        }

        internal static IDictionary<string, object> CreateEventMetadata(
            IDictionary<string, object> metadata)
        {
            var result = metadata == null
                ? new Dictionary<string, object>()
                : new Dictionary<string, object>(metadata);
            result["unity_version"] = PackageVersion;
            return result;
        }

        private static bool TrySnapshotUserCatalog(
            IDictionary<string, string> userCatalog,
            out IDictionary<string, string> snapshot,
            out CFResult failure)
        {
            snapshot = null;
            failure = null;
            if (userCatalog == null)
            {
                return true;
            }

            try
            {
                if (userCatalog.Count > 0)
                {
                    snapshot = new Dictionary<string, string>(userCatalog);
                }
                return true;
            }
            catch (Exception exception)
            {
                failure = InvalidArgument("Could not read the user catalog: " + exception.Message);
                return false;
            }
        }

        private static CFResult ConvertNativeResult(NativeBridgeResult nativeResult)
        {
            if (nativeResult == null)
            {
                return CFResult.Failed(
                    CFErrorCode.NativeFailure,
                    "The native SDK returned no result.",
                    "null_native_result");
            }

            if (nativeResult.IsSuccess)
            {
                return CFResult.Succeeded();
            }

            string message = string.IsNullOrEmpty(nativeResult.ErrorMessage)
                ? "The native SDK operation failed."
                : nativeResult.ErrorMessage;
            return CFResult.Failed(
                MapErrorCode(nativeResult.ErrorCode),
                message,
                nativeResult.ErrorCode);
        }

        private static CFResult<NotificationPermissionStatus>
            ConvertNotificationPermissionResult(NativeBridgeResult nativeResult)
        {
            if (nativeResult == null || !nativeResult.IsSuccess)
            {
                CFResult failure = ConvertNativeResult(nativeResult);
                return CFResult<NotificationPermissionStatus>.Failed(
                    failure.Error.Code,
                    failure.Error.Message,
                    failure.Error.NativeCode);
            }

            object parsed;
            string parseError;
            if (!CFJson.TryDeserialize(nativeResult.PayloadJson, out parsed, out parseError))
            {
                return NotificationPermissionFailure(
                    "Could not decode the native notification permission response: " + parseError);
            }

            IDictionary<string, object> response = parsed as IDictionary<string, object>;
            object statusValue;
            string status = response != null && response.TryGetValue("status", out statusValue)
                ? statusValue as string
                : null;

            switch ((status ?? string.Empty).Trim().ToLowerInvariant())
            {
                case "authorized":
                    return CFResult<NotificationPermissionStatus>.Succeeded(
                        NotificationPermissionStatus.Authorized);
                case "denied":
                    return CFResult<NotificationPermissionStatus>.Succeeded(
                        NotificationPermissionStatus.Denied);
                case "not_required":
                    return CFResult<NotificationPermissionStatus>.Succeeded(
                        NotificationPermissionStatus.NotRequired);
                default:
                    return NotificationPermissionFailure(
                        "The native notification permission response contained an unknown status.");
            }
        }

        private static CFResult<NotificationPermissionStatus>
            NotificationPermissionFailure(string message)
        {
            return CFResult<NotificationPermissionStatus>.Failed(
                CFErrorCode.InvalidResponse,
                message,
                "invalid_notification_permission_response");
        }

        private static CFErrorCode MapErrorCode(string nativeCode)
        {
            if (string.IsNullOrEmpty(nativeCode))
            {
                return CFErrorCode.NativeFailure;
            }

            switch (nativeCode.Trim().ToLowerInvariant())
            {
                case "invalid_argument":
                case "invalid_action_request":
                case "invalid_blocked_reason":
                case "invalid_event_name":
                case "invalid_identify":
                case "invalid_other_catalog":
                case "invalid_user_catalog":
                case "invalid_options":
                case "invalid_screen":
                case "invalid_sdk_key":
                case "invalid_track":
                case "invalid_user_id":
                case "reserved_event_name":
                    return CFErrorCode.InvalidArgument;
                case "not_initialized":
                    return CFErrorCode.NotInitialized;
                case "initialization_in_progress":
                    return CFErrorCode.InitializationInProgress;
                case "already_initialized":
                case "configuration_conflict":
                    return CFErrorCode.AlreadyInitialized;
                case "unsupported_platform":
                    return CFErrorCode.UnsupportedPlatform;
                case "serialization_error":
                case "serialization_failure":
                    return CFErrorCode.SerializationFailure;
                case "invalid_response":
                case "malformed_response":
                    return CFErrorCode.InvalidResponse;
                case "timeout":
                    return CFErrorCode.Timeout;
                case "native_error":
                case "native_exception":
                case "native_failure":
                case "jni_exception":
                case "interop_exception":
                case "bridge_unavailable":
                case "startup_unavailable":
                case "initialization_failed":
                case "native_identify_failed":
                case "native_other_catalog_failed":
                case "native_user_catalog_failed":
                case "native_track_failed":
                case "native_fetch_actions_failed":
                case "native_show_in_app_failed":
                case "native_pause_failed":
                case "notification_permission_error":
                    return CFErrorCode.NativeFailure;
                default:
                    return CFErrorCode.Unknown;
            }
        }

        private static NativeBridgeResult NativeExceptionResult(string operation, Exception exception)
        {
            string message = "The native bridge threw while attempting to " + operation + ".";
            if (exception != null && !string.IsNullOrEmpty(exception.Message))
            {
                message += " " + exception.Message;
            }

            return NativeBridgeResult.Failure("native_exception", message);
        }

        private static CFResult InvalidArgument(string message)
        {
            return CFResult.Failed(
                CFErrorCode.InvalidArgument,
                message,
                null);
        }

        private static CFResult<IList<CFAction>> ActionFailure(
            CFErrorCode code,
            string message)
        {
            return CFResult<IList<CFAction>>.Failed(code, message, null);
        }

        private static CFResult<IList<CFAction>> ConvertActionFailure(
            CFResult source)
        {
            if (source == null || source.Error == null)
            {
                return ActionFailure(CFErrorCode.Unknown, "The action operation failed.");
            }

            return CFResult<IList<CFAction>>.Failed(
                source.Error.Code,
                source.Error.Message,
                source.Error.NativeCode);
        }

        private static bool IsBlank(string value)
        {
            return string.IsNullOrEmpty(value) || value.Trim().Length == 0;
        }

        internal static string NormalizeSdkKey(string value)
        {
            if (value == null)
            {
                return null;
            }

            // Dashboard keys are raw values, but accepting an accidentally pasted HTTP
            // authorization prefix keeps Android and iOS behavior deterministic.
            string normalized = value.Trim();
            const string bearerPrefix = "Bearer ";
            if (normalized.StartsWith(bearerPrefix, StringComparison.OrdinalIgnoreCase))
            {
                normalized = normalized.Substring(bearerPrefix.Length).Trim();
            }
            return normalized;
        }

        private static string NormalizeWireValue(string value)
        {
            return value.Trim().ToLowerInvariant();
        }

        private static bool IsReservedTrackEventName(string value)
        {
            for (int i = 0; i < ReservedTrackEventNames.Length; i++)
            {
                if (string.Equals(value, ReservedTrackEventNames[i], StringComparison.Ordinal))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool IsReservedCatalogName(string value)
        {
            for (int i = 0; i < ReservedCatalogNames.Length; i++)
            {
                if (string.Equals(value, ReservedCatalogNames[i], StringComparison.Ordinal))
                {
                    return true;
                }
            }

            return false;
        }

        private static string NormalizeCatalogName(string value)
        {
            if (value == null)
            {
                return string.Empty;
            }

            string normalized = Regex.Replace(
                value,
                @"^[\s\p{Z}\uFEFF]+|[\s\p{Z}\uFEFF]+$",
                string.Empty);
            return Regex.Replace(normalized, @"[\s\p{Z}\uFEFF]+", "_")
                .ToLowerInvariant();
        }

        private static string NormalizeTrackEventName(string value)
        {
            return value.Trim().Replace(' ', '_').ToLowerInvariant();
        }

        private static void Complete<T>(Action<T> completion, T result)
        {
            if (completion == null)
            {
                return;
            }

            UnityCallbackDispatcher.Run(
                delegate
                {
                    try
                    {
                        completion(result);
                    }
                    catch (Exception exception)
                    {
                        Debug.LogException(exception);
                    }
                });
        }

        private delegate void NativeOperation(Action<NativeBridgeResult> completion);

        private sealed class NativeCompletionGate
        {
            private readonly Action<NativeBridgeResult> completion;
            private int completed;

            internal NativeCompletionGate(Action<NativeBridgeResult> completion)
            {
                this.completion = completion;
            }

            internal void Invoke(NativeBridgeResult result)
            {
                if (Interlocked.Exchange(ref completed, 1) != 0)
                {
                    return;
                }

                completion(result);
            }
        }
    }
}
