#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
AAR="$SCRIPT_DIR/../causalfoundry-unity-android.aar"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

if [ ! -f "$AAR" ]; then
    echo "Missing $AAR. Run build.sh first." >&2
    exit 1
fi

unzip -q "$AAR" -d "$TEMP_DIR"

grep -q 'android.permission.INTERNET' "$TEMP_DIR/AndroidManifest.xml"
grep -q 'android.permission.POST_NOTIFICATIONS' "$TEMP_DIR/AndroidManifest.xml"
grep -q 'CFStartupInitializer' "$TEMP_DIR/AndroidManifest.xml"
grep -q 'minCompileSdk=33' "$TEMP_DIR/META-INF/com/android/build/gradle/aar-metadata.properties"
grep -q 'CFUnityBridge' "$TEMP_DIR/proguard.txt"

javap -classpath "$TEMP_DIR/classes.jar" -public \
    ai.causalfoundry.unity.android.CFUnityBridge \
    ai.causalfoundry.unity.android.CFUnityCallback \
    ai.causalfoundry.unity.android.CFNotificationPermissionFragment \
    ai.causalfoundry.unity.android.CFStartupInitializer

if jar tf "$TEMP_DIR/classes.jar" \
    | grep -Eq 'CausalFoundry(UnityBridge|UnityCallback|StartupInitializer|NativeState|NotificationPermissionFragment)'; then
    echo "AAR still contains a pre-CF Java bridge class." >&2
    exit 1
fi

if jar tf "$TEMP_DIR/classes.jar" \
    | grep -q 'CausalFoundryInAppMessageInsetsLayout'; then
    echo "AAR still contains the removed Unity in-app inset workaround." >&2
    exit 1
fi

javap -classpath "$TEMP_DIR/classes.jar" -public \
    ai.causalfoundry.unity.android.CFUnityBridge \
    | grep -q 'logUserCatalog(java.lang.String, java.lang.String, java.lang.String)'

javap -classpath "$TEMP_DIR/classes.jar" -public \
    ai.causalfoundry.unity.android.CFUnityBridge \
    | grep -q 'logOtherCatalog(java.lang.String, java.lang.String, java.lang.String)'

javap -classpath "$TEMP_DIR/classes.jar" -c -private \
    ai.causalfoundry.unity.android.CFNativeState \
    | grep -q 'OtherCatalogModel'

javap -classpath "$TEMP_DIR/classes.jar" -c -private \
    ai.causalfoundry.unity.android.CFNativeState \
    | grep -q 'CoreCatalogType.Other'

javap -classpath "$TEMP_DIR/classes.jar" -verbose -private \
    ai.causalfoundry.unity.android.CFNativeState \
    | grep -q 'invalid_other_catalog'

javap -classpath "$TEMP_DIR/classes.jar" -verbose -private \
    ai.causalfoundry.unity.android.CFNativeState \
    | grep -q 'native_other_catalog_failed'

javap -classpath "$TEMP_DIR/classes.jar" -public \
    ai.causalfoundry.unity.android.CFUnityBridge \
    | grep -q 'setPaused(java.lang.String, boolean)'

javap -classpath "$TEMP_DIR/classes.jar" -public \
    ai.causalfoundry.unity.android.CFUnityBridge \
    | grep -q 'requestNotificationPermission(android.app.Activity, java.lang.String, ai.causalfoundry.unity.android.CFUnityCallback)'

javap -classpath "$TEMP_DIR/classes.jar" -c -private \
    ai.causalfoundry.unity.android.CFNotificationPermissionFragment \
    | grep -q 'requestPermissions'

javap -classpath "$TEMP_DIR/classes.jar" -verbose \
    ai.causalfoundry.unity.android.CFUnityBridge \
    | grep -q 'major version: 52'

javap -classpath "$TEMP_DIR/classes.jar" -verbose \
    ai.causalfoundry.unity.android.CFNotificationPermissionFragment \
    | grep -q 'major version: 52'

javap -classpath "$TEMP_DIR/classes.jar" -verbose \
    ai.causalfoundry.unity.android.CFNativeState \
    | grep -q 'major version: 52'

# JDK 21+ emits an unnamed MethodParameters entry on this synthetic Kotlin Function1 bridge.
# D8 4.0.52, bundled with Unity 2021.3, crashes while reading that otherwise legal metadata.
if javap -classpath "$TEMP_DIR/classes.jar" -verbose \
    'ai.causalfoundry.unity.android.CFNativeState$5' \
    | grep -q 'MethodParameters:'; then
    echo "AAR contains bridge metadata incompatible with Unity 2021 D8; rebuild with JDK 17." >&2
    exit 1
fi

javap -classpath "$TEMP_DIR/classes.jar" -verbose \
    ai.causalfoundry.unity.android.CFNotificationPermissionFragment \
    | grep -Fq '{\"status\":\"authorized\"}'

javap -classpath "$TEMP_DIR/classes.jar" -verbose \
    ai.causalfoundry.unity.android.CFNotificationPermissionFragment \
    | grep -Fq '{\"status\":\"denied\"}'

javap -classpath "$TEMP_DIR/classes.jar" -verbose \
    ai.causalfoundry.unity.android.CFNotificationPermissionFragment \
    | grep -Fq '{\"status\":\"not_required\"}'

javap -classpath "$TEMP_DIR/classes.jar" -c -private \
    ai.causalfoundry.unity.android.CFNativeState \
    | grep -q 'putstatic.*runtimePauseOverride'

javap -classpath "$TEMP_DIR/classes.jar" -c -private \
    ai.causalfoundry.unity.android.CFNativeState \
    | grep -q 'getstatic.*runtimePauseOverride'

if javap -classpath "$TEMP_DIR/classes.jar" -private \
    ai.causalfoundry.unity.android.CFNativeState \
    | grep -q 'ensureCoreNotificationChannel'; then
    echo "AAR still contains the removed Unity notification-channel workaround." >&2
    exit 1
fi

echo "Android facade AAR verification passed."
