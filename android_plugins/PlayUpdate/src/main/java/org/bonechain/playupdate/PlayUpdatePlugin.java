package org.bonechain.playupdate;

import android.app.Activity;

import com.google.android.play.core.appupdate.AppUpdateInfo;
import com.google.android.play.core.appupdate.AppUpdateManager;
import com.google.android.play.core.appupdate.AppUpdateManagerFactory;
import com.google.android.play.core.appupdate.AppUpdateOptions;
import com.google.android.play.core.install.model.AppUpdateType;
import com.google.android.play.core.install.model.UpdateAvailability;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;

/**
 * Asks Google Play whether a newer version of the game is out and opens Google's
 * full-screen update page (an "immediate" in-app update). Used by scripts/play_update.gd.
 *
 * Signals:
 *  - update_checked(state, detail, version, staleDays): state 1 = an update is out, 2 = an
 *    update was already started (resume it), 0 = none, -1 = Play couldn't be asked (not
 *    installed from Play, offline, ...). detail is a short description for the log, version
 *    the update's version code (0 if none) and staleDays how many days ago Play on this phone
 *    learned of the update (-1 if Play doesn't say). The game lets an update wait a few days.
 *  - update_finished(result): what came back from Google's page. -1 = accepted (Play installs
 *    it and restarts the game), 0 = backed out, 1 = failed, 2 = no update to start any more.
 *
 * Every call is wrapped so that a problem here never stops the game from starting.
 */
public class PlayUpdatePlugin extends GodotPlugin {
    private AppUpdateManager manager;

    public PlayUpdatePlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "PlayUpdate";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("update_checked", Integer.class, String.class, Integer.class, Integer.class));
        signals.add(new SignalInfo("update_finished", Integer.class));
        return signals;
    }

    private static int stateOf(AppUpdateInfo info) {
        int availability = info.updateAvailability();
        if (availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) {
            return 2;
        }
        if (availability == UpdateAvailability.UPDATE_AVAILABLE && info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
            return 1;
        }
        return 0;
    }

    private static int staleDays(AppUpdateInfo info) {
        Integer days = info.clientVersionStalenessDays();
        return days == null ? -1 : days;
    }

    private AppUpdateManager manager(Activity activity) {
        if (manager == null) {
            manager = AppUpdateManagerFactory.create(activity.getApplicationContext());
        }
        return manager;
    }

    @UsedByGodot
    public void check() {
        final Activity activity = getActivity();
        if (activity == null) {
            emitSignal("update_checked", -1, "no activity", 0, -1);
            return;
        }
        activity.runOnUiThread(() -> {
            try {
                manager(activity).getAppUpdateInfo()
                        .addOnSuccessListener(info -> emitSignal("update_checked", stateOf(info),
                                "availability " + info.updateAvailability(), info.availableVersionCode(), staleDays(info)))
                        .addOnFailureListener(e -> emitSignal("update_checked", -1, String.valueOf(e), 0, -1));
            } catch (Throwable t) {
                emitSignal("update_checked", -1, String.valueOf(t), 0, -1);
            }
        });
    }

    /** Opens Google's update page. An AppUpdateInfo works for one flow only, so ask again first. */
    @UsedByGodot
    public void start() {
        final Activity activity = getActivity();
        if (activity == null) {
            emitSignal("update_finished", 1);
            return;
        }
        activity.runOnUiThread(() -> {
            try {
                manager(activity).getAppUpdateInfo()
                        .addOnSuccessListener(info -> {
                            if (stateOf(info) == 0) {
                                emitSignal("update_finished", 2);
                                return;
                            }
                            try {
                                manager(activity).startUpdateFlow(info, activity,
                                                AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE))
                                        .addOnSuccessListener(result -> emitSignal("update_finished", result == null ? 1 : result))
                                        .addOnFailureListener(e -> emitSignal("update_finished", 1));
                            } catch (Throwable t) {
                                emitSignal("update_finished", 1);
                            }
                        })
                        .addOnFailureListener(e -> emitSignal("update_finished", 1));
            } catch (Throwable t) {
                emitSignal("update_finished", 1);
            }
        });
    }
}
