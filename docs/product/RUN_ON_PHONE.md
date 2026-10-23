# Run the current app on Android

Use the updated checkout, not the older `prepskul_app` / `paper-app` checkout:

```sh
cd /Users/user/Desktop/PrepSkul/prepskul_app_delbert
./scripts/run-phone.sh
```

Connect the phone over USB, enable USB debugging and accept its authorization prompt. `adb devices -l` must show `device`, not `unauthorized`.

For the local Mate backend, start `npm run dev` in `PrepSkul_Web`, then run:

```sh
MATE_LOCAL_API=1 ./scripts/run-phone.sh
```

The script reverses USB port 3000 and passes an explicit API override. Without that option, the app uses its configured production backend; local server voice/pedagogy changes are not production deployments.

Android debug uses `com.prepskul.prepskul.debug`; the store/release app uses `com.prepskul.prepskul`. They can coexist. Use the app launched by Flutter. Do not uninstall or clear storage to fix a checkout mismatch.
