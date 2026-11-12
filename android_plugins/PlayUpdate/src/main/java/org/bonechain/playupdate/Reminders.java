package org.bonechain.playupdate;

import android.app.AlarmManager;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Bone Chain's phone reminders (version 143). The game hands over a short list of
 * reminders ({id, at (unix seconds), title, text}); each one becomes an inexact alarm that
 * posts one notification. The list is also kept in the app's preferences so that a phone
 * restart (which clears alarms) can put them back (see BootReceiver). Nothing here runs
 * unless the player turned reminders on in the game.
 */
public final class Reminders {
    static final String PREFS = "bonechain_reminders";
    static final String KEY = "list";
    static final String CHANNEL = "reminders";
    private static final int MAX = 16;

    private Reminders() {}

    /** Replaces every reminder with the ones in `json` (an array). An empty array clears them. */
    static void schedule(Context context, String json) {
        cancelAll(context);
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply();
        arm(context, json);
    }

    static void cancelAll(Context context) {
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        for (int id = 1; id <= MAX; id++) {
            PendingIntent pi = pending(context, id, null, null, PendingIntent.FLAG_NO_CREATE);
            if (pi != null) {
                if (alarms != null) {
                    alarms.cancel(pi);
                }
                pi.cancel();
            }
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply();
    }

    /** Arms the alarms in `json` that are still in the future. */
    static void arm(Context context, String json) {
        AlarmManager alarms = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
        if (alarms == null || json == null) {
            return;
        }
        long now = System.currentTimeMillis();
        try {
            JSONArray list = new JSONArray(json);
            for (int i = 0; i < list.length() && i < MAX; i++) {
                JSONObject r = list.getJSONObject(i);
                int id = r.optInt("id", i + 1);
                long at = r.optLong("at", 0) * 1000L;
                if (id < 1 || id > MAX || at <= now) {
                    continue;
                }
                PendingIntent pi = pending(context, id, r.optString("title", "Bone Chain"), r.optString("text", ""),
                        PendingIntent.FLAG_UPDATE_CURRENT);
                // Inexact on purpose: no special alarm permission, and a few minutes either way is fine.
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi);
            }
        } catch (Throwable ignored) {
            // A bad list never stops the game.
        }
    }

    private static PendingIntent pending(Context context, int id, String title, String text, int flags) {
        Intent intent = new Intent(context, ReminderReceiver.class);
        intent.setAction("org.bonechain.REMINDER_" + id);
        if (title != null) {
            intent.putExtra("id", id);
            intent.putExtra("title", title);
            intent.putExtra("text", text);
        }
        return PendingIntent.getBroadcast(context, id, intent, flags | PendingIntent.FLAG_IMMUTABLE);
    }

    static void ensureChannel(Context context) {
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null && nm.getNotificationChannel(CHANNEL) == null) {
                NotificationChannel ch = new NotificationChannel(CHANNEL, "Reminders", NotificationManager.IMPORTANCE_DEFAULT);
                ch.setDescription("The Daily Crypt, events and your streak. At most one a day.");
                nm.createNotificationChannel(ch);
            }
        }
    }

    /** Posts one reminder now. */
    static void post(Context context, int id, String title, String text) {
        NotificationManager nm = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
        if (nm == null) {
            return;
        }
        if (Build.VERSION.SDK_INT >= 24 && !nm.areNotificationsEnabled()) {
            return;
        }
        ensureChannel(context);
        Intent open = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        PendingIntent tap = null;
        if (open != null) {
            open.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            tap = PendingIntent.getActivity(context, 100 + id, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        }
        android.app.Notification.Builder b = Build.VERSION.SDK_INT >= 26
                ? new android.app.Notification.Builder(context, CHANNEL)
                : new android.app.Notification.Builder(context);
        b.setSmallIcon(R.drawable.bonechain_notify)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(new android.app.Notification.BigTextStyle().bigText(text))
                .setAutoCancel(true)
                .setColor(0xFFE8B24A);
        if (tap != null) {
            b.setContentIntent(tap);
        }
        // One at a time: a new reminder replaces an old one still in the shade.
        nm.notify(7100, b.build());
    }

    /** The alarm went off: show the reminder. */
    public static class ReminderReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            try {
                post(context, intent.getIntExtra("id", 1), intent.getStringExtra("title"), intent.getStringExtra("text"));
            } catch (Throwable ignored) {
            }
        }
    }

    /** The phone restarted, which clears alarms: put the saved ones back. */
    public static class BootReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            try {
                SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
                arm(context, prefs.getString(KEY, null));
            } catch (Throwable ignored) {
            }
        }
    }
}
