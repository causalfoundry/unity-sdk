using System;
using System.Collections.Generic;
using CausalFoundry.Unity.Internal;
using NUnit.Framework;

namespace CausalFoundry.Unity.Editor.Tests
{
    public sealed class CFSDKTests
    {
        private FakeBridge bridge;
        private CFSettings settings;

        [SetUp]
        public void SetUp()
        {
            bridge = new FakeBridge();
            CFSDK.SetBridgeForTesting(bridge);
            settings = UnityEngine.ScriptableObject.CreateInstance<CFSettings>();
            settings.SdkKey = "key";
        }

        [TearDown]
        public void TearDown()
        {
            CFSDK.SetBridgeForTesting(new NoOpCFBridge());
            UnityEngine.Object.DestroyImmediate(settings);
        }

        [Test]
        public void Initialize_RejectsBlankKeyWithoutCallingNativeCode()
        {
            CFResult result = null;

            Assert.DoesNotThrow(delegate { CFSDK.Initialize("  ", null, value => result = value); });

            Assert.That(result, Is.Not.Null);
            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidArgument));
            Assert.That(bridge.InitializeCalls, Is.EqualTo(0));
        }

        [TestCase("{\"status\":\"authorized\"}", NotificationPermissionStatus.Authorized)]
        [TestCase("{\"status\":\"denied\"}", NotificationPermissionStatus.Denied)]
        [TestCase("{\"status\":\"not_required\"}", NotificationPermissionStatus.NotRequired)]
        public void RequestNotificationPermission_DoesNotRequireInitializationAndMapsStatus(
            string payload,
            NotificationPermissionStatus expectedStatus)
        {
            bridge.NotificationPermissionResult = NativeBridgeResult.Success(payload);
            CFResult<NotificationPermissionStatus> result = null;

            CFSDK.RequestNotificationPermission(value => result = value);

            Assert.That(result, Is.Not.Null);
            Assert.That(result.IsSuccess, Is.True);
            Assert.That(result.Value, Is.EqualTo(expectedStatus));
            Assert.That(bridge.NotificationPermissionCalls, Is.EqualTo(1));
            Assert.That(bridge.InitializeCalls, Is.EqualTo(0));
        }

        [Test]
        public void RequestNotificationPermission_RejectsMalformedNativeResponse()
        {
            bridge.NotificationPermissionResult = NativeBridgeResult.Success("{\"status\":\"maybe\"}");
            CFResult<NotificationPermissionStatus> result = null;

            CFSDK.RequestNotificationPermission(value => result = value);

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidResponse));
            Assert.That(
                result.Error.NativeCode,
                Is.EqualTo("invalid_notification_permission_response"));
        }

        [Test]
        public void RequestNotificationPermission_ConvertsPlatformExceptionToFailure()
        {
            bridge.ThrowOnNotificationPermission = true;
            CFResult<NotificationPermissionStatus> result = null;

            Assert.DoesNotThrow(
                delegate
                {
                    CFSDK.RequestNotificationPermission(value => result = value);
                });

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NativeFailure));
        }

        [Test]
        public void RequestNotificationPermission_MapsNativeRequestFailure()
        {
            bridge.NotificationPermissionResult = NativeBridgeResult.Failure(
                "notification_permission_error",
                "permission request failed");
            CFResult<NotificationPermissionStatus> result = null;

            CFSDK.RequestNotificationPermission(value => result = value);

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NativeFailure));
            Assert.That(result.Error.NativeCode, Is.EqualTo("notification_permission_error"));
        }

        [Test]
        public void Initialize_UsesPortableDefaultsAndIsIdempotent()
        {
            int callbackCount = 0;
            CFResult first = null;
            CFResult second = null;

            CFSDK.Initialize("key", null, value =>
            {
                callbackCount++;
                first = value;
            });
            CFSDK.Initialize("key", null, value =>
            {
                callbackCount++;
                second = value;
            });

            Assert.That(first.IsSuccess, Is.True);
            Assert.That(second.IsSuccess, Is.True);
            Assert.That(CFSDK.IsInitialized, Is.True);
            Assert.That(bridge.InitializeCalls, Is.EqualTo(1));
            Assert.That(callbackCount, Is.EqualTo(2));
            Assert.That(bridge.OptionsJson, Does.Contain("\"allow_anonymous_users\":true"));
            Assert.That(bridge.OptionsJson, Does.Contain("\"disable_auto_page_tracking\":true"));
        }

        [Test]
        public void Initialize_TrimsKeyForNativeCallAndIdempotency()
        {
            CFResult first = null;
            CFResult second = null;

            CFSDK.Initialize("  key  ", null, value => first = value);
            CFSDK.Initialize("key", null, value => second = value);

            Assert.That(first.IsSuccess, Is.True);
            Assert.That(second.IsSuccess, Is.True);
            Assert.That(bridge.SdkKey, Is.EqualTo("key"));
            Assert.That(bridge.InitializeCalls, Is.EqualTo(1));
        }

        [Test]
        public void Initialize_StripsBearerPrefixForCrossPlatformConsistency()
        {
            CFResult first = null;
            CFResult second = null;

            CFSDK.Initialize("  bEaReR key  ", null, value => first = value);
            CFSDK.Initialize("key", null, value => second = value);

            Assert.That(first.IsSuccess, Is.True);
            Assert.That(second.IsSuccess, Is.True);
            Assert.That(bridge.SdkKey, Is.EqualTo("key"));
            Assert.That(bridge.InitializeCalls, Is.EqualTo(1));
        }

        [Test]
        public void Settings_NormalizesSdkKeyUsedByEarlyBootstrap()
        {
            CFSettings settings =
                UnityEngine.ScriptableObject.CreateInstance<CFSettings>();
            try
            {
                settings.SdkKey = "  Bearer key  ";

                Assert.That(settings.SdkKey, Is.EqualTo("key"));
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(settings);
            }
        }

        [Test]
        public void Initialize_PreservesNativeEarlyBootstrapConflict()
        {
            bridge.InitializeResult = NativeBridgeResult.Failure(
                "already_initialized",
                "The native SDK was already initialized with different settings.");
            CFResult result = null;

            CFSDK.Initialize("different-key", null, value => result = value);

            Assert.That(result, Is.Not.Null);
            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.AlreadyInitialized));
            Assert.That(CFSDK.IsInitialized, Is.False);
        }

        [Test]
        public void Initialize_RejectsDifferentOptionsAfterSuccess()
        {
            CFResult first = null;
            CFResult second = null;

            CFSDK.Initialize("key", null, value => first = value);
            CFSDK.Initialize(
                "key",
                new CFOptions { AllowAnonymousUsers = false },
                value => second = value);

            Assert.That(first.IsSuccess, Is.True);
            Assert.That(second.IsSuccess, Is.False);
            Assert.That(second.Error.Code, Is.EqualTo(CFErrorCode.AlreadyInitialized));
            Assert.That(bridge.InitializeCalls, Is.EqualTo(1));
        }

        [Test]
        public void Initialize_DoesNotCoalesceDifferentOptionsWhileInFlight()
        {
            bridge.HoldInitialization = true;
            CFResult first = null;
            CFResult second = null;

            CFSDK.Initialize("key", null, value => first = value);
            CFSDK.Initialize(
                "key",
                new CFOptions { PauseSdk = true },
                value => second = value);

            Assert.That(first, Is.Null);
            Assert.That(second.IsSuccess, Is.False);
            Assert.That(second.Error.Code, Is.EqualTo(CFErrorCode.InitializationInProgress));
            Assert.That(bridge.InitializeCalls, Is.EqualTo(1));

            bridge.CompleteHeldInitialization();
            Assert.That(first.IsSuccess, Is.True);
        }

        [Test]
        public void CallsDuringInitialization_ReturnInitializationInProgress()
        {
            bridge.HoldInitialization = true;
            CFSDK.Initialize("key");
            CFResult result = null;

            CFSDK.Track("event", null, value => result = value);

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InitializationInProgress));
            bridge.CompleteHeldInitialization();
        }

        [Test]
        public void ReplacingBridge_IgnoresLateInitializationFromPreviousSession()
        {
            bridge.HoldInitialization = true;
            CFResult staleResult = null;
            CFSDK.Initialize("stale-key", null, value => staleResult = value);

            FakeBridge replacement = new FakeBridge();
            CFSDK.SetBridgeForTesting(replacement);
            bridge.CompleteHeldInitialization();

            Assert.That(staleResult, Is.Null);
            Assert.That(CFSDK.IsInitialized, Is.False);

            CFResult currentResult = null;
            CFSDK.Initialize("current-key", null, value => currentResult = value);
            Assert.That(currentResult.IsSuccess, Is.True);
            Assert.That(replacement.SdkKey, Is.EqualTo("current-key"));
        }

        [Test]
        public void InitializeAndIdentify_InitializesIdentifiesAndLogsCatalogInOrder()
        {
            CFResult result = null;

            CFSDK.InitializeAndIdentify(
                settings,
                "player-42",
                IdentityAction.Login,
                new Dictionary<string, string>
                {
                    { "role", "game_user" },
                    { "tier", "gold" }
                },
                value => result = value);

            Assert.That(result, Is.Not.Null);
            Assert.That(result.IsSuccess, Is.True);
            CollectionAssert.AreEqual(
                new[] { "initialize", "identify", "user_catalog" },
                bridge.Calls);
            Assert.That(bridge.SdkKey, Is.EqualTo("key"));
            Assert.That(bridge.IdentityUserId, Is.EqualTo("player-42"));
            Assert.That(bridge.IdentityAction, Is.EqualTo("login"));
            Assert.That(
                bridge.IdentityAttributesJson,
                Is.EqualTo(
                    "{\"meta\":{\"unity_version\":\"" +
                    CFSDK.PackageVersion +
                    "\"}}"));
            Assert.That(bridge.CatalogUserId, Is.EqualTo("player-42"));
            Assert.That(
                bridge.CatalogJson,
                Is.EqualTo("{\"meta\":{\"role\":\"game_user\",\"tier\":\"gold\"}}"));
        }

        [TestCase(true)]
        [TestCase(false)]
        public void InitializeAndIdentify_SkipsNullOrEmptyCatalog(bool useNullCatalog)
        {
            IDictionary<string, string> catalog = useNullCatalog
                ? null
                : new Dictionary<string, string>();
            CFResult result = null;

            CFSDK.InitializeAndIdentify(
                settings,
                "player-42",
                IdentityAction.Login,
                catalog,
                value => result = value);

            Assert.That(result, Is.Not.Null);
            Assert.That(result.IsSuccess, Is.True);
            CollectionAssert.AreEqual(new[] { "initialize", "identify" }, bridge.Calls);
            Assert.That(bridge.UserCatalogCalls, Is.EqualTo(0));
        }

        [Test]
        public void InitializeAndIdentify_InitializationFailureStopsIdentityAndCatalog()
        {
            bridge.InitializeResult = NativeBridgeResult.Failure(
                "initialization_failed",
                "initialization failed");
            int callbackCount = 0;
            CFResult result = null;

            CFSDK.InitializeAndIdentify(
                settings,
                "player-42",
                IdentityAction.Login,
                new Dictionary<string, string> { { "role", "game_user" } },
                value =>
                {
                    callbackCount++;
                    result = value;
                });

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NativeFailure));
            Assert.That(callbackCount, Is.EqualTo(1));
            CollectionAssert.AreEqual(new[] { "initialize" }, bridge.Calls);
        }

        [Test]
        public void InitializeAndIdentify_IdentityFailureStopsCatalog()
        {
            bridge.IdentifyResult = NativeBridgeResult.Failure(
                "native_identify_failed",
                "identify failed");
            int callbackCount = 0;
            CFResult result = null;

            CFSDK.InitializeAndIdentify(
                settings,
                "player-42",
                IdentityAction.Login,
                new Dictionary<string, string> { { "role", "game_user" } },
                value =>
                {
                    callbackCount++;
                    result = value;
                });

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NativeFailure));
            Assert.That(callbackCount, Is.EqualTo(1));
            CollectionAssert.AreEqual(new[] { "initialize", "identify" }, bridge.Calls);
            Assert.That(bridge.UserCatalogCalls, Is.EqualTo(0));
        }

        [Test]
        public void InitializeAndIdentify_CatalogFailureCompletesWithFailure()
        {
            bridge.UserCatalogResult = NativeBridgeResult.Failure(
                "native_user_catalog_failed",
                "catalog failed");
            int callbackCount = 0;
            CFResult result = null;

            CFSDK.InitializeAndIdentify(
                settings,
                "player-42",
                IdentityAction.Login,
                new Dictionary<string, string> { { "role", "game_user" } },
                value =>
                {
                    callbackCount++;
                    result = value;
                });

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NativeFailure));
            Assert.That(callbackCount, Is.EqualTo(1));
            CollectionAssert.AreEqual(
                new[] { "initialize", "identify", "user_catalog" },
                bridge.Calls);
        }

        [Test]
        public void InitializeAndIdentify_NativeDuplicateCompletionsCompletePipelineOnce()
        {
            bridge.CompleteIdentifyTwice = true;
            bridge.CompleteUserCatalogTwice = true;
            int callbackCount = 0;

            CFSDK.InitializeAndIdentify(
                settings,
                "player-42",
                IdentityAction.Login,
                new Dictionary<string, string> { { "role", "game_user" } },
                value => callbackCount++);

            Assert.That(callbackCount, Is.EqualTo(1));
            Assert.That(bridge.IdentifyCalls, Is.EqualTo(1));
            Assert.That(bridge.UserCatalogCalls, Is.EqualTo(1));
            CollectionAssert.AreEqual(
                new[] { "initialize", "identify", "user_catalog" },
                bridge.Calls);
        }

        [Test]
        public void InitializeAndIdentify_BlankUserIdFailsBeforeInitialization()
        {
            CFResult result = null;

            CFSDK.InitializeAndIdentify(
                settings,
                "  ",
                IdentityAction.Login,
                new Dictionary<string, string> { { "role", "game_user" } },
                value => result = value);

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidArgument));
            Assert.That(bridge.InitializeCalls, Is.EqualTo(0));
            Assert.That(bridge.Calls, Is.Empty);
            Assert.That(bridge.IdentifyCalls, Is.EqualTo(0));
            Assert.That(bridge.UserCatalogCalls, Is.EqualTo(0));
        }

        [Test]
        public void InitializeAndIdentify_UndefinedActionFailsBeforeInitialization()
        {
            CFResult result = null;

            CFSDK.InitializeAndIdentify(
                settings,
                "player-42",
                (IdentityAction)99,
                new Dictionary<string, string> { { "role", "game_user" } },
                value => result = value);

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidArgument));
            Assert.That(bridge.InitializeCalls, Is.EqualTo(0));
            Assert.That(bridge.Calls, Is.Empty);
            Assert.That(bridge.IdentifyCalls, Is.EqualTo(0));
            Assert.That(bridge.UserCatalogCalls, Is.EqualTo(0));
        }

        [TestCase(IdentityAction.Blocked)]
        [TestCase(IdentityAction.Unblocked)]
        public void InitializeAndIdentify_ActionRequiringOptionsFailsBeforeInitialization(
            IdentityAction identityAction)
        {
            CFResult result = null;

            CFSDK.InitializeAndIdentify(
                settings,
                "player-42",
                identityAction,
                new Dictionary<string, string> { { "role", "game_user" } },
                value => result = value);

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidArgument));
            Assert.That(bridge.InitializeCalls, Is.EqualTo(0));
            Assert.That(bridge.Calls, Is.Empty);
            Assert.That(bridge.IdentifyCalls, Is.EqualTo(0));
            Assert.That(bridge.UserCatalogCalls, Is.EqualTo(0));
        }

        [Test]
        public void Identify_ValidatesEnumBeforeCallingNativeCode()
        {
            Initialize();
            CFResult result = null;

            CFSDK.Identify("user", (IdentityAction)99, null, value => result = value);

            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidArgument));
            Assert.That(bridge.IdentifyCalls, Is.EqualTo(0));
        }

        [Test]
        public void Identify_OverridesUnityVersionWithoutMutatingCallerMetadata()
        {
            Initialize();
            CFResult result = null;
            var metadata = new Dictionary<string, object>
            {
                { "role", "game_user" },
                { "unity_version", "caller-version" }
            };

            CFSDK.Identify(
                "player-42",
                IdentityAction.Login,
                new IdentifyOptions { Metadata = metadata },
                value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(
                bridge.IdentityAttributesJson,
                Is.EqualTo(
                    "{\"meta\":{\"role\":\"game_user\",\"unity_version\":\"" +
                    CFSDK.PackageVersion +
                    "\"}}"));
            Assert.That(metadata.Count, Is.EqualTo(2));
            Assert.That(metadata["unity_version"], Is.EqualTo("caller-version"));
        }

        [Test]
        public void LogUserCatalog_UsesPortableCountryAndMetadataWireContract()
        {
            Initialize();
            CFResult result = null;

            CFSDK.LogUserCatalog(
                "player-42",
                new UserCatalogOptions
                {
                    Country = "Spain",
                    Metadata = new Dictionary<string, string>
                    {
                        { "role", "game_user" }
                    }
                },
                value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(bridge.UserCatalogCalls, Is.EqualTo(1));
            Assert.That(bridge.CatalogUserId, Is.EqualTo("player-42"));
            Assert.That(
                bridge.CatalogJson,
                Is.EqualTo("{\"country\":\"Spain\",\"meta\":{\"role\":\"game_user\"}}"));
        }

        [Test]
        public void LogUserCatalog_RejectsBlankUserIdWithoutCallingNativeCode()
        {
            Initialize();
            CFResult result = null;

            CFSDK.LogUserCatalog("  ", null, value => result = value);

            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidArgument));
            Assert.That(bridge.UserCatalogCalls, Is.EqualTo(0));
        }

        [Test]
        public void LogUserCatalog_ConvertsPlatformExceptionToFailure()
        {
            Initialize();
            bridge.ThrowOnUserCatalog = true;
            CFResult result = null;

            Assert.DoesNotThrow(delegate
            {
                CFSDK.LogUserCatalog(
                    "player-42",
                    new UserCatalogOptions { Country = "Spain" },
                    value => result = value);
            });

            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NativeFailure));
        }

        [Test]
        public void LogUserCatalog_MapsNativeCatalogFailure()
        {
            Initialize();
            bridge.UserCatalogResult = NativeBridgeResult.Failure(
                "native_user_catalog_failed",
                "catalog failed");
            CFResult result = null;

            CFSDK.LogUserCatalog(
                "player-42",
                new UserCatalogOptions { Country = "Spain" },
                value => result = value);

            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NativeFailure));
        }

        [Test]
        public void LogOtherCatalog_UsesNativeWireContract()
        {
            Initialize();
            CFResult result = null;

            CFSDK.LogOtherCatalog(
                "household-42",
                "Household Details",
                new Dictionary<string, object>
                {
                    { "members", 4L },
                    { "is_approved", true }
                },
                value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(bridge.OtherCatalogCalls, Is.EqualTo(1));
            Assert.That(bridge.OtherCatalogSubjectId, Is.EqualTo("household-42"));
            Assert.That(
                bridge.OtherCatalogJson,
                Is.EqualTo("{\"meta\":{\"is_approved\":true,\"members\":4},\"name\":\"Household Details\"}"));
        }

        [TestCase(null, "household")]
        [TestCase("  ", "household")]
        [TestCase("household-42", null)]
        [TestCase("household-42", " \u00a0 \ufeff ")]
        [TestCase("household-42", " \u00a0 Site \ufeff ")]
        public void LogOtherCatalog_RejectsInvalidIdentityOrName(
            string subjectId,
            string catalogName)
        {
            Initialize();
            CFResult result = null;

            CFSDK.LogOtherCatalog(
                subjectId,
                catalogName,
                new Dictionary<string, object> { { "active", true } },
                value => result = value);

            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidArgument));
            Assert.That(bridge.OtherCatalogCalls, Is.EqualTo(0));
        }

        [TestCase(true)]
        [TestCase(false)]
        public void LogOtherCatalog_RejectsMissingMetadata(bool useNull)
        {
            Initialize();
            CFResult result = null;

            CFSDK.LogOtherCatalog(
                "household-42",
                "household",
                useNull ? null : new Dictionary<string, object>(),
                value => result = value);

            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidArgument));
            Assert.That(bridge.OtherCatalogCalls, Is.EqualTo(0));
        }

        [Test]
        public void Track_UsesExplicitPropertyAndMetadataWireContract()
        {
            Initialize();
            CFResult result = null;
            var metadata = new Dictionary<string, object>
            {
                { "score", 42L },
                { "perfect", true }
            };
            var options = new TrackOptions
            {
                Property = "complete",
                Metadata = metadata,
                UpdateImmediately = true,
                TimestampMilliseconds = 1234L
            };

            CFSDK.Track(" Level Finished ", options, value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(bridge.EventName, Is.EqualTo("level_finished"));
            Assert.That(
                bridge.PropertiesJson,
                Is.EqualTo(
                    "{\"immediate\":true,\"meta\":{\"perfect\":true,\"score\":42,\"unity_version\":\"" +
                    CFSDK.PackageVersion +
                    "\"},\"property\":\"complete\",\"timestamp_ms\":1234}"));
            Assert.That(metadata.Count, Is.EqualTo(2));
            Assert.That(metadata.ContainsKey("unity_version"), Is.False);
        }

        [Test]
        public void Track_NullOptionsIncludesUnityVersionMetadata()
        {
            Initialize();
            CFResult result = null;

            CFSDK.Track("event", null, value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(
                bridge.PropertiesJson,
                Is.EqualTo(
                    "{\"meta\":{\"unity_version\":\"" +
                    CFSDK.PackageVersion +
                    "\"}}"));
        }

        [TestCase(" APP ")]
        [TestCase(CFEventNames.Page)]
        [TestCase(CFEventNames.Identify)]
        [TestCase(CFEventNames.Media)]
        [TestCase(CFEventNames.Search)]
        [TestCase(CFEventNames.Rate)]
        [TestCase(CFEventNames.ModuleSelection)]
        [TestCase(CFEventNames.Track)]
        [TestCase(CFEventNames.ActionResponse)]
        [TestCase(CFEventNames.NudgeResponse)]
        [TestCase(CFEventNames.Item)]
        [TestCase(CFEventNames.Delivery)]
        [TestCase(CFEventNames.Checkout)]
        [TestCase(CFEventNames.Cart)]
        [TestCase(CFEventNames.CancelCheckout)]
        [TestCase(CFEventNames.ItemReport)]
        [TestCase(CFEventNames.ItemRequest)]
        [TestCase(CFEventNames.Module)]
        [TestCase(CFEventNames.Exam)]
        [TestCase(CFEventNames.Question)]
        [TestCase(CFEventNames.Level)]
        [TestCase(CFEventNames.Milestone)]
        [TestCase(CFEventNames.Promo)]
        [TestCase(CFEventNames.Survey)]
        [TestCase(CFEventNames.Reward)]
        [TestCase(CFEventNames.Payment)]
        [TestCase(CFEventNames.Patient)]
        [TestCase(CFEventNames.Encounter)]
        [TestCase(CFEventNames.Appointment)]
        [TestCase(CFEventNames.Diagnosis)]
        [TestCase("module selection")]
        public void Track_RejectsReservedNativeEventName(string eventName)
        {
            Initialize();
            CFResult result = null;

            CFSDK.Track(eventName, null, value => result = value);

            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidArgument));
            Assert.That(bridge.EventName, Is.Null);
        }

        [Test]
        public void Track_ConvertsPlatformExceptionToFailureAndDoesNotThrow()
        {
            Initialize();
            bridge.ThrowOnTrack = true;
            CFResult result = null;

            Assert.DoesNotThrow(delegate
            {
                CFSDK.Track("event", null, value => result = value);
            });

            Assert.That(result, Is.Not.Null);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NativeFailure));
        }

        [Test]
        public void Track_IgnoresDuplicateNativeCompletions()
        {
            Initialize();
            bridge.CompleteTwice = true;
            int callbackCount = 0;

            CFSDK.Track("event", null, value => callbackCount++);

            Assert.That(callbackCount, Is.EqualTo(1));
        }

        [Test]
        public void FetchActions_DecodesDocumentedEnvelopeAndPreservesRawData()
        {
            Initialize();
            bridge.FetchPayload =
                "{\"data\":[{\"user_id\":\"u1\",\"payload\":{\"type\":\"custom\",\"render_method\":\"in_app_component\",\"delivery_mode\":\"one-off\",\"content\":{\"title\":\"Hi\",\"body\":\"There\",\"color\":\"blue\"},\"attr\":{\"level\":2},\"tags\":[\"a\"],\"internal\":{\"action_id\":96}},\"queued_at\":\"now\"}]}";
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchActions(
                new ActionQuery(ActionTypes.Custom, ActionRenderMethods.InAppComponent, ActionDeliveryModes.OneOff),
                value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(result.Value, Has.Count.EqualTo(1));
            Assert.That(result.Value[0].UserId, Is.EqualTo("u1"));
            Assert.That(result.Value[0].Payload.Content.Title, Is.EqualTo("Hi"));
            Assert.That(result.Value[0].Payload.Content.Values["color"], Is.EqualTo("blue"));
            Assert.That(result.Value[0].Payload.Attributes["level"], Is.EqualTo(2L));
            Assert.That(result.Value[0].Error, Is.Null);
        }

        [Test]
        public void FetchActions_IgnoresAndroidsEmptyPerItemError()
        {
            Initialize();
            bridge.FetchPayload =
                "[{\"payload\":{\"type\":\"custom\",\"render_method\":\"in_app_component\",\"content\":{}},\"error\":\"\"}]";
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchActions(
                new ActionQuery(ActionTypes.Custom, ActionRenderMethods.InAppComponent, ActionDeliveryModes.OneOff),
                value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(result.Value, Has.Count.EqualTo(1));
            Assert.That(result.Value[0].Error, Is.Null);
        }

        [Test]
        public void FetchActions_NormalizesOpenWireValues()
        {
            Initialize();
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchActions(
                new ActionQuery(" MESSAGE ", " IN_APP_MESSAGE ", " ONE-OFF "),
                value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(bridge.ActionType, Is.EqualTo("message"));
            Assert.That(bridge.RenderMethod, Is.EqualTo("in_app_message"));
            Assert.That(bridge.DeliveryMode, Is.EqualTo("one-off"));
        }

        [Test]
        public void FetchActions_NativeShapedOverloadForwardsAllArguments()
        {
            Initialize();
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchActions(
                invActionType: ActionTypes.Custom,
                actionRenderMethodType: ActionRenderMethods.InAppComponent,
                deliveryMode: ActionDeliveryModes.Cached,
                actionAttributes: new Dictionary<string, string>
                {
                    { "screen", "results" },
                    { "experiment", "variant-b" }
                },
                completion: value => result = value);

            Assert.That(result, Is.Not.Null);
            Assert.That(result.IsSuccess, Is.True);
            Assert.That(bridge.FetchActionsCalls, Is.EqualTo(1));
            Assert.That(bridge.ActionType, Is.EqualTo(ActionTypes.Custom));
            Assert.That(bridge.RenderMethod, Is.EqualTo(ActionRenderMethods.InAppComponent));
            Assert.That(bridge.DeliveryMode, Is.EqualTo(ActionDeliveryModes.Cached));
            Assert.That(
                bridge.ActionAttributesJson,
                Is.EqualTo("{\"experiment\":\"variant-b\",\"screen\":\"results\"}"));
        }

        [TestCase(true)]
        [TestCase(false)]
        public void FetchActions_NativeShapedOverloadAcceptsNullOrEmptyAttributes(
            bool useNullAttributes)
        {
            Initialize();
            IDictionary<string, string> actionAttributes = useNullAttributes
                ? null
                : new Dictionary<string, string>();
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchActions(
                invActionType: ActionTypes.Custom,
                actionRenderMethodType: ActionRenderMethods.InAppComponent,
                deliveryMode: ActionDeliveryModes.OneOff,
                actionAttributes: actionAttributes,
                completion: value => result = value);

            Assert.That(result, Is.Not.Null);
            Assert.That(result.IsSuccess, Is.True);
            Assert.That(bridge.FetchActionsCalls, Is.EqualTo(1));
            Assert.That(bridge.ActionAttributesJson, Is.EqualTo("{}"));
        }

        [TestCase(true)]
        [TestCase(false)]
        public void FetchCustomActions_UsesFixedWireValuesAndEmptyAttributes(bool useNullAttributes)
        {
            Initialize();
            IDictionary<string, string> attributes = useNullAttributes
                ? null
                : new Dictionary<string, string>();
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchCustomActions(attributes, value => result = value);

            Assert.That(result, Is.Not.Null);
            Assert.That(result.IsSuccess, Is.True);
            Assert.That(result.Value, Is.Empty);
            Assert.That(bridge.FetchActionsCalls, Is.EqualTo(1));
            Assert.That(bridge.ActionType, Is.EqualTo(ActionTypes.Custom));
            Assert.That(bridge.RenderMethod, Is.EqualTo(ActionRenderMethods.InAppComponent));
            Assert.That(bridge.DeliveryMode, Is.EqualTo(ActionDeliveryModes.OneOff));
            Assert.That(bridge.ActionAttributesJson, Is.EqualTo("{}"));
        }

        [Test]
        public void FetchCustomActions_MapsAttributesToActionQuery()
        {
            Initialize();
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchCustomActions(
                new Dictionary<string, string>
                {
                    { "screen", "results" },
                    { "experiment", "variant-b" }
                },
                value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(
                bridge.ActionAttributesJson,
                Is.EqualTo("{\"experiment\":\"variant-b\",\"screen\":\"results\"}"));
        }

        [Test]
        public void FetchCustomActions_DelegatesResponseParsing()
        {
            Initialize();
            bridge.FetchPayload =
                "{\"data\":[{\"user_id\":\"u1\",\"payload\":{\"type\":\"custom\",\"render_method\":\"in_app_component\",\"delivery_mode\":\"one-off\",\"content\":{\"title\":\"Bonus\",\"body\":\"Unlocked\",\"reward\":25},\"attr\":{\"screen\":\"results\"}}}]}";
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchCustomActions(null, value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(result.Value, Has.Count.EqualTo(1));
            Assert.That(result.Value[0].UserId, Is.EqualTo("u1"));
            Assert.That(result.Value[0].Payload.Type, Is.EqualTo(ActionTypes.Custom));
            Assert.That(
                result.Value[0].Payload.RenderMethod,
                Is.EqualTo(ActionRenderMethods.InAppComponent));
            Assert.That(result.Value[0].Payload.Content.Title, Is.EqualTo("Bonus"));
            Assert.That(result.Value[0].Payload.Content.Values["reward"], Is.EqualTo(25L));
            Assert.That(result.Value[0].Payload.Attributes["screen"], Is.EqualTo("results"));
        }

        [Test]
        public void FetchCustomActions_RequiresInitialization()
        {
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchCustomActions(null, value => result = value);

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NotInitialized));
            Assert.That(bridge.FetchActionsCalls, Is.EqualTo(0));
        }

        [Test]
        public void FetchCustomActions_RejectsMalformedNativeResponse()
        {
            Initialize();
            bridge.FetchPayload = "{\"data\":{}}";
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchCustomActions(null, value => result = value);

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.InvalidResponse));
            Assert.That(bridge.FetchActionsCalls, Is.EqualTo(1));
        }

        [Test]
        public void FetchCustomActions_PropagatesNativeFailureAndCompletesOnce()
        {
            Initialize();
            bridge.FetchActionsResult = NativeBridgeResult.Failure(
                "native_fetch_actions_failed",
                "fetch failed");
            bridge.CompleteFetchActionsTwice = true;
            int callbackCount = 0;
            CFResult<IList<CFAction>> result = null;

            CFSDK.FetchCustomActions(
                null,
                value =>
                {
                    callbackCount++;
                    result = value;
                });

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NativeFailure));
            Assert.That(result.Error.NativeCode, Is.EqualTo("native_fetch_actions_failed"));
            Assert.That(callbackCount, Is.EqualTo(1));
            Assert.That(bridge.FetchActionsCalls, Is.EqualTo(1));
        }

        [Test]
        public void ShowInAppMessage_NormalizesScreen()
        {
            Initialize();
            CFResult result = null;

            CFSDK.ShowInAppMessage(" HOME ", value => result = value);

            Assert.That(result.IsSuccess, Is.True);
            Assert.That(bridge.Screen, Is.EqualTo("home"));
        }

        [Test]
        public void SetPaused_RequiresInitialization()
        {
            CFResult result = null;

            CFSDK.SetPaused(true, value => result = value);

            Assert.That(result.IsSuccess, Is.False);
            Assert.That(result.Error.Code, Is.EqualTo(CFErrorCode.NotInitialized));
            Assert.That(bridge.Paused, Is.Null);
        }

        [Test]
        public void SetPaused_ForwardsRuntimeConsentState()
        {
            Initialize();
            CFResult pauseResult = null;
            CFResult resumeResult = null;

            CFSDK.SetPaused(true, value => pauseResult = value);
            Assert.That(bridge.Paused, Is.True);
            CFSDK.SetPaused(false, value => resumeResult = value);

            Assert.That(pauseResult.IsSuccess, Is.True);
            Assert.That(resumeResult.IsSuccess, Is.True);
            Assert.That(bridge.Paused, Is.False);
        }

        [Test]
        public void ActionOpened_ProvidesCtaFieldsAndAllAttributes()
        {
            ActionOpenedEvent received = null;
            CFSDK.ActionOpened += value => received = value;

            bridge.RaiseActionOpened("{\"cta_id\":\"sku-1\",\"cta_type\":\"redirect\",\"campaign\":\"summer\"}");

            Assert.That(received, Is.Not.Null);
            Assert.That(received.CtaType, Is.EqualTo("redirect"));
            Assert.That(received.CtaId, Is.EqualTo("sku-1"));
            Assert.That(received.Attributes["campaign"], Is.EqualTo("summer"));
        }

        [Test]
        public void ActionOpened_QueuesColdStartActionUntilFirstSubscriber()
        {
            bridge.RaiseActionOpened("{\"cta_id\":\"cold-1\",\"cta_type\":\"redirect\"}");
            ActionOpenedEvent received = null;

            CFSDK.ActionOpened += value => received = value;

            Assert.That(received, Is.Not.Null);
            Assert.That(received.CtaId, Is.EqualTo("cold-1"));
        }

        [Test]
        public void NoOpBridge_ProvidesSuccessfulNoOpsForPublicApi()
        {
            CFSDK.SetBridgeForTesting(new NoOpCFBridge());
            CFResult initializeResult = null;
            CFResult<NotificationPermissionStatus> permissionResult = null;
            CFResult identifyResult = null;
            CFResult catalogResult = null;
            CFResult otherCatalogResult = null;
            CFResult trackResult = null;
            CFResult<IList<CFAction>> actionsResult = null;
            CFResult showResult = null;
            CFResult pauseResult = null;

            CFSDK.RequestNotificationPermission(value => permissionResult = value);
            CFSDK.Initialize("key", null, value => initializeResult = value);
            CFSDK.Identify(
                "player-42",
                IdentityAction.Login,
                null,
                value => identifyResult = value);
            CFSDK.LogUserCatalog(
                "player-42",
                null,
                value => catalogResult = value);
            CFSDK.LogOtherCatalog(
                "household-42",
                "household",
                new Dictionary<string, object> { { "active", true } },
                value => otherCatalogResult = value);
            CFSDK.Track("level_finished", null, value => trackResult = value);
            CFSDK.FetchActions(new ActionQuery(), value => actionsResult = value);
            CFSDK.ShowInAppMessage(ActionScreens.Home, value => showResult = value);
            CFSDK.SetPaused(true, value => pauseResult = value);

            Assert.That(initializeResult, Is.Not.Null);
            Assert.That(permissionResult.IsSuccess, Is.True);
            Assert.That(permissionResult.Value, Is.EqualTo(NotificationPermissionStatus.NotRequired));
            Assert.That(initializeResult.IsSuccess, Is.True);
            Assert.That(CFSDK.IsInitialized, Is.True);
            Assert.That(identifyResult.IsSuccess, Is.True);
            Assert.That(catalogResult.IsSuccess, Is.True);
            Assert.That(otherCatalogResult.IsSuccess, Is.True);
            Assert.That(trackResult.IsSuccess, Is.True);
            Assert.That(actionsResult.IsSuccess, Is.True);
            Assert.That(actionsResult.Value, Is.Empty);
            Assert.That(showResult.IsSuccess, Is.True);
            Assert.That(pauseResult.IsSuccess, Is.True);
        }

        [Test]
        public void NativeBridgeFactory_UsesNoOpBridgeInEditor()
        {
            INativeCFBridge selectedBridge = NativeCFBridgeFactory.Create();

            Assert.That(selectedBridge, Is.TypeOf<NoOpCFBridge>());
            Assert.That(selectedBridge.IsSupported, Is.True);
        }

        private void Initialize()
        {
            CFResult result = null;
            CFSDK.Initialize("key", null, value => result = value);
            Assert.That(result.IsSuccess, Is.True);
        }

        private sealed class FakeBridge : INativeCFBridge
        {
            public FakeBridge()
            {
                Calls = new List<string>();
            }

            public event Action<string> ActionOpenedJson;

            public bool IsSupported
            {
                get { return true; }
            }

            public int InitializeCalls { get; private set; }
            public int NotificationPermissionCalls { get; private set; }
            public int IdentifyCalls { get; private set; }
            public int UserCatalogCalls { get; private set; }
            public int OtherCatalogCalls { get; private set; }
            public int FetchActionsCalls { get; private set; }
            public IList<string> Calls { get; private set; }
            public string SdkKey { get; private set; }
            public string OptionsJson { get; private set; }
            public string IdentityUserId { get; private set; }
            public string IdentityAction { get; private set; }
            public string IdentityAttributesJson { get; private set; }
            public string CatalogUserId { get; private set; }
            public string CatalogJson { get; private set; }
            public string OtherCatalogSubjectId { get; private set; }
            public string OtherCatalogJson { get; private set; }
            public string EventName { get; private set; }
            public string PropertiesJson { get; private set; }
            public string ActionType { get; private set; }
            public string RenderMethod { get; private set; }
            public string DeliveryMode { get; private set; }
            public string ActionAttributesJson { get; private set; }
            public string Screen { get; private set; }
            public bool? Paused { get; private set; }
            public bool ThrowOnTrack { get; set; }
            public bool ThrowOnNotificationPermission { get; set; }
            public bool ThrowOnUserCatalog { get; set; }
            public bool CompleteTwice { get; set; }
            public string FetchPayload { get; set; }
            public NativeBridgeResult InitializeResult { get; set; }
            public NativeBridgeResult IdentifyResult { get; set; }
            public NativeBridgeResult NotificationPermissionResult { get; set; }
            public NativeBridgeResult UserCatalogResult { get; set; }
            public NativeBridgeResult FetchActionsResult { get; set; }
            public bool HoldInitialization { get; set; }
            public bool CompleteIdentifyTwice { get; set; }
            public bool CompleteUserCatalogTwice { get; set; }
            public bool CompleteFetchActionsTwice { get; set; }

            private Action<NativeBridgeResult> heldInitialization;

            public void RequestNotificationPermission(Action<NativeBridgeResult> completion)
            {
                if (ThrowOnNotificationPermission)
                {
                    throw new InvalidOperationException("boom");
                }

                NotificationPermissionCalls++;
                completion(
                    NotificationPermissionResult ??
                    NativeBridgeResult.Success("{\"status\":\"authorized\"}"));
            }

            public void Initialize(
                string sdkKey,
                string optionsJson,
                Action<NativeBridgeResult> completion)
            {
                InitializeCalls++;
                Calls.Add("initialize");
                SdkKey = sdkKey;
                OptionsJson = optionsJson;
                if (HoldInitialization)
                {
                    heldInitialization = completion;
                    return;
                }
                completion(InitializeResult ?? NativeBridgeResult.Success());
            }

            public void CompleteHeldInitialization()
            {
                Action<NativeBridgeResult> completion = heldInitialization;
                heldInitialization = null;
                completion(InitializeResult ?? NativeBridgeResult.Success());
            }

            public void Identify(
                string userId,
                string action,
                string attributesJson,
                Action<NativeBridgeResult> completion)
            {
                IdentifyCalls++;
                Calls.Add("identify");
                IdentityUserId = userId;
                IdentityAction = action;
                IdentityAttributesJson = attributesJson;
                completion(IdentifyResult ?? NativeBridgeResult.Success());
                if (CompleteIdentifyTwice)
                {
                    completion(NativeBridgeResult.Failure("native_error", "late"));
                }
            }

            public void LogUserCatalog(
                string userId,
                string catalogJson,
                Action<NativeBridgeResult> completion)
            {
                if (ThrowOnUserCatalog)
                {
                    throw new InvalidOperationException("boom");
                }

                UserCatalogCalls++;
                Calls.Add("user_catalog");
                CatalogUserId = userId;
                CatalogJson = catalogJson;
                completion(UserCatalogResult ?? NativeBridgeResult.Success());
                if (CompleteUserCatalogTwice)
                {
                    completion(NativeBridgeResult.Failure("native_error", "late"));
                }
            }

            public void LogOtherCatalog(
                string subjectId,
                string catalogJson,
                Action<NativeBridgeResult> completion)
            {
                OtherCatalogCalls++;
                OtherCatalogSubjectId = subjectId;
                OtherCatalogJson = catalogJson;
                completion(NativeBridgeResult.Success());
            }

            public void Track(
                string eventName,
                string propertiesJson,
                Action<NativeBridgeResult> completion)
            {
                if (ThrowOnTrack)
                {
                    throw new InvalidOperationException("boom");
                }

                EventName = eventName;
                PropertiesJson = propertiesJson;
                completion(NativeBridgeResult.Success());
                if (CompleteTwice)
                {
                    completion(NativeBridgeResult.Failure("native_error", "late"));
                }
            }

            public void FetchActions(
                string actionType,
                string renderMethod,
                string deliveryMode,
                string attributesJson,
                Action<NativeBridgeResult> completion)
            {
                FetchActionsCalls++;
                ActionType = actionType;
                RenderMethod = renderMethod;
                DeliveryMode = deliveryMode;
                ActionAttributesJson = attributesJson;
                completion(
                    FetchActionsResult ??
                    NativeBridgeResult.Success(FetchPayload));
                if (CompleteFetchActionsTwice)
                {
                    completion(NativeBridgeResult.Success("[]"));
                }
            }

            public void ShowInAppMessage(string screen, Action<NativeBridgeResult> completion)
            {
                Screen = screen;
                completion(NativeBridgeResult.Success());
            }

            public void SetPaused(bool paused, Action<NativeBridgeResult> completion)
            {
                Paused = paused;
                completion(NativeBridgeResult.Success());
            }

            public void RaiseActionOpened(string attributesJson)
            {
                Action<string> handler = ActionOpenedJson;
                if (handler != null)
                {
                    handler(attributesJson);
                }
            }
        }
    }
}
