package ai.emie.app.b3probe;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;

/** Android framework instrumentation of the actual installed Kotlin helper. */
public final class B3RecoveryInstrumentation extends Instrumentation {
    private final ArrayList<String> passed = new ArrayList<>();
    private Throwable failure;
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }
    private void verify(String id, Intent intent, boolean consumes, String expected) throws Exception {
        Class<?> type = Class.forName("ai.emie.app.MainActivity", true, getTargetContext().getClassLoader());
        Object activity = type.getDeclaredConstructor().newInstance();
        Method take = type.getDeclaredMethod("takeRecovery", Intent.class); take.setAccessible(true);
        Field pending = type.getDeclaredField("pending"); pending.setAccessible(true);
        Uri before = intent == null ? null : intent.getData();
        take.invoke(activity, intent);
        Object actual = pending.get(activity);
        if (!(expected == null ? actual == null : expected.equals(actual))) throw new AssertionError(id + ": pending mismatch");
        Uri after = intent == null ? null : intent.getData();
        if (consumes ? after != null : !(before == null ? after == null : before.equals(after))) throw new AssertionError(id + ": data mismatch");
        passed.add(id);
    }
    private void tests() throws Exception {
        String valid = "http://10.0.2.2:8010/reset-password?token=synthetic_native_proof_12345";
        String invalid = "https://untrusted.example/reset-password?token=synthetic_native_proof_12345&extra=1";
        verify("recovery_view_consumed", new Intent(Intent.ACTION_VIEW, Uri.parse(valid)), true, valid);
        verify("invalid_recovery_view_sanitized_for_dart_rejection", new Intent(Intent.ACTION_VIEW, Uri.parse(invalid)), true, invalid);
        verify("other_view_preserves_data", new Intent(Intent.ACTION_VIEW, Uri.parse("https://plugin.example/other?code=synthetic")), false, null);
        verify("non_view_preserves_reset_data", new Intent(Intent.ACTION_SEND, Uri.parse(valid)), false, null);
        verify("null_intent_is_untouched", null, false, null);
        verify("oversized_recovery_is_neutral_and_sanitized", new Intent(Intent.ACTION_VIEW, Uri.parse(valid + "x".repeat(5000))), true, "/reset-password");
    }
    @Override public void onStart() {
        runOnMainSync(() -> { try { tests(); } catch (Throwable error) { failure = error; } });
        Bundle results = new Bundle();
        results.putStringArrayList("passed_test_ids", passed);
        results.putInt("passed_count", passed.size());
        results.putString("failure_type", failure == null ? "none" : failure.getClass().getName());
        finish(failure == null ? Activity.RESULT_OK : Activity.RESULT_CANCELED, results);
    }
}
