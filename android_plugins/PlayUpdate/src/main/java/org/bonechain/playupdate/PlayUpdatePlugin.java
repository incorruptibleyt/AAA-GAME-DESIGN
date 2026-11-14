package org.bonechain.playupdate;

import android.app.Activity;

import com.google.android.play.core.appupdate.AppUpdateInfo;
import com.google.android.play.core.appupdate.AppUpdateManager;
import com.google.android.play.core.appupdate.AppUpdateManagerFactory;
import com.google.android.play.core.appupdate.AppUpdateOptions;
import com.google.android.play.core.install.model.AppUpdateType;
import com.google.android.play.core.install.model.UpdateAvailability;
import com.google.android.play.core.review.ReviewManager;
import com.google.android.play.core.review.ReviewManagerFactory;

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
 *  - review_finished(ok, detail): Google's in-app rating card was asked for (review()).
 *    ok = 1 when the flow finished (Google never says whether the card showed or what was
 *    rated), 0 when it couldn't start. detail is for the log.
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
        signals.add(new SignalInfo("review_finished", Integer.class, String.class));
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

    /** Shows Google Play's in-app rating card (Google decides whether it actually appears). */
    @UsedByGodot
    public void review() {
        final Activity activity = getActivity();
        if (activity == null) {
            emitSignal("review_finished", 0, "no activity");
            return;
        }
        activity.runOnUiThread(() -> {
            try {
                final ReviewManager reviews = ReviewManagerFactory.create(activity.getApplicationContext());
                reviews.requestReviewFlow()
                        .addOnSuccessListener(info -> {
                            try {
                                reviews.launchReviewFlow(activity, info)
                                        .addOnCompleteListener(done -> emitSignal("review_finished", 1, "done"))
                                        .addOnFailureListener(e -> emitSignal("review_finished", 0, String.valueOf(e)));
                            } catch (Throwable t) {
                                emitSignal("review_finished", 0, String.valueOf(t));
                            }
                        })
                        .addOnFailureListener(e -> emitSignal("review_finished", 0, String.valueOf(e)));
            } catch (Throwable t) {
                emitSignal("review_finished", 0, String.valueOf(t));
            }
        });
    }

    // ------------------------------------------------------------- reminders (version 143)

    /** Replaces the game's phone reminders with the list in `json` (see Reminders). */
    @UsedByGodot
    public void remindersSchedule(String json) {
        final Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        try {
            Reminders.ensureChannel(activity.getApplicationContext());
            Reminders.schedule(activity.getApplicationContext(), json);
        } catch (Throwable ignored) {
        }
    }

    /** Clears every phone reminder (the player turned them off). */
    @UsedByGodot
    public void remindersClear() {
        final Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        try {
            Reminders.cancelAll(activity.getApplicationContext());
        } catch (Throwable ignored) {
        }
    }

    /** Whether this phone lets the game show notifications at all (the Android setting). */
    @UsedByGodot
    public boolean remindersAllowed() {
        final Activity activity = getActivity();
        if (activity == null) {
            return false;
        }
        try {
            android.app.NotificationManager nm = (android.app.NotificationManager)
                    activity.getSystemService(android.content.Context.NOTIFICATION_SERVICE);
            return nm != null && (android.os.Build.VERSION.SDK_INT < 24 || nm.areNotificationsEnabled());
        } catch (Throwable t) {
            return false;
        }
    }

    /** Shows a reminder now, for the robot and for testing on a phone. */
    @UsedByGodot
    public void remindersTest(String title, String text) {
        final Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        try {
            Reminders.post(activity.getApplicationContext(), 1, title, text);
        } catch (Throwable ignored) {
        }
    }
}
