#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GRADLE_COMMAND=${GRADLE_COMMAND:-gradle}

if [ -n "${JAVA_HOME:-}" ]; then
    BUILD_JAVA="$JAVA_HOME/bin/java"
else
    BUILD_JAVA=$(command -v java || true)
fi

if [ ! -x "$BUILD_JAVA" ]; then
    echo "A JDK 17 java executable is required to build the Android facade AAR." >&2
    exit 1
fi

BUILD_JAVA_MAJOR=$("$BUILD_JAVA" -version 2>&1 | sed -n '1s/.*version "\([0-9][0-9]*\).*/\1/p')
if [ "$BUILD_JAVA_MAJOR" != "17" ]; then
    echo "The Android facade AAR must be built with JDK 17; found Java ${BUILD_JAVA_MAJOR:-unknown}." >&2
    echo "Newer javac releases emit bridge metadata that crashes the D8 version in Unity 2021." >&2
    exit 1
fi

cd "$SCRIPT_DIR"
"$GRADLE_COMMAND" --no-daemon clean assembleRelease

OUTPUT=$(find "$SCRIPT_DIR/build/outputs/aar" -maxdepth 1 -name '*-release.aar' -print | head -n 1)
if [ -z "$OUTPUT" ]; then
    echo "Release AAR was not produced." >&2
    exit 1
fi

cp "$OUTPUT" "$SCRIPT_DIR/../causalfoundry-unity-android.aar"
echo "Wrote $SCRIPT_DIR/../causalfoundry-unity-android.aar"
