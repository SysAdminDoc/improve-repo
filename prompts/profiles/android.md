Stack: Android (Kotlin/Compose/Gradle).

When surfacing improvement opportunities, prioritize:
- Material 3 compliance (theming, dynamic colors, motion tokens)
- AMOLED / true-black dark theme support
- minSdk/targetSdk alignment with the latest stable (don't assume very old baselines without reason)
- Foreground service + notification compliance on Android 14+ (FGS types, exact alarms, boot permissions)
- Background execution limits (WorkManager vs AlarmManager vs JobScheduler choices)
- R8/ProGuard / minify + shrinkResources for release builds
- Adaptive icon (foreground/background/monochrome layers)
- Edge-to-edge + predictive back gesture support (Android 14+)
- APK signing: verify a release signing config exists, not just debug
- Gradle: Kotlin DSL (build.gradle.kts), version catalog (libs.versions.toml), dependencyResolutionManagement
- Compose: stability annotations, derivedStateOf, rememberSaveable, LazyColumn keys
- Accessibility: content descriptions, touch targets ≥48dp, TalkBack support
- Deep linking, app links, Android App Bundles (AAB) for Play Store
- Baseline profiles / Startup tracing for cold-start optimization

Skip generic "add unit tests" or "add README" suggestions — they're already universal.
