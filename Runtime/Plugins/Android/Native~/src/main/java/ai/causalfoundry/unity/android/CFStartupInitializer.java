package ai.causalfoundry.unity.android;

import android.app.Application;
import android.content.Context;

import androidx.annotation.NonNull;
import androidx.lifecycle.ProcessLifecycleInitializer;
import androidx.startup.Initializer;

import java.util.Collections;
import java.util.List;

/**
 * Starts before the first Activity so the Core SDK observes the real first process lifecycle.
 * ProcessLifecycleInitializer is an explicit dependency to make ordering deterministic.
 */
public final class CFStartupInitializer implements Initializer<Boolean> {
    @NonNull
    @Override
    public Boolean create(@NonNull Context context) {
        Context applicationContext = context.getApplicationContext();
        if (applicationContext instanceof Application) {
            CFNativeState.startup((Application) applicationContext);
        }
        return Boolean.TRUE;
    }

    @NonNull
    @Override
    public List<Class<? extends Initializer<?>>> dependencies() {
        return Collections.<Class<? extends Initializer<?>>>singletonList(
            ProcessLifecycleInitializer.class);
    }
}
