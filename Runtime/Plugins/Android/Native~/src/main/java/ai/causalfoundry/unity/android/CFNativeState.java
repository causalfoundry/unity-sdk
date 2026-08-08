package ai.causalfoundry.unity.android;

import android.app.Application;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleEventObserver;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.ProcessLifecycleOwner;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.lang.reflect.Type;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

import io.kenkai.android.sdk.core.CFCoreEvent;
import io.kenkai.android.sdk.core.action.interfaces.ActionOnClickInterface;
import io.kenkai.android.sdk.core.action.interfaces.ActionOnClickObject;
import io.kenkai.android.sdk.core.action.models.BackendActionPayload;
import io.kenkai.android.sdk.core.builders.CFLog;
import io.kenkai.android.sdk.core.catalog.catalog_models.CoreCatalogType;
import io.kenkai.android.sdk.core.catalog.catalog_models.OtherCatalogModel;
import io.kenkai.android.sdk.core.catalog.catalog_models.UserCatalogModel;
import io.kenkai.android.sdk.core.event_models.event_objects.IdentifyObject;
import io.kenkai.android.sdk.core.event_models.event_objects.TrackEventObject;
import io.kenkai.android.sdk.core.event_types.CoreEventType;
import io.kenkai.android.sdk.core.event_types.CountryCode;
import io.kenkai.android.sdk.core.event_types.IdentifyAction;
import kotlin.Unit;
import kotlin.jvm.functions.Function1;

/** Process-wide state hidden behind {@link CFUnityBridge}. */
final class CFNativeState {
    static final String META_SDK_KEY = "ai.causalfoundry.unity.SDK_KEY";
    static final String META_OPTIONS_JSON = "ai.causalfoundry.unity.OPTIONS_JSON";
    static final String CORE_META_SDK_KEY = "io.kenkai.android.sdk.APPLICATION_KEY";

    private static final String LOG_TAG = "CFUnityBridge";
    private static final String PREFERENCES = "ai.causalfoundry.unity.bridge";
    private static final String PENDING_ACTIONS = "pending_actions";
    private static final int MAX_PENDING_ACTIONS = 32;
    private static final long FETCH_TIMEOUT_MILLIS = 60_000L;

    private static final Object LOCK = new Object();
    private static final Handler MAIN_HANDLER = new Handler(Looper.getMainLooper());
    private static final Gson GSON = new Gson();
    private static final Type OBJECT_MAP_TYPE =
        new TypeToken<Map<String, Object>>() { }.getType();
    private static final Type STRING_MAP_TYPE =
        new TypeToken<Map<String, String>>() { }.getType();
    private static final Set<String> RESERVED_TRACK_NAMES =
        Collections.unmodifiableSet(new HashSet<String>(Arrays.asList(
            "identify", "page", "app", "search", "media", "nudge_response",
            "action_response", "rate", "module_selection", "item", "delivery",
            "checkout", "cart", "cancel_checkout", "item_report", "item_request",
            "module", "exam", "question", "level", "milestone", "promo", "survey",
            "reward", "payment", "patient", "encounter", "appointment", "diagnosis")));
    private static final Set<String> RESERVED_CATALOG_NAMES =
        Collections.unmodifiableSet(new HashSet<String>(Arrays.asList(
            "user", "media", "user_chw", "site", "patient", "drug", "grocery",
            "blood", "oxygen", "medical_equipment", "facility", "survey", "reward",
            "other")));

    private static Application application;
    private static CFUnityCallback callback;
    private static LifecycleEventObserver lifecycleObserver;
    private static boolean observerInstalled;
    private static boolean actionListenerInstalled;
    private static boolean coreCreated;
    private static boolean pendingDeliveryScheduled;
    private static String sdkKey = "";
    private static String optionsJson = "{}";
    private static Boolean runtimePauseOverride;

    private CFNativeState() {
    }

    static void startup(Application app) {
        if (app == null) {
            return;
        }

        synchronized (LOCK) {
            if (application == null) {
                application = app;
                readManifestConfigurationLocked(app);
            }
            installActionListenerLocked();
            if (!observerInstalled) {
                lifecycleObserver = new LifecycleEventObserver() {
                    @Override
                    public void onStateChanged(
                        LifecycleOwner source,
                        Lifecycle.Event event) {
                        onLifecycleEvent(event);
                    }
                };
                ProcessLifecycleOwner.get().getLifecycle().addObserver(lifecycleObserver);
                observerInstalled = true;
            }
        }
    }

    static void setCallback(CFUnityCallback newCallback) {
        synchronized (LOCK) {
            callback = newCallback;
        }
        schedulePendingActionDelivery();
    }

    static void configure(String requestId, String newSdkKey, String newOptionsJson) {
        Application currentApplication;
        String normalizedKey = normalizeSdkKey(newSdkKey);
        String normalizedOptions = normalizeJsonObject(newOptionsJson);
        String previousOptions;
        boolean wasCoreCreated;

        try {
            parseObject(normalizedOptions);
        } catch (IllegalArgumentException error) {
            completeFailure(requestId, "invalid_options", messageFor(error));
            return;
        }

        synchronized (LOCK) {
            currentApplication = application;
            if (currentApplication == null) {
                completeFailure(
                    requestId,
                    "startup_unavailable",
                    "AndroidX Startup did not provide an Application. Use the Activity overload or enable the Startup provider.");
                return;
            }

            if (normalizedKey.length() == 0) {
                normalizedKey = sdkKey;
            }
            if (normalizedKey.length() == 0) {
                completeFailure(
                    requestId,
                    "invalid_sdk_key",
                    "SDK key is empty and no manifest SDK key was found.");
                return;
            }
            if (coreCreated && sdkKey.length() > 0 && !sdkKey.equals(normalizedKey)) {
                completeFailure(
                    requestId,
                    "already_initialized",
                    "The Android Core SDK is already initialized with a different SDK key.");
                return;
            }

            previousOptions = optionsJson;
            wasCoreCreated = coreCreated;
            if (wasCoreCreated && !previousOptions.equals(normalizedOptions)) {
                completeFailure(
                    requestId,
                    "configuration_conflict",
                    "The Android Core SDK is already initialized with different options.");
                return;
            }

            sdkKey = normalizedKey;
            optionsJson = normalizedOptions;
        }

        try {
            if (!wasCoreCreated) {
                ensureCoreInitializedForCurrentState();
            }
            completeSuccess(requestId, null);
        } catch (Throwable error) {
            completeFailure(requestId, "initialization_failed", messageFor(error));
        }
    }

    static void identify(
        String requestId,
        String userId,
        String action,
        String attributesJson) {
        if (!ensureReady(requestId)) {
            return;
        }
        if (isBlank(userId)) {
            completeFailure(requestId, "invalid_user_id", "userId is required.");
            return;
        }

        try {
            JSONObject attributes = parseObject(attributesJson);
            IdentifyAction identifyAction = parseIdentifyAction(action);
            String referralCode = optionalString(attributes, "referral_code", "");
            String blockedReason = optionalString(attributes, "blocked_reason", "");
            String blockedRemarks = optionalString(attributes, "blocked_remarks", "");
            Map<String, Object> meta = objectMap(attributes.optJSONObject("meta"));

            if ((identifyAction == IdentifyAction.Blocked
                || identifyAction == IdentifyAction.UnBlocked)
                && isBlank(blockedReason)) {
                completeFailure(
                    requestId,
                    "invalid_blocked_reason",
                    "blocked_reason is required for blocked and unblocked identity actions.");
                return;
            }

            IdentifyObject identifyObject = new IdentifyObject(
                userId.trim(),
                identifyAction,
                referralCode,
                blockedReason,
                blockedRemarks,
                meta);

            CFCoreEvent.INSTANCE.logIngest(
                CoreEventType.Identify,
                identifyObject,
                optionalBoolean(attributes, "immediate"),
                optionalTimestamp(attributes));
            completeSuccess(requestId, null);
        } catch (IllegalArgumentException error) {
            completeFailure(requestId, "invalid_identify", messageFor(error));
        } catch (Throwable error) {
            completeFailure(requestId, "native_identify_failed", messageFor(error));
        }
    }

    static void track(String requestId, String eventName, String propertiesJson) {
        if (!ensureReady(requestId)) {
            return;
        }
        if (isBlank(eventName)) {
            completeFailure(requestId, "invalid_event_name", "eventName is required.");
            return;
        }
        String normalizedEventName = eventName.trim()
            .toLowerCase(Locale.US)
            .replace(" ", "_");
        if (RESERVED_TRACK_NAMES.contains(normalizedEventName)) {
            completeFailure(
                requestId,
                "reserved_event_name",
                "Track event name is reserved by the Causal Foundry Core SDK: " + eventName);
            return;
        }

        try {
            JSONObject properties = parseObject(propertiesJson);
            String property = nullableString(properties, "property");
            Map<String, Object> meta = objectMap(properties.optJSONObject("meta"));
            TrackEventObject trackObject = new TrackEventObject(
                normalizedEventName,
                property,
                meta);

            CFCoreEvent.INSTANCE.logIngest(
                CoreEventType.Track,
                trackObject,
                optionalBoolean(properties, "immediate"),
                optionalTimestamp(properties));
            completeSuccess(requestId, null);
        } catch (IllegalArgumentException error) {
            completeFailure(requestId, "invalid_track", messageFor(error));
        } catch (Throwable error) {
            completeFailure(requestId, "native_track_failed", messageFor(error));
        }
    }

    static void logUserCatalog(String requestId, String userId, String catalogJson) {
        if (!ensureReady(requestId)) {
            return;
        }
        if (isBlank(userId)) {
            completeFailure(requestId, "invalid_user_id", "userId is required.");
            return;
        }

        try {
            JSONObject catalog = parseObject(catalogJson);
            UserCatalogModel model = GSON.fromJson(catalog.toString(), UserCatalogModel.class);
            if (model == null) {
                completeFailure(
                    requestId,
                    "invalid_user_catalog",
                    "User catalog JSON must contain an object.");
                return;
            }

            String country = model.getCountry();
            if (!isBlank(country) && !isKnownCountry(country)) {
                completeFailure(
                    requestId,
                    "invalid_user_catalog",
                    "Unsupported user catalog country '" + country + "'.");
                return;
            }

            CFCoreEvent.INSTANCE.logCatalog(
                CoreCatalogType.User,
                userId.trim(),
                model);
            completeSuccess(requestId, null);
        } catch (IllegalArgumentException error) {
            completeFailure(requestId, "invalid_user_catalog", messageFor(error));
        } catch (Throwable error) {
            completeFailure(requestId, "native_user_catalog_failed", messageFor(error));
        }
    }

    static void logOtherCatalog(String requestId, String subjectId, String catalogJson) {
        if (!ensureReady(requestId)) {
            return;
        }

        try {
            if (isBlank(subjectId)) {
                throw new IllegalArgumentException("subjectId is required.");
            }

            JSONObject catalog = parseObject(catalogJson);
            String name = nullableString(catalog, "name");
            String normalizedName = normalizeCatalogName(name);
            if (normalizedName.length() == 0) {
                throw new IllegalArgumentException("Catalog name is required.");
            }
            if (RESERVED_CATALOG_NAMES.contains(normalizedName)) {
                throw new IllegalArgumentException(
                    "Catalog name '" + name + "' is reserved and cannot be used.");
            }

            Object metaValue = catalog.opt("meta");
            if (!(metaValue instanceof JSONObject)) {
                throw new IllegalArgumentException("Catalog meta must be a JSON object.");
            }
            Map<String, Object> meta = objectMap((JSONObject) metaValue);
            if (meta == null || meta.isEmpty()) {
                throw new IllegalArgumentException("Catalog meta is required.");
            }

            OtherCatalogModel model = new OtherCatalogModel(name, meta);
            CFCoreEvent.INSTANCE.logCatalog(
                CoreCatalogType.Other,
                subjectId.trim(),
                model);
            completeSuccess(requestId, null);
        } catch (IllegalArgumentException error) {
            completeFailure(requestId, "invalid_other_catalog", messageFor(error));
        } catch (Throwable error) {
            completeFailure(requestId, "native_other_catalog_failed", messageFor(error));
        }
    }

    static void fetchActions(
        final String requestId,
        String actionType,
        String renderMethod,
        String deliveryMode,
        String attributesJson) {
        if (!ensureReady(requestId)) {
            return;
        }
        if (isBlank(actionType) || isBlank(renderMethod)) {
            completeFailure(
                requestId,
                "invalid_action_request",
                "actionType and renderMethod are required.");
            return;
        }

        try {
            final Map<String, String> attributes = stringMap(parseObject(attributesJson));
            String normalizedDeliveryMode = isBlank(deliveryMode) ? "one-off" : deliveryMode.trim();
            final AtomicBoolean completionGate = new AtomicBoolean(false);
            final Runnable timeout = new Runnable() {
                @Override
                public void run() {
                    if (completionGate.compareAndSet(false, true)) {
                        completeFailure(
                            requestId,
                            "timeout",
                            "The native action fetch did not complete within 60 seconds.");
                    }
                }
            };
            MAIN_HANDLER.postDelayed(timeout, FETCH_TIMEOUT_MILLIS);

            try {
                CFCoreEvent.INSTANCE.fetchActions(
                    actionType.trim(),
                    renderMethod.trim(),
                    normalizedDeliveryMode,
                    attributes,
                    new Function1<List<BackendActionPayload>, Unit>() {
                        @Override
                        public Unit invoke(List<BackendActionPayload> actions) {
                            if (!completionGate.compareAndSet(false, true)) {
                                return Unit.INSTANCE;
                            }
                            MAIN_HANDLER.removeCallbacks(timeout);
                            List<BackendActionPayload> safeActions = actions == null
                                ? Collections.<BackendActionPayload>emptyList()
                                : actions;
                            completeSuccess(requestId, GSON.toJson(safeActions));
                            return Unit.INSTANCE;
                        }
                    });
            } catch (Throwable error) {
                MAIN_HANDLER.removeCallbacks(timeout);
                if (completionGate.compareAndSet(false, true)) {
                    if (error instanceof IllegalArgumentException) {
                        completeFailure(requestId, "invalid_action_request", messageFor(error));
                    } else {
                        completeFailure(requestId, "native_fetch_actions_failed", messageFor(error));
                    }
                }
            }
        } catch (IllegalArgumentException error) {
            completeFailure(requestId, "invalid_action_request", messageFor(error));
        }
    }

    static void showInAppMessage(String requestId, String screen) {
        if (!ensureReady(requestId)) {
            return;
        }
        try {
            // Empty is Core's ActionScreenType.None/default screen value.
            CFCoreEvent.INSTANCE.showInAppMessage(screen == null ? "" : screen.trim());
            completeSuccess(requestId, null);
        } catch (Throwable error) {
            completeFailure(requestId, "native_show_in_app_failed", messageFor(error));
        }
    }

    static void setPaused(String requestId, boolean paused) {
        if (!ensureReady(requestId)) {
            return;
        }
        Boolean previousOverride;
        synchronized (LOCK) {
            previousOverride = runtimePauseOverride;
            runtimePauseOverride = Boolean.valueOf(paused);
        }
        try {
            new CFLog.Builder().setPauseSDK(paused);
            completeSuccess(requestId, null);
        } catch (Throwable error) {
            synchronized (LOCK) {
                runtimePauseOverride = previousOverride;
            }
            completeFailure(requestId, "native_pause_failed", messageFor(error));
        }
    }

    private static void onLifecycleEvent(Lifecycle.Event event) {
        if (event == null || event == Lifecycle.Event.ON_ANY) {
            return;
        }
        try {
            if (event == Lifecycle.Event.ON_CREATE) {
                invokeCoreLifecycle(Lifecycle.Event.ON_CREATE);
            } else if (event == Lifecycle.Event.ON_RESUME) {
                ensureCoreCreated();
                if (isCoreCreated()) {
                    invokeCoreLifecycle(Lifecycle.Event.ON_RESUME);
                }
            } else if ((event == Lifecycle.Event.ON_PAUSE
                || event == Lifecycle.Event.ON_STOP) && isCoreCreated()) {
                invokeCoreLifecycle(event);
            }
        } catch (Throwable error) {
            // A ContentProvider initializer must never crash the host application.
            Log.e(LOG_TAG, "Core lifecycle initialization failed", error);
        }
    }

    private static void ensureCoreInitializedForCurrentState() {
        boolean wasCreated = isCoreCreated();
        ensureCoreCreated();
        Lifecycle.State state = ProcessLifecycleOwner.get().getLifecycle().getCurrentState();
        if (!wasCreated
            && isCoreCreated()
            && state.isAtLeast(Lifecycle.State.RESUMED)) {
            invokeCoreLifecycle(Lifecycle.Event.ON_RESUME);
        }
    }

    private static void ensureCoreCreated() {
        if (isCoreCreated() || !hasSdkKey()) {
            return;
        }
        Lifecycle.State state = ProcessLifecycleOwner.get().getLifecycle().getCurrentState();
        if (state.isAtLeast(Lifecycle.State.CREATED)) {
            invokeCoreLifecycle(Lifecycle.Event.ON_CREATE);
        }
    }

    private static void invokeCoreLifecycle(Lifecycle.Event event) {
        Application currentApplication;
        String currentKey;
        String currentOptions;
        Boolean currentPauseOverride;
        synchronized (LOCK) {
            currentApplication = application;
            currentKey = sdkKey;
            currentOptions = optionsJson;
            currentPauseOverride = runtimePauseOverride;
            if (currentApplication == null || currentKey.length() == 0) {
                return;
            }
            if (event == Lifecycle.Event.ON_CREATE && coreCreated) {
                return;
            }
        }

        CFLog.Builder builder = new CFLog.Builder()
            .init(currentApplication)
            .setSdkKey(currentKey)
            .setLifecycleEvent(event);
        applyOptions(builder, parseObject(currentOptions), currentPauseOverride);
        builder.build();

        if (event == Lifecycle.Event.ON_CREATE) {
            synchronized (LOCK) {
                coreCreated = true;
            }
        }
    }

    private static void applyOptions(
        CFLog.Builder builder,
        JSONObject options,
        Boolean pauseOverride) {
        Boolean pauseSdk = pauseOverride != null
            ? pauseOverride
            : strictOptionBoolean(options, "pause_sdk", "pauseSDK");
        if (pauseSdk != null) {
            builder.setPauseSDK(pauseSdk.booleanValue());
        }

        Boolean enableDebugMode = strictOptionBoolean(
            options,
            "enable_debug_mode",
            "enableDebugMode");
        Boolean disableDebugMode = strictOptionBoolean(
            options,
            "disable_debug_mode",
            "disableDebugMode");
        if ((enableDebugMode != null && !enableDebugMode.booleanValue())
            || (disableDebugMode != null && disableDebugMode.booleanValue())) {
            builder.disableDebugMode();
        }

        Boolean disableAutoPageTracking = strictOptionBoolean(
            options,
            "disable_auto_page_tracking",
            "disable_auto_page_track",
            "disableAutoPageTracking",
            "disableAutoPageTrack");
        Boolean autoTrackPages = strictOptionBoolean(options, "auto_track_pages", "autoTrackPages");
        if ((disableAutoPageTracking != null && disableAutoPageTracking.booleanValue())
            || (autoTrackPages != null && !autoTrackPages.booleanValue())) {
            builder.disableAutoPageTrack();
        }

        Boolean disableAutoCollect = strictOptionBoolean(
            options,
            "disable_auto_collect_app_events",
            "disableAutoCollectAppEvents");
        if (disableAutoCollect != null && disableAutoCollect.booleanValue()) {
            builder.disableAutoCollectAppEvents();
        }

        Boolean allowAnonymousUsers = strictOptionBoolean(
            options,
            "allow_anonymous_users",
            "allowAnonymousUsers");
        if (allowAnonymousUsers != null && allowAnonymousUsers.booleanValue()) {
            builder.allowAnonymousUsers();
        }

        Boolean autoShowInAppMessages = strictOptionBoolean(
            options,
            "auto_show_in_app_messages",
            "auto_show_in_app_message",
            "autoShowInAppMessages",
            "autoShowInAppMessage");
        if (autoShowInAppMessages != null) {
            builder.setAutoShowInAppMessage(autoShowInAppMessages.booleanValue());
        }

        Boolean updateImmediately = strictOptionBoolean(
            options,
            "update_immediately",
            "updateImmediately");
        if (updateImmediately != null) {
            builder.updateImmediately(updateImmediately.booleanValue());
        }

        String notificationTitle = optionString(
            options,
            "ingest_notification_title",
            "ingestNotificationTitle");
        if (notificationTitle != null) {
            builder.setIngestNotificationTitle(notificationTitle);
        }
        String notificationDescription = optionString(
            options,
            "ingest_notification_description",
            "ingestNotificationDescription");
        if (notificationDescription != null) {
            builder.setIngestNotificationDescription(notificationDescription);
        }
        if (hasEither(
            options,
            "ingest_notification_enabled",
            "ingestNotificationEnabled")) {
            builder.setIngestNotificationEnabled(optionBoolean(
                options,
                "ingest_notification_enabled",
                "ingestNotificationEnabled",
                true));
        }
        Long notificationInterval = optionLong(
            options,
            "ingest_notification_interval_ms",
            "ingestNotificationIntervalMs");
        if (notificationInterval != null && notificationInterval >= 0L) {
            builder.updateIngestNotificationShowInterval(notificationInterval);
        }
        Long inAppDelay = optionLong(
            options,
            "in_app_message_initial_delay_ms",
            "inAppMessageInitialDelayMs");
        if (inAppDelay != null && inAppDelay >= 0L) {
            builder.updateInAppMessageInitialDelay(inAppDelay);
        }
    }

    private static boolean ensureReady(String requestId) {
        if (!isCoreCreated()) {
            completeFailure(
                requestId,
                "not_initialized",
                "Initialize the Causal Foundry SDK before calling this method.");
            return false;
        }
        return true;
    }

    private static boolean isCoreCreated() {
        synchronized (LOCK) {
            return coreCreated;
        }
    }

    private static boolean hasSdkKey() {
        synchronized (LOCK) {
            return sdkKey.length() > 0;
        }
    }

    private static void installActionListenerLocked() {
        if (actionListenerInstalled) {
            return;
        }
        ActionOnClickObject.Companion.setActionOnClickInterface(
            new ActionOnClickInterface() {
                @Override
                public void onActionOpened(Map<String, String> actionAttributes) {
                    queueActionOpened(actionAttributes);
                }
            });
        actionListenerInstalled = true;
    }

    private static void queueActionOpened(Map<String, String> actionAttributes) {
        Application currentApplication;
        synchronized (LOCK) {
            currentApplication = application;
        }
        if (currentApplication == null) {
            return;
        }

        try {
            JSONObject envelope = new JSONObject();
            envelope.put("id", UUID.randomUUID().toString());
            envelope.put(
                "attributes",
                new JSONObject(actionAttributes == null
                    ? Collections.<String, String>emptyMap()
                    : actionAttributes));

            SharedPreferences preferences = preferences(currentApplication);
            synchronized (LOCK) {
                JSONArray pending = readPending(preferences);
                while (pending.length() >= MAX_PENDING_ACTIONS) {
                    pending.remove(0);
                }
                pending.put(envelope);
                preferences.edit().putString(PENDING_ACTIONS, pending.toString()).commit();
            }
            schedulePendingActionDelivery();
            launchApplicationIfBackground(currentApplication);
        } catch (Throwable error) {
            Log.e(LOG_TAG, "Unable to persist action-open attributes", error);
        }
    }

    private static void schedulePendingActionDelivery() {
        synchronized (LOCK) {
            if (callback == null || application == null || pendingDeliveryScheduled) {
                return;
            }
            pendingDeliveryScheduled = true;
        }

        MAIN_HANDLER.post(new Runnable() {
            @Override
            public void run() {
                deliverPendingActionsOnMainThread();
            }
        });
    }

    private static void deliverPendingActionsOnMainThread() {
        while (true) {
            CFUnityCallback currentCallback;
            Application currentApplication;
            JSONObject first;
            synchronized (LOCK) {
                currentCallback = callback;
                currentApplication = application;
                if (currentCallback == null || currentApplication == null) {
                    pendingDeliveryScheduled = false;
                    return;
                }
                JSONArray pending = readPending(preferences(currentApplication));
                first = pending.optJSONObject(0);
                if (first == null) {
                    pendingDeliveryScheduled = false;
                    return;
                }
            }

            try {
                JSONObject attributes = first.optJSONObject("attributes");
                currentCallback.onActionOpened(
                    attributes == null ? "{}" : attributes.toString());
            } catch (Throwable error) {
                synchronized (LOCK) {
                    pendingDeliveryScheduled = false;
                }
                Log.e(LOG_TAG, "Managed action-open callback failed", error);
                return;
            }

            synchronized (LOCK) {
                SharedPreferences currentPreferences = preferences(currentApplication);
                JSONArray pending = readPending(currentPreferences);
                String deliveredId = first.optString("id", "");
                for (int index = 0; index < pending.length(); index++) {
                    JSONObject item = pending.optJSONObject(index);
                    if (item != null && deliveredId.equals(item.optString("id", ""))) {
                        pending.remove(index);
                        break;
                    }
                }
                currentPreferences.edit()
                    .putString(PENDING_ACTIONS, pending.toString())
                    .commit();
            }
        }
    }

    private static void launchApplicationIfBackground(Application currentApplication) {
        try {
            Lifecycle.State state = ProcessLifecycleOwner.get()
                .getLifecycle()
                .getCurrentState();
            if (state.isAtLeast(Lifecycle.State.STARTED)) {
                return;
            }
            Intent launchIntent = currentApplication.getPackageManager()
                .getLaunchIntentForPackage(currentApplication.getPackageName());
            if (launchIntent != null) {
                launchIntent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_ACTIVITY_CLEAR_TOP
                        | Intent.FLAG_ACTIVITY_SINGLE_TOP);
                currentApplication.startActivity(launchIntent);
            }
        } catch (Throwable error) {
            Log.e(LOG_TAG, "Unable to launch application for action-open callback", error);
        }
    }

    private static SharedPreferences preferences(Context context) {
        return context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE);
    }

    private static JSONArray readPending(SharedPreferences preferences) {
        try {
            return new JSONArray(preferences.getString(PENDING_ACTIONS, "[]"));
        } catch (JSONException ignored) {
            return new JSONArray();
        }
    }

    private static void readManifestConfigurationLocked(Application app) {
        try {
            ApplicationInfo info = app.getPackageManager().getApplicationInfo(
                app.getPackageName(),
                PackageManager.GET_META_DATA);
            Bundle metadata = info.metaData;
            if (metadata == null) {
                return;
            }
            String manifestKey = bundleString(metadata, META_SDK_KEY);
            if (isBlank(manifestKey)) {
                manifestKey = bundleString(metadata, CORE_META_SDK_KEY);
            }
            sdkKey = normalizeSdkKey(manifestKey);
            optionsJson = normalizeJsonObject(bundleString(metadata, META_OPTIONS_JSON));
        } catch (Throwable error) {
            Log.w(LOG_TAG, "Unable to read manifest configuration", error);
        }
    }

    private static String bundleString(Bundle bundle, String key) {
        Object value = bundle.get(key);
        return value == null ? "" : String.valueOf(value);
    }

    private static IdentifyAction parseIdentifyAction(String action) {
        if (isBlank(action)) {
            throw new IllegalArgumentException("action is required.");
        }
        String normalized = action.trim()
            .toLowerCase(Locale.US)
            .replace("_", "")
            .replace("-", "");
        if ("register".equals(normalized)) {
            return IdentifyAction.Register;
        }
        if ("login".equals(normalized)) {
            return IdentifyAction.Login;
        }
        if ("logout".equals(normalized)) {
            return IdentifyAction.Logout;
        }
        if ("blocked".equals(normalized)) {
            return IdentifyAction.Blocked;
        }
        if ("unblocked".equals(normalized)) {
            return IdentifyAction.UnBlocked;
        }
        throw new IllegalArgumentException("Unsupported identify action: " + action);
    }

    private static JSONObject parseObject(String json) {
        try {
            return new JSONObject(normalizeJsonObject(json));
        } catch (JSONException error) {
            throw new IllegalArgumentException("Expected a JSON object.", error);
        }
    }

    private static String normalizeJsonObject(String json) {
        return isBlank(json) ? "{}" : json.trim();
    }

    private static String normalizeSdkKey(String key) {
        if (isBlank(key)) {
            return "";
        }
        String normalized = key.trim();
        if (normalized.regionMatches(true, 0, "Bearer ", 0, 7)) {
            return normalized.substring(7).trim();
        }
        return normalized;
    }

    private static String normalizeCatalogName(String name) {
        return name == null ? "" : name
            .replaceAll("^[\\s\\p{Z}\\uFEFF]+|[\\s\\p{Z}\\uFEFF]+$", "")
            .replaceAll("[\\s\\p{Z}\\uFEFF]+", "_")
            .toLowerCase(Locale.US);
    }

    private static Map<String, Object> objectMap(JSONObject object) {
        if (object == null) {
            return null;
        }
        return GSON.fromJson(object.toString(), OBJECT_MAP_TYPE);
    }

    private static Map<String, String> stringMap(JSONObject object) {
        if (object == null || object.length() == 0) {
            return Collections.emptyMap();
        }
        try {
            return GSON.fromJson(object.toString(), STRING_MAP_TYPE);
        } catch (RuntimeException error) {
            throw new IllegalArgumentException(
                "Action attributes must contain string values.",
                error);
        }
    }

    private static Boolean optionalBoolean(JSONObject object, String key) {
        if (!object.has(key) || object.isNull(key)) {
            return null;
        }
        Object value = object.opt(key);
        if (!(value instanceof Boolean)) {
            throw new IllegalArgumentException(key + " must be a boolean.");
        }
        return (Boolean) value;
    }

    private static Long optionalTimestamp(JSONObject object) {
        if (!object.has("timestamp_ms") || object.isNull("timestamp_ms")) {
            return null;
        }
        Object value = object.opt("timestamp_ms");
        if (!(value instanceof Number)) {
            throw new IllegalArgumentException("timestamp_ms must be a number.");
        }
        long timestamp = ((Number) value).longValue();
        return timestamp <= 0L ? null : Long.valueOf(timestamp);
    }

    private static String optionalString(JSONObject object, String key, String defaultValue) {
        String value = nullableString(object, key);
        return value == null ? defaultValue : value;
    }

    private static String nullableString(JSONObject object, String key) {
        if (!object.has(key) || object.isNull(key)) {
            return null;
        }
        Object value = object.opt(key);
        if (!(value instanceof String)) {
            throw new IllegalArgumentException(key + " must be a string.");
        }
        return (String) value;
    }

    private static boolean optionBoolean(
        JSONObject options,
        String snakeCase,
        String camelCase,
        boolean defaultValue) {
        String key = options.has(snakeCase) ? snakeCase : camelCase;
        return options.has(key) ? options.optBoolean(key, defaultValue) : defaultValue;
    }

    private static Boolean strictOptionBoolean(JSONObject options, String... keys) {
        for (String key : keys) {
            if (!options.has(key) || options.isNull(key)) {
                continue;
            }
            Object value = options.opt(key);
            if (!(value instanceof Boolean)) {
                throw new IllegalArgumentException(key + " must be a boolean.");
            }
            return (Boolean) value;
        }
        return null;
    }

    private static boolean optionValue(
        JSONObject options,
        boolean defaultValue,
        String... keys) {
        Boolean value = strictOptionBoolean(options, keys);
        return value == null ? defaultValue : value.booleanValue();
    }

    private static String optionString(
        JSONObject options,
        String snakeCase,
        String camelCase) {
        String key = options.has(snakeCase) ? snakeCase : camelCase;
        if (!options.has(key) || options.isNull(key)) {
            return null;
        }
        return options.optString(key, null);
    }

    private static Long optionLong(
        JSONObject options,
        String snakeCase,
        String camelCase) {
        String key = options.has(snakeCase) ? snakeCase : camelCase;
        if (!options.has(key) || options.isNull(key)) {
            return null;
        }
        Object value = options.opt(key);
        return value instanceof Number ? Long.valueOf(((Number) value).longValue()) : null;
    }

    private static boolean hasEither(
        JSONObject options,
        String snakeCase,
        String camelCase) {
        return options.has(snakeCase) || options.has(camelCase);
    }

    private static boolean isKnownCountry(String value) {
        for (CountryCode country : CountryCode.values()) {
            if (country.toString().equals(value)) {
                return true;
            }
        }
        return false;
    }

    private static void completeSuccess(String requestId, String payloadJson) {
        complete(requestId, true, payloadJson, null, null);
    }

    private static void completeFailure(
        String requestId,
        String errorCode,
        String errorMessage) {
        complete(requestId, false, null, errorCode, errorMessage);
    }

    private static void complete(
        final String requestId,
        final boolean success,
        final String payloadJson,
        final String errorCode,
        final String errorMessage) {
        final CFUnityCallback currentCallback;
        synchronized (LOCK) {
            currentCallback = callback;
        }
        if (currentCallback == null) {
            return;
        }
        MAIN_HANDLER.post(new Runnable() {
            @Override
            public void run() {
                try {
                    currentCallback.onResult(
                        requestId == null ? "" : requestId,
                        success,
                        payloadJson,
                        errorCode,
                        errorMessage);
                } catch (Throwable error) {
                    Log.e(LOG_TAG, "Managed result callback failed", error);
                }
            }
        });
    }

    private static String messageFor(Throwable error) {
        String message = error == null ? null : error.getMessage();
        return isBlank(message)
            ? (error == null ? "Unknown native error." : error.getClass().getSimpleName())
            : message;
    }

    private static boolean isBlank(String value) {
        return value == null || value.trim().length() == 0;
    }
}
