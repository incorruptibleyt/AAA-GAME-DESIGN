package org.bonechain.playgames;

import android.app.Activity;
import android.content.Intent;
import android.view.View;

import com.google.android.gms.common.api.ResolvableApiException;
import com.google.android.gms.games.AnnotatedData;
import com.google.android.gms.games.LeaderboardsClient;
import com.google.android.gms.games.PlayGames;
import com.google.android.gms.games.PlayGamesSdk;
import com.google.android.gms.games.Player;
import com.google.android.gms.games.leaderboard.LeaderboardScore;
import com.google.android.gms.games.leaderboard.LeaderboardScoreBuffer;
import com.google.android.gms.tasks.Task;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONArray;
import org.json.JSONObject;

import java.util.HashSet;
import java.util.Set;

/**
 * Google Play Games Services for Bone Chain's leaderboards. Used by scripts/leaders.gd.
 *
 * Signals:
 *  - signed_in(ok, name, detail): ok 1 = signed in to Play Games as `name`, 0 = not.
 *  - scores_loaded(tag, json, error): the scores asked for with load(). json is a list of
 *    {rank, name, score, me}; error is "" when it worked, "friends" when the player hasn't let
 *    the game see their friends yet, or a short description for the log.
 *  - friends_access(state): 1 = the game may see the player's friends, 0 = not, 2 = Google's
 *    "share your friends" page was opened (the answer comes as another friends_access).
 *  - board_closed(): Google's own leaderboard page was closed.
 *
 * Every call is wrapped so that a problem here never stops the game.
 */
public class PlayGamesPlugin extends GodotPlugin {
    private static final int RC_BOARD = 9004;
    private static final int RC_FRIENDS = 9005;
    private boolean ready = false;
    private String playerId = "";

    public PlayGamesPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "PlayGames";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(new SignalInfo("signed_in", Integer.class, String.class, String.class));
        signals.add(new SignalInfo("scores_loaded", String.class, String.class, String.class));
        signals.add(new SignalInfo("friends_access", Integer.class));
        signals.add(new SignalInfo("board_closed"));
        return signals;
    }

    @Override
    public View onMainCreate(Activity activity) {
        try {
            PlayGamesSdk.initialize(activity.getApplicationContext());
            ready = true;
        } catch (Throwable t) {
            ready = false;
        }
        return null;
    }

    @Override
    public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == RC_BOARD) {
            emitSignal("board_closed");
        } else if (requestCode == RC_FRIENDS) {
            emitSignal("friends_access", resultCode == Activity.RESULT_OK ? 1 : 0);
        }
    }

    /** True when Play Games started on this phone. */
    @UsedByGodot
    public boolean is_ready() {
        return ready;
    }

    /** Asks whether the player is signed in (Play Games signs them in by itself at launch). */
    @UsedByGodot
    public void check() {
        final Activity a = getActivity();
        if (!ready || a == null) {
            emitSignal("signed_in", 0, "", "not ready");
            return;
        }
        a.runOnUiThread(() -> {
            try {
                PlayGames.getGamesSignInClient(a).isAuthenticated()
                        .addOnCompleteListener(task -> signedIn(a, task.isSuccessful() && task.getResult().isAuthenticated(),
                                task.isSuccessful() ? "not signed in" : String.valueOf(task.getException())));
            } catch (Throwable t) {
                emitSignal("signed_in", 0, "", String.valueOf(t));
            }
        });
    }

    /** Opens Google's sign-in (the player tapped SIGN IN). */
    @UsedByGodot
    public void sign_in() {
        final Activity a = getActivity();
        if (!ready || a == null) {
            emitSignal("signed_in", 0, "", "not ready");
            return;
        }
        a.runOnUiThread(() -> {
            try {
                PlayGames.getGamesSignInClient(a).signIn()
                        .addOnCompleteListener(task -> signedIn(a, task.isSuccessful() && task.getResult().isAuthenticated(),
                                task.isSuccessful() ? "declined" : String.valueOf(task.getException())));
            } catch (Throwable t) {
                emitSignal("signed_in", 0, "", String.valueOf(t));
            }
        });
    }

    private void signedIn(Activity a, boolean ok, String detail) {
        if (!ok) {
            emitSignal("signed_in", 0, "", detail);
            return;
        }
        try {
            PlayGames.getPlayersClient(a).getCurrentPlayer()
                    .addOnSuccessListener(p -> {
                        playerId = p == null ? "" : p.getPlayerId();
                        emitSignal("signed_in", 1, p == null ? "" : p.getDisplayName(), "ok");
                    })
                    .addOnFailureListener(e -> emitSignal("signed_in", 1, "", String.valueOf(e)));
        } catch (Throwable t) {
            emitSignal("signed_in", 1, "", String.valueOf(t));
        }
    }

    /** Sends a score. Play Games keeps the best one for each day, week and all time. */
    @UsedByGodot
    public void submit(String board, int score) {
        final Activity a = getActivity();
        if (!ready || a == null) {
            return;
        }
        a.runOnUiThread(() -> {
            try {
                PlayGames.getLeaderboardsClient(a).submitScore(board, (long) score);
            } catch (Throwable ignored) {
            }
        });
    }

    /**
     * Loads scores. span: 0 daily, 1 weekly, 2 all time. collection: 0 everyone, 3 friends.
     * centered: around the player instead of the top.
     */
    @UsedByGodot
    public void load(String tag, String board, int span, int collection, boolean centered, int count) {
        final Activity a = getActivity();
        if (!ready || a == null) {
            emitSignal("scores_loaded", tag, "[]", "not ready");
            return;
        }
        a.runOnUiThread(() -> {
            try {
                LeaderboardsClient lc = PlayGames.getLeaderboardsClient(a);
                Task<AnnotatedData<LeaderboardsClient.LeaderboardScores>> task = centered
                        ? lc.loadPlayerCenteredScores(board, span, collection, count, true)
                        : lc.loadTopScores(board, span, collection, count, true);
                task.addOnSuccessListener(data -> emitSignal("scores_loaded", tag, toJson(data), ""))
                        .addOnFailureListener(e -> emitSignal("scores_loaded", tag, "[]",
                                e instanceof ResolvableApiException && collection == 3 ? "friends" : String.valueOf(e)));
            } catch (Throwable t) {
                emitSignal("scores_loaded", tag, "[]", String.valueOf(t));
            }
        });
    }

    private String toJson(AnnotatedData<LeaderboardsClient.LeaderboardScores> data) {
        JSONArray out = new JSONArray();
        LeaderboardsClient.LeaderboardScores scores = data == null ? null : data.get();
        if (scores == null) {
            return out.toString();
        }
        LeaderboardScoreBuffer buf = scores.getScores();
        try {
            for (LeaderboardScore s : buf) {
                JSONObject o = new JSONObject();
                Player holder = s.getScoreHolder();
                o.put("rank", s.getRank());
                o.put("name", s.getScoreHolderDisplayName());
                o.put("score", s.getRawScore());
                o.put("me", holder != null && !playerId.isEmpty() && playerId.equals(holder.getPlayerId()));
                out.put(o);
            }
        } catch (Throwable ignored) {
        } finally {
            buf.release();
            scores.release();
        }
        return out.toString();
    }

    /** Asks to see the player's Play Games friends (Google shows its own "share" page if needed). */
    @UsedByGodot
    public void ask_friends() {
        final Activity a = getActivity();
        if (!ready || a == null) {
            emitSignal("friends_access", 0);
            return;
        }
        a.runOnUiThread(() -> {
            try {
                PlayGames.getPlayersClient(a).loadFriends(10, false)
                        .addOnSuccessListener(d -> emitSignal("friends_access", 1))
                        .addOnFailureListener(e -> {
                            if (e instanceof ResolvableApiException) {
                                try {
                                    ((ResolvableApiException) e).startResolutionForResult(a, RC_FRIENDS);
                                    emitSignal("friends_access", 2);
                                    return;
                                } catch (Throwable ignored) {
                                }
                            }
                            emitSignal("friends_access", 0);
                        });
            } catch (Throwable t) {
                emitSignal("friends_access", 0);
            }
        });
    }

    /** Opens Google's own leaderboard page (span and collection as in load()). */
    @UsedByGodot
    public void show_board(String board, int span, int collection) {
        final Activity a = getActivity();
        if (!ready || a == null) {
            emitSignal("board_closed");
            return;
        }
        a.runOnUiThread(() -> {
            try {
                PlayGames.getLeaderboardsClient(a).getLeaderboardIntent(board, span, collection)
                        .addOnSuccessListener(intent -> a.startActivityForResult(intent, RC_BOARD))
                        .addOnFailureListener(e -> emitSignal("board_closed"));
            } catch (Throwable t) {
                emitSignal("board_closed");
            }
        });
    }
}
