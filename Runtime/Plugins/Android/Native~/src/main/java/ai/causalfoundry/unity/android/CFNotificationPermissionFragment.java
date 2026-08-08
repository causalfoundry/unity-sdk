package ai.causalfoundry.unity.android;

import android.app.Activity;
import android.app.Fragment;
import android.app.FragmentManager;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import java.util.ArrayList;
import java.util.List;

/**
 * Headless platform Fragment that owns the Android runtime-permission callback without requiring
 * the host game to subclass Unity's Activity. Platform Fragment is used deliberately so the facade
 * remains compatible with Unity 2021.3 and Android API 21 hosts.
 */
public final class CFNotificationPermissionFragment extends Fragment {
    private static final String FRAGMENT_TAG =
        "ai.causalfoundry.unity.android.NotificationPermission";
    // Keep the literal so loading this API-21-compatible facade never resolves an API-33 field.
    private static final String PERMISSION = "android.permission.POST_NOTIFICATIONS";
    private static final int REQUEST_CODE = 0xCF01;
    private static final String AUTHORIZED_PAYLOAD = "{\"status\":\"authorized\"}";
    private static final String DENIED_PAYLOAD = "{\"status\":\"denied\"}";
    private static final String NOT_REQUIRED_PAYLOAD = "{\"status\":\"not_required\"}";
    private static final String ERROR_CODE = "notification_permission_error";
    private static final Handler MAIN_HANDLER = new Handler(Looper.getMainLooper());

    private final List<PendingRequest> pendingRequests = new ArrayList<PendingRequest>();
    private boolean requestInFlight;

    /** Required public constructor for FragmentManager state restoration. */
    public CFNotificationPermissionFragment() {
    }

    static void request(
        final Activity activity,
        String requestId,
        final CFUnityCallback callback) {
        if (callback == null) {
            return;
        }

        final String normalizedRequestId = requestId == null ? "" : requestId;
        if (activity == null) {
            deliverFailureOnMain(
                callback,
                normalizedRequestId,
                "UnityPlayer.currentActivity is not available.");
            return;
        }

        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                requestOnMainThread(activity, normalizedRequestId, callback);
            }
        });
    }

    private static void requestOnMainThread(
        Activity activity,
        String requestId,
        CFUnityCallback callback) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            deliverPayload(callback, requestId, NOT_REQUIRED_PAYLOAD);
            return;
        }
        if (activity.checkSelfPermission(PERMISSION) == PackageManager.PERMISSION_GRANTED) {
            deliverStatus(callback, requestId, true);
            return;
        }

        if (activity.isFinishing() || activity.isDestroyed()) {
            deliverFailure(
                callback,
                requestId,
                "The host Activity is finishing or has been destroyed.");
            return;
        }

        CFNotificationPermissionFragment fragment = null;
        try {
            FragmentManager manager = activity.getFragmentManager();
            if (manager.isDestroyed()) {
                deliverFailure(callback, requestId, "The host FragmentManager is destroyed.");
                return;
            }

            Fragment existing = manager.findFragmentByTag(FRAGMENT_TAG);
            if (existing == null) {
                fragment = new CFNotificationPermissionFragment();
                fragment.enqueue(requestId, callback);
                manager.beginTransaction()
                    .add(fragment, FRAGMENT_TAG)
                    // This branch only runs on API 33+, where synchronous commits are available.
                    // Attaching now ensures another request in this frame finds this coordinator
                    // without executing unrelated pending transactions owned by the host game.
                    .commitNowAllowingStateLoss();
            } else if (existing instanceof CFNotificationPermissionFragment) {
                fragment = (CFNotificationPermissionFragment) existing;
                fragment.enqueue(requestId, callback);
            } else {
                deliverFailure(callback, requestId, "The notification permission Fragment tag is in use.");
            }
        } catch (Throwable error) {
            if (fragment == null) {
                deliverFailure(callback, requestId, messageFor(error));
            } else {
                // The request was already enqueued, so drain it through the coordinator to preserve
                // the exactly-once callback contract even if Fragment attachment fails partway.
                fragment.failPending(messageFor(error));
            }
        }
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setRetainInstance(true);
    }

    @Override
    public void onResume() {
        super.onResume();
        requestIfReady();
    }

    @Override
    public void onRequestPermissionsResult(
        int requestCode,
        String[] permissions,
        int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode != REQUEST_CODE) {
            return;
        }

        requestInFlight = false;
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            completePending(NOT_REQUIRED_PAYLOAD);
            return;
        }
        Activity activity = getActivity();
        boolean authorized = activity != null
            && activity.checkSelfPermission(PERMISSION) == PackageManager.PERMISSION_GRANTED;
        completePending(authorized);
    }

    @Override
    public void onDestroy() {
        Activity activity = getActivity();
        boolean changingConfiguration = activity != null && activity.isChangingConfigurations();
        if (!changingConfiguration && !pendingRequests.isEmpty()) {
            failPending("The host Activity was destroyed before permission was resolved.");
        }
        super.onDestroy();
    }

    private void enqueue(String requestId, CFUnityCallback callback) {
        pendingRequests.add(new PendingRequest(requestId, callback));
        requestIfReady();
    }

    private void requestIfReady() {
        if (requestInFlight || pendingRequests.isEmpty() || !isAdded() || !isResumed()) {
            return;
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            completePending(NOT_REQUIRED_PAYLOAD);
            return;
        }

        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        if (activity.checkSelfPermission(PERMISSION) == PackageManager.PERMISSION_GRANTED) {
            completePending(true);
            return;
        }

        try {
            requestInFlight = true;
            requestPermissions(new String[] { PERMISSION }, REQUEST_CODE);
        } catch (Throwable error) {
            requestInFlight = false;
            failPending(messageFor(error));
        }
    }

    private void completePending(boolean authorized) {
        completePending(authorized ? AUTHORIZED_PAYLOAD : DENIED_PAYLOAD);
    }

    private void completePending(String payload) {
        List<PendingRequest> completed = drainPending();
        for (PendingRequest request : completed) {
            deliverPayload(request.callback, request.requestId, payload);
        }

        // A Unity callback may synchronously queue another request. Start it after the original
        // completion batch so reentrant calls cannot be lost.
        requestIfReady();
    }

    private void failPending(String message) {
        List<PendingRequest> completed = drainPending();
        for (PendingRequest request : completed) {
            deliverFailure(request.callback, request.requestId, message);
        }
        requestIfReady();
    }

    private List<PendingRequest> drainPending() {
        List<PendingRequest> completed = new ArrayList<PendingRequest>(pendingRequests);
        pendingRequests.clear();
        return completed;
    }

    private static void deliverStatus(
        CFUnityCallback callback,
        String requestId,
        boolean authorized) {
        deliverPayload(callback, requestId, authorized ? AUTHORIZED_PAYLOAD : DENIED_PAYLOAD);
    }

    private static void deliverPayload(
        CFUnityCallback callback,
        String requestId,
        String payload) {
        try {
            callback.onResult(
                requestId,
                true,
                payload,
                null,
                null);
        } catch (Throwable ignored) {
            // One disconnected Unity proxy must not prevent other queued callers from completing.
        }
    }

    private static void deliverFailure(
        CFUnityCallback callback,
        String requestId,
        String message) {
        try {
            callback.onResult(requestId, false, null, ERROR_CODE, message);
        } catch (Throwable ignored) {
            // The managed callback may already have been released during application shutdown.
        }
    }

    private static void deliverFailureOnMain(
        final CFUnityCallback callback,
        final String requestId,
        final String message) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            deliverFailure(callback, requestId, message);
            return;
        }
        MAIN_HANDLER.post(new Runnable() {
            @Override
            public void run() {
                deliverFailure(callback, requestId, message);
            }
        });
    }

    private static String messageFor(Throwable error) {
        if (error == null || error.getMessage() == null || error.getMessage().length() == 0) {
            return "Unable to request notification permission.";
        }
        return error.getMessage();
    }

    private static final class PendingRequest {
        final String requestId;
        final CFUnityCallback callback;

        PendingRequest(String requestId, CFUnityCallback callback) {
            this.requestId = requestId;
            this.callback = callback;
        }
    }
}
