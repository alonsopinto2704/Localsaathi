# Launch readiness plan (2026-10-04)

Goal: take LocalSaathi from "demo that runs" to "ready to deploy": an Android app
that can go through Google Play review, a public website a real business would
run, and a backend that has actually been executed. The chief engineer (main
session) reviews every workstream's diff and re-runs its verification; nothing
counts as done on an agent's word alone.

## Assumptions (correct any of these and the plan changes)

1. **The public website is built in this repo (`website/`, static Astro) using
   the app as the reference** (owner's instruction, replacing an earlier Floot
   site): same tokens, screens, components, copy and data, exported from the
   app's source. Static HTML per page keeps it crawlable and fast. The Flutter
   web build stays the visual reference and is not deployed.
2. **Android only** for the store launch. iOS is out of scope.
3. **Backend is the existing Supabase design** in `backend/`. Steps that need
   the owner's accounts (Supabase project, SMS provider with DLT registration,
   Play Console developer account, domain) are prepared and documented, not
   performed.
4. **Mock mode stays the default** for local development. Release builds talk
   to Supabase when built with `--dart-define=SUPABASE_URL=… SUPABASE_ANON_KEY=…`.
5. **No new tracking SDKs.** Crashes and ANRs come from Play Console Android
   vitals; website analytics is Floot's built-in, storage-free mode.
6. **Contact is by email links**, not forms, so the website collects no new
   personal data.
7. **Placeholders stay placeholders**: domain `localsaathi.example`, operator
   name/address, Grievance Officer. One config value per platform to change.

## Success criteria

- [ ] `flutter analyze` reports no issues; `flutter test` is fully green
      (including the 10 domain tests that failed before).
- [ ] `flutter build appbundle --release` succeeds with targetSdk 36,
      16 KB page-size aligned native libraries, R8 on, release signing from
      `android/key.properties` when present.
- [ ] All 12 migrations + seed apply on a real Postgres engine with Supabase
      stubs, and the pgTAP suite passes, from one command.
- [ ] With Supabase configured, every repository the app uses is backed by
      Supabase (saved providers and drafts stay on-device by design); without
      it the app runs in labelled demo mode exactly as today.
- [ ] Website has the pages and plumbing a real business site has (below),
      verified by screenshots on desktop and phone.
- [ ] `store/` holds Play listing text within limits, 512 px icon, 1024×500
      feature graphic, phone screenshots, and the App content answers (data
      safety, content rating, ads, health, app access for reviewers).
- [ ] `DEPLOYMENT.md` runbook with a rollback plan; CI workflow file.

## Workstreams and file ownership

Agents run in parallel in one working directory, so each owns a disjoint set
of paths. Touching another workstream's paths is not allowed; report the need
instead.

| WS | Scope | Owns |
|---|---|---|
| 1 Backend verification | Run migrations + pgTAP on PGlite, fix SQL, harden RLS | `backend/**`, `docs/deploy/backend.md` |
| 2 Supabase data layer | Supabase repositories, env config, real call/WhatsApp, photo upload | `lib/data/supabase/**`, `lib/app/app_dependencies.dart`, `lib/main.dart`, `lib/core/config/app_config.dart`, `lib/core/widgets/provider_contact.dart`, `pubspec.yaml` deps, `test/supabase_*` |
| 3 Android release | targetSdk 36, toolchain, splash, 16 KB check, signing, CI | `android/**`, `.github/**`, `docs/deploy/android-release.md` |
| 4 Play listing | Listing copy, graphics, screenshots, App content answers | `store/**`, `tool/make_icons.py`, `tool/store_screenshots.*`, `docs/deploy/play-console.md` |
| 5 Website (top priority) | App-mirrored site: pages, SEO, account deletion URL, a11y | `website/**`, `tool/export_website_data.py`, `docs/deploy/website.md` |
| 7 Test health | Fix the failing domain tests at root cause | `lib/domain/**`, `lib/data/repositories/mock_*`, `lib/data/seed/**`, `test/localsaathi_core_test.dart` |

Chief engineer: `tasks/plan.md`, `DEPLOYMENT.md`, `pubspec.yaml` version,
`README.md`, final integration build and screenshots.

## Website scope (WS5)

Home (how it works, trust, provider CTA), search results, city-wide service
pages, locality and locality+service pages (exist), provider pages (exist), For
providers, About, Contact, Help/FAQ, Trust & safety, legal (exist) + account
deletion, 404. Plumbing: per-page title/description/canonical, Open Graph and
Twitter cards, JSON-LD (Organization, LocalBusiness, BreadcrumbList, FAQPage),
sitemap and robots, one `indexingEnabled` switch (off while listings are demo),
favicon/app icon, report-listing and share actions, keyboard and screen-reader
basics. No invented facts: no testimonials, user counts, team names, addresses.

## Order

1. Parallel: WS1, WS2, WS3, WS4, WS5, WS7.
2. Review each as it lands; send fixes back to the same agent.
3. Integration: version bump, full test + analyze, release AAB on the merged
   tree, store screenshots from the final build, website screenshots.
4. DEPLOYMENT.md + rollback plan; final report.

## Findings at kickoff

- `flutter build appbundle --release` fails today: Gradle 8.9 is below Flutter
  3.47.6's minimum (8.14); Flutter's migrator also pinned `android.newDsl=false`.
  → WS3.
- Call and WhatsApp on real (non-demo) listings only show "not wired" messages:
  the app's core action is missing. → WS2.
- The app has no backend client at all (mock repositories only). → WS2.

## Risks

| Risk | Mitigation |
|---|---|
| Supabase layer can't be run end to end here (no Docker, no project) | Pure mapping tests now; opt-in smoke test against a real project, documented |
| Parallel agents break each other's builds | Ownership table; WS3 builds in a private copy |
| 16 GB RAM with Gradle + Flutter + Node at once | Only WS3 runs Gradle; daemons stopped after use |
| Play review needs a login for provider features | Supabase test phone number + fixed OTP for reviewers, documented |
| New personal developer accounts need 12 testers × 14 days of closed testing | Called out in the Play runbook |
