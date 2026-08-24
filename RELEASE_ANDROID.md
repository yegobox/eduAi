# Android release (Google Play)

Package name: **`rw.akili.app`** · Track flow: `internal` → `beta` → `production`.

The pipeline mirrors Flipper's (`apps/flipper/android` + `.github/workflows/build_android.yaml`):
Gradle reads the upload key from `key.properties`, Fastlane builds the AAB and calls
`supply` (`upload_to_play_store`) with a Play service-account JSON.

Differences from Flipper: no Melos/submodules (single-package repo), no Shorebird,
and compile-time config comes from `env.json` via `--dart-define-from-file`.

---

## 1. The first release — must be done by hand

Google Play's API **cannot create an app and cannot make its first upload**. Until an
AAB for `rw.akili.app` exists in the Console, every `supply` call fails. So do this once:

1. **Play Console → Create app**: name, default language, App, Free.
   Use the same developer account as Flipper so the existing service account can reach it.
2. **Complete the release-readiness forms** (Dashboard → "Set up your app"): privacy
   policy URL, app access (give a test login — reviewers must get past the sign-in wall),
   ads declaration, content rating, target audience (this app has education/child-facing
   content — answer honestly, it changes the Families policy that applies), data safety
   (declare what Supabase/Firebase collects), and the store listing (icon 512×512,
   feature graphic 1024×500, ≥2 phone screenshots, short + full description).
   Declare the MoMo payment flow under financial features.
3. **Get a signed bundle.** The signing material is shared with Flipper and is already
   copied into this project (`android/key.properties` + `android/app/key.jks`, alias
   `upload`, both git-ignored). Use a production config file rather than the dev
   `env.json` — `APP_FLAVOR` must not be `dev` and `DATA_CONNECTOR_URL` must not be
   `localhost`:
   ```bash
   cp env.json env.prod.json    # then edit: APP_FLAVOR=prod, real DATA_CONNECTOR_URL
   flutter build appbundle --release --dart-define-from-file=env.prod.json
   # -> build/app/outputs/bundle/release/app-release.aab   (versionCode 1)
   ```
   This needs the Android SDK installed locally (`flutter doctor` must show a green
   Android toolchain). If it isn't, run the *Release Android (Play Store)* workflow with
   lane **`build_only`** and download the `eduai-android-<run>` artifact instead — it
   builds the same signed AAB on CI without touching the Play API.

4. **Upload it** to Internal testing → create release → add testers → roll out.
   This is where Play enrols the app in Play App Signing and registers your upload key.
5. Verify the install works from the Play link before wiring CI.

After that first upload succeeds, everything below is automatic.

## 2. Repo secrets

GitHub secrets are per-repository, so the Flipper ones are **not** visible here (and their
values cannot be read back out of Flipper — they must be re-entered from the original
source). Set these on `yegobox/eduAi` → Settings → Secrets and variables → Actions:

| Secret | Where the value comes from |
| --- | --- |
| `PLAY_STORE_UPLOAD_KEY` | `base64 -i android/app/key.jks` — the keystore shared with Flipper (alias `upload`). |
| `KEYSTORE_KEY_ALIAS` | `upload` (same as Flipper) |
| `KEYSTORE_KEY_PASSWORD` | from `android/key.properties` |
| `KEYSTORE_STORE_PASSWORD` | from `android/key.properties` |
| `PLAYSTORE_ACCOUNT_KEY` | The Play Console service-account JSON, same one Flipper uses. Grant that service account access to the new app in Play Console → Users and permissions. |
| `ENV_JSON` | Full production `env.json`: real `SUPABASE_URL`/`SUPABASE_ANON_KEY`, `APP_FLAVOR: prod`, a reachable `DATA_CONNECTOR_URL` (not localhost), MoMo settings. |
| `GOOGLE_SERVICE_JSON` | `android/app/google-services.json` — the Android app config from Firebase project `akili-dc22e` for `rw.akili.app`. Must be the file with a top-level `client` array (not `firebase.json`, not a service-account key). `tool/validate_google_services.py` checks this in CI. Only needed when `ENABLE_PHONE_AUTH` is true; the workflow warns and continues without it. |

Set them from the working copy with the `gh` CLI:

```bash
cd /Users/richard/Developer/yego-project/eduAi
R=yegobox/eduAi
base64 -i android/app/key.jks | gh secret set PLAY_STORE_UPLOAD_KEY -R $R
grep '^keyAlias='       android/key.properties | cut -d= -f2- | tr -d '\n' | gh secret set KEYSTORE_KEY_ALIAS -R $R
grep '^keyPassword='    android/key.properties | cut -d= -f2- | tr -d '\n' | gh secret set KEYSTORE_KEY_PASSWORD -R $R
grep '^storePassword='  android/key.properties | cut -d= -f2- | tr -d '\n' | gh secret set KEYSTORE_STORE_PASSWORD -R $R
gh secret set GOOGLE_SERVICE_JSON       -R $R < android/app/google-services.json
gh secret set ENV_JSON                  -R $R < env.prod.json          # create this first
gh secret set PLAYSTORE_ACCOUNT_KEY     -R $R < /path/to/play-service-account.json
```

The keystore itself is **not** in git — back it up outside the repo. Losing it means
asking Google to reset the upload key.

## 3. Shipping after that

- **On every push, any branch** → internal track. No commit-message opt-in, no branch
  filter: if you push, it ships to internal testing.
- **On tag**: `git tag android-v1.0.3 && git push origin android-v1.0.3` → internal track.
- **Manual**: Actions → *Release Android (Play Store)* → Run workflow → pick a lane
  (`build_only`, `internal`, `beta`, `production`, `promote_to_production`). `beta` and
  `production` are only ever reached this way.

Runs share one `release-android` concurrency group and queue rather than cancel, so
back-to-back pushes upload in order instead of interrupting an in-flight Play upload.

Versioning is driven by CI, not `pubspec.yaml`:
`versionCode = github.run_number + 1000`, `versionName = 1.0.<run_number>`. The gradle
config reads `VERSION_CODE` / `VERSION_NAME` from the environment and falls back to the
pubspec values locally. The +1000 offset keeps CI codes safely above the manual `1`.

Release notes: `android/fastlane/metadata/android/en-US/changelogs/default.txt`.

## 4. Local dry run

```bash
cd android
bundle install
PLAY_STORE_CONFIG_JSON="$(cat /path/to/play-service-account.json)" bundle exec fastlane internal
```

Set `AAB_PREBUILT=true` to upload a bundle you already built instead of rebuilding.

## Notes / still open

- iOS and macOS bundle IDs are still `rw.eduai.eduai`. Only Android was renamed; change
  them when you go to the App Store.
- The launcher label in `android/app/src/main/AndroidManifest.xml` is still `eduai`.
  The Play listing name is separate, but pick the final on-device name before launch.
- Production rollout: personal Play accounts need 12 testers for 14 days first;
  organization accounts are exempt.
