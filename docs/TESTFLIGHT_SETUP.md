# Mac-free development: CI → TestFlight setup

This repo is set up so the only Apple hardware you ever need is your iPhone.
GitHub Actions (macOS runners) compiles, tests, signs, and uploads the app;
your phone installs each build from the TestFlight app. Every step below can
be done from a phone browser.

## One-time setup

### 1. Apple Developer Program ($99/year)

Enroll at [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll)
or via the **Apple Developer** app on your iPhone (usually the smoothest
path — it uses your device's identity for verification).

After enrolling, note your **Team ID** (10 characters, e.g. `AB12CD34EF`):
developer.apple.com → Account → Membership details.

### 2. Register the app

1. **Bundle ID:** developer.apple.com → Account → Certificates, Identifiers &
   Profiles → Identifiers → **+** → App IDs → App.
   - Description: `Quick Draw`
   - Bundle ID (explicit): `com.quickdraw.app` — *if this exact ID is taken,
     pick your own (e.g. `com.yourname.quickdraw`) and change
     `PRODUCT_BUNDLE_IDENTIFIER` in `QuickDraw.xcodeproj/project.pbxproj`
     (two occurrences) to match.*
   - No special capabilities needed (Multipeer Connectivity requires none).
2. **App record:** [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   → My Apps → **+** → New App.
   - Platform iOS, Name `Quick Draw` (or any available name), Language
     English, Bundle ID: the one above, SKU: anything (e.g. `quickdraw-001`).

### 3. Create an App Store Connect API key

App Store Connect → Users and Access → **Integrations** → App Store Connect
API → Team Keys → **+**.

- Name: `github-ci`
- Access: **App Manager** (Admin also works; lower roles cannot use
  cloud-managed signing).
- Download the `.p8` file — **you get exactly one chance to download it.**
- Note the **Key ID** (on the key row) and the **Issuer ID** (top of page).

### 4. Add GitHub repository secrets

GitHub repo → Settings → Secrets and variables → Actions → New repository
secret (×4):

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | the Key ID from step 3 |
| `ASC_ISSUER_ID` | the Issuer ID from step 3 |
| `ASC_KEY_P8` | the full text contents of the `.p8` file, including the BEGIN/END lines |
| `APPLE_TEAM_ID` | your Team ID from step 1 |

(To read the `.p8` on a phone: open it in the Files app with a text-viewer,
or forward it to yourself; it's a short plain-text file.)

### 5. Run the pipeline

- Merge/push to `main`, **or** GitHub → Actions → *iOS CI* → **Run
  workflow**.
- First run does everything: registers signing (Apple *cloud-managed*
  certificates — no certificate files to manage anywhere), builds, tests,
  archives, uploads.
- After Apple's processing (5–30 min) the build appears in App Store Connect
  → TestFlight. First time only: answer any remaining compliance questions
  (encryption is pre-answered by `ITSAppUsesNonExemptEncryption` in the
  Info.plist) and add yourself under **Internal Testing** (create a group,
  add your Apple ID).
- Install the **TestFlight** app on both iPhones, accept the invite, install
  Quick Draw. Subsequent uploads appear as updates automatically.

## Day-to-day loop

1. Edit code (Claude Code session, github.dev, any editor) and push.
2. The `test` job runs the 68-test unit suite on every push to `main` or a
   `claude/**` branch; the `deploy` job uploads to TestFlight on pushes to
   `main` (or manual dispatch from any branch).
3. Update the app from TestFlight on both phones and play.

Expect ~10–15 min of CI plus Apple's processing per iteration. Motion
tuning this way is slow but workable — batch several threshold changes per
build, and use the diagnostics overlay (below) to decide them.

## TestFlight tooling builds

CI builds compile with the `TESTFLIGHT_TOOLS` Swift condition, which keeps
the developer tooling that is normally DEBUG-only:

- Settings → **Developer diagnostics** overlay (live tilt/rotation/accel,
  detector state, thresholds, sync offset, opponent report)
- Home → **Practice vs. Tin Can Tex** (simulated opponent)
- Countdown debug buttons (Sim Draw / Sim False Start / Drop Link)

For an eventual **App Store review build**, run the workflow manually with
`include_tools` unchecked — that produces a clean release with all tooling
compiled out.

## Cost & quota notes

- GitHub-hosted **macOS runners bill at a 10× minute multiplier** on private
  repos. The free tier (2,000 min/month) ≈ 200 macOS minutes ≈ ~10–13 full
  runs. Options: make the repo public (macOS minutes are free for public
  repos), buy extra minutes, or trigger `deploy` manually only when you
  actually want a new phone build (pushes to feature branches only run the
  cheap-ish test job — consider pushing batches).
- The Apple Developer Program fee is the only other recurring cost.

## Troubleshooting

- **"No profiles / no signing certificate" during archive** — the API key's
  role is too low (needs App Manager/Admin) or `APPLE_TEAM_ID` is wrong.
- **Upload rejected: bundle ID not found** — step 2 wasn't completed, or the
  pbxproj bundle ID doesn't match the registered one.
- **Build never appears in TestFlight** — check App Store Connect → your
  app → TestFlight → iOS builds for a processing/compliance hold; also check
  the email tied to your developer account.
- **Two-phone testing note:** TestFlight internal testers can install on all
  their own devices; add a second Apple ID as a tester for the second phone,
  or sign into TestFlight with the same Apple ID on both.
