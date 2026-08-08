# Unity reaches the facade by its Java class name and implements this callback through JNI.
-keep class ai.causalfoundry.unity.android.CFUnityBridge { public *; }
-keep class ai.causalfoundry.unity.android.CFStartupInitializer { public *; }
-keep class ai.causalfoundry.unity.android.CFNotificationPermissionFragment { *; }
-keep interface ai.causalfoundry.unity.android.CFUnityCallback { *; }

# The native Core SDK discovers and invokes this callback object from notification receivers.
-keep class io.kenkai.android.sdk.core.action.interfaces.ActionOnClickObject { *; }
-keep interface io.kenkai.android.sdk.core.action.interfaces.ActionOnClickInterface { *; }
