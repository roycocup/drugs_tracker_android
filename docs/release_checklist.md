# Android Release Checklist

1. **Bump version**  
   - Update `version` in `pubspec.yaml`.  
   - Reflect semantic changes (major/minor/patch) and increment build number.

2. **Update changelog**  
   - Summarise notable fixes/features since the last release.  
   - Include rollout risks or mitigation notes.

3. **Regenerate assets & configs**  
   - Run `flutter pub get` and `flutter clean` if packages changed.  
   - Update app icons/splash if required.  
   - Refresh `google-services.json` and ensure `android/key.properties` is present locally.

4. **Verify telemetry**  
   - Confirm Crashlytics dashboard receives test crash in staging build.  
   - Validate analytics events via DebugView (if enabled).

5. **Run automated checks**  
   - `flutter analyze`  
   - `flutter test`  
   - `flutter test integration_test`  
   - `flutter build appbundle --release --dart-define=APP_ENV=prod`

6. **Manual QA**  
   - Smoke test add/edit/delete record flows.  
   - Validate CSV import/export with sample data.  
   - Review statistics ranges and totals for correctness.

7. **Play Console submission**  
   - Upload the `.aab` artifact from `build/app/outputs/bundle/release/`.  
   - Attach release notes, targeting, and rollout percentage.  
   - Confirm content ratings, data safety form, and screenshots are current.

8. **Post-release monitoring**  
   - Track Crashlytics alerts for regressions.  
   - Review analytics dashboards for engagement anomalies.

