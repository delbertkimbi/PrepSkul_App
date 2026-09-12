# Diligence runbook (Flutter)

Clone: `https://github.com/delbertkimbi/PrepSkul_App` (`main` = marketplace, `primar` = kids product).

```bash
cp .env.template .env
flutter pub get
flutter run
```

Env names and Fapshi sandbox vs live: [ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md).

Folder map and naming (SkulMate vs Primar): [STRUCTURE.md](STRUCTURE.md).

Group classes follow `GROUP_CLASSES_ENABLED` / `AppConfig.enableGroupClasses`. Primar is off on `main` (`AppConfig.enablePrimar`).

```bash
# One line (zsh treats pasted newlines as new commands):
flutter test test/features/sessions/floating_pip_drag_test.dart test/features/tutor/tutor_online_join_test.dart test/features/booking/upcoming_session_merge_test.dart test/features/group_classes/my_sessions_group_visibility_test.dart
```
