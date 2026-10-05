# Mac iOS / PostgreSQL acceptance

This workflow uses the active Mac repositories only:

- Backend: `/Users/emiso/Documents/ChatGPT/Emiso Backend`, baseline `d32d7a3cb79cb30c7d675cfefa80fb6f8a7d0f4e`.
- Flutter: `/Users/emiso/Documents/ChatGPT/Emie Flutter`, baseline `2311e5a6e532980a622695d6c29bf2971655182c`.

No production DB, production app start, provider account, Windows launcher, migration change, commit or push is part of this workflow.

## Tools and owned data

Use the verified CPython 3.11.9 arm64 environment at `/Users/emiso/Emie-Recovery/toolchains/r3c-20260927T223712Z-9f6a/venv/bin/python` and its `lib/python3.11/site-packages`. The B2 runner explicitly checks every pinned requirement and permits only that external package root. It still requires `-I -S -B` and the protected target/PID/datadir/durability guards.

PostgreSQL 17.11 binaries are alongside the environment under `Postgres.app/Contents/Versions/17/bin`. The export's `tools/provision_pg.py` records actual process/listener identity before connecting and creates a new private `/private/tmp/emiso-confirm-pg-*` root. It never reuses an old cluster. Read its export-state input before a future authorized run; do not blindly repeat today's setup. There is no global service.

Today's fixture and its synthetic credentials remain private and outside the review ZIP. `/private/tmp` is not a durable backup. Durable source, sanitized logs, manifests, patches and tool identities are in the export. A future acceptance run should create a fresh owned fixture; UI `setup` explicitly refuses an existing `ui-target.json`.

The test role has no superuser, CREATEDB or CREATEROLE. It owns its synthetic databases and can perform schema DDL there. `pg_read_all_settings` permits the mandatory live datadir check. Provisioning alone uses the new synthetic cluster administrator.

## PG commands

Run from the explicit active backend path, replacing `TESTROOT` with the verified newly created root:

```sh
PY='/Users/emiso/Emie-Recovery/toolchains/r3c-20260927T223712Z-9f6a/venv/bin/python'
SITE='/Users/emiso/Emie-Recovery/toolchains/r3c-20260927T223712Z-9f6a/venv/lib/python3.11/site-packages'
"$PY" -I -S -B app/tests/run_schema_compatibility_b2_postgresql.py TESTROOT --site-packages "$SITE"
```

Save `TESTROOT/storage-postgres-results.json` under a B2-specific evidence name before running the separately selected B1 suite:

```sh
"$PY" -I -S -B app/tests/run_b1_mac_postgresql.py TESTROOT --site-packages "$SITE"
```

Both runners deliberately share the existing report filename. Never sum repeated executions. The B1 suite has six observed database-lock races and one confirmed-commit/discarded-result test; the latter is not HTTP response-loss injection.

The unchanged full migration chain is run only in newly owned schemas or the separate synthetic UI database. The descriptor-aware Mac audit wrapper permits actual owned-root writes and rejects a dir_fd escape. No product guard is disabled.

## Local simulator

Use Flutter 3.38.6 / Dart 3.10.7, installed Xcode and CocoaPods. Dependency resolution is `flutter pub get --enforce-lockfile` and `pod install --deployment`; do not upgrade packages, SDKs or lockfiles. The recorded config-only Flutter preparation also invoked its internal pod install; both lockfiles were byte-for-byte unchanged. All final guarded tests followed dependency preparation.

`mac_local_backend.py setup TESTROOT` creates a separate UI database within the verified owned cluster, applies the existing migration chain, and allocates local SMTP capture. Run it with the same Python `-I -S -B` from the active Flutter repository. The `smtp` and `backend` modes serve only this target on Loopback, without dotenv, real provider keys or header authentication. Start with explicit process records; retain PID/start identity before stopping. The helper's lifetime is bounded by an alarm. Credentials and captured synthetic mail remain under TESTROOT, never in the review export.

The tested backend port was 8010. The app accepts only 8010..8019. Android retains `10.0.2.2`; iOS Local Debug uses `127.0.0.1`. Never pass Android's host to the iOS simulator. If 8010 is occupied, do not contact or kill that listener; the helper refuses to start, and a reviewed explicit alternate port must be passed consistently to all local components.

Prepare the separate local plist:

```sh
python3 tool/beta_b3/ios_build_config.py --local-port 8010 --output OWNED_BUILD/Info-Local.plist
```

Build through the existing workspace/Generated.xcconfig using Debug, `FLUTTER_BUILD_MODE=debug`, and Dart definitions `EMIE_LOCAL=true`, `EMIE_LOCAL_PORT=8010` (Xcode `DART_DEFINES` is the comma-separated base64 encoding of those strings). Pass `INFOPLIST_FILE=OWNED_BUILD/Info-Local.plist` and `SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG EMIE_LOCAL"` only to that build. Use Simulator SDK and local ad-hoc signing (`CODE_SIGN_IDENTITY=-`, `CODE_SIGNING_ALLOWED=YES`). The initial unsigned attempt failed Keychain with -34018; do not bypass secure storage or replace it with plaintext. The ad-hoc simulator build passed the native Keychain test.

Select exactly one simulator UDID. Install and launch only that device. The local plist adds only `NSAllowsLocalNetworking`, never arbitrary ATS loads. It preserves existing plugin schemes and contains the test-only `emie-local-recovery` scheme. Release/Profile never use this plist or the `EMIE_LOCAL` Swift condition. `lib/main.dart` already rejects Local mode outside Debug.

For OS delivery, use `simctl openurl SELECTED_UDID` with the synthetic test URL assembled privately from a captured reset mail. Do not log the URL. `emie-local-recovery://recover/reset-password?token=...` maps only to the configured local origin. Cold tests terminate this app first; warm tests preserve its session. This is real OS custom-scheme delivery, not proof of public Universal Links. The native ingress uses one expiring RAM slot, hands it to `takeInitial` once, and forwards warm links to the same Dart controller. No proof enters Navigator names, preferences or secure storage.

## External inputs and intended locations

No additional real Google/domain values were supplied for this block. `emiso.ai` is not a confirmed recovery origin.

| Input | Purpose | Intended location |
| --- | --- | --- |
| Confirmed iOS OAuth client ID for `ai.emiso.emie` | Google native client identity | Verified `ios/Runner/GoogleService-Info.plist` and/or explicit confirmed build input |
| Matching reversed iOS client ID | Google callback scheme | Prepared build `Info.plist` / `CFBundleURLTypes` |
| Confirmed backend/web OAuth client ID | ID-token audience for backend | Confirmed release JSON `server_client_id`; backend association reviewed separately |
| Confirmed HTTPS recovery origin, matching AASA app identifier/path | Public Universal Links | Dart `EMIE_RECOVERY_ORIGIN`, native prepared `Info.plist`; associated-domain entitlement only after confirmation |
| Actual AASA file and hosting/Apple association evidence | Verify public OS delivery | Documentation/review input; no hosting or portal mutation here |
| Distribution identity matching the existing distribution profile | Store/archive distribution signing | Existing local Keychain/profile store, never source or ZIP |
| Explicit device-test permission and device | Native device/provider acceptance | Separate authorized device run |

`ios_build_config.py --release-config confirmed.json --output OWNED_BUILD/Info-Release.plist` expects `bundle_id`, `ios_client_id`, `server_client_id`, `reversed_client_id`, `recovery_origin`. Its unit tests use synthetic values only; those values are not release configuration. The helper validates shape and matching scheme, not ownership of a Google project/domain. Confirm the real association first. Do not replace existing configuration with examples.

The production base plist has no invented Google values or associated domains. Its `EMIERecoveryOrigin` build variable defaults to empty. Google availability is checked natively before invoking the provider and is visibly unavailable when missing. Apple Sign-in uses the same unchanged entitlement contents for Debug, Release and Profile.

Documentation-only associated-domain/AASA outline after confirmation: entitlement `applinks:CONFIRMED_HOST`; AASA application identifier `CONFIRMED_TEAM.ai.emiso.emie` and only the intended `/reset-password` route. No such placeholder belongs in active entitlements.

## Actual scope of evidence

See the single review report and per-test JSONs. The local native smoke covers login, Keychain restore, Home, profile save/reload, project save/reload, Memory edit/reload, warm/cold OS recovery, invalid link and session B retention. Real reset completion/replay/password/refresh checks are separate loopback HTTP tests; the native password form was not submitted. Existing Flutter widget/transport tests cover submission and uncertain outcomes separately. There is no claim of one combined native end-to-end reset submission.

A Release-configuration archive was successfully signed with the pre-existing matching Development identity/profile and verified locally. It is a development-signed archive, not distribution signing, TestFlight, Store approval or a real Apple login. Public provider/domain gates and previous broader profile/warm stability gates remain open; this short local smoke does not retire them. No Linux container/image/signal acceptance is implied by macOS POSIX tests.
