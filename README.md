# Dinos4Helena

A mobile-first 3D Android game starter built with Godot 4 and GDScript. The repository includes a project-local development toolchain, VS Code integration, a small 3D test scene, and a verified Android debug export.

## Installed development stack

- Godot 4.7.2 (standard/GDScript edition)
- Godot export templates matching the editor version
- Eclipse Temurin JDK 17
- Android SDK Platform 36, Build Tools 36.1.0, Platform Tools, NDK 29, and CMake 3.22.1
- VS Code Godot Tools extension

The large tools are stored in ignored `.tools/`, `.local/`, and `.cache/` directories. This keeps the machine-wide Java and Android configuration untouched.

## Work in VS Code

Open this repository as the workspace. VS Code should activate the Godot Tools extension automatically.

Use `Terminal > Run Task`:

- `Godot: Open editor` opens the visual scene/asset editor.
- `Godot: Run game` runs the game on the desktop.
- `Android: Build debug APK` creates `build/android/Dinos4Helena-debug.apk`.
- `Android: Connected devices` lists USB-connected Android devices.

`Ctrl+Shift+B` builds the APK. Use `Terminal > Run Task > Godot: Run game` to launch the desktop game. Scripts live under `scripts/`; scenes and assets are edited visually in Godot while GDScript is edited in VS Code.

Equivalent terminal commands are:

```bash
./scripts/godot.sh --editor --path .
./scripts/godot.sh --path .
./scripts/build-android.sh
```

If the ignored local toolchain is ever removed, recreate it with:

```bash
./scripts/setup-dev.sh
```

## Run on an Android phone

1. Enable Developer options and USB debugging on the phone.
2. Connect it over USB and accept the debugging prompt.
3. Run the `Android: Connected devices` task.
4. Build the APK, then install it:

```bash
.tools/android-sdk/platform-tools/adb install -r build/android/Dinos4Helena-debug.apk
```

You can also select the phone from Godot's play/deploy controls after opening the editor.

## Prepare a Google Play release later

The checked-in preset intentionally creates a debug APK only. Before publishing:

1. Change `package/unique_name` in `export_presets.cfg` from `org.dinos4helena.game` to a package ID you own. A published package ID cannot be changed later.
2. In Godot, use `Project > Install Android Build Template`, then add a separate Android release preset with Gradle Build enabled and export format set to AAB.
3. Create a release keystore and keep both the file and passwords outside Git. Never reuse the generated debug key for a Play release.
4. Export a signed, non-debug `.aab`, test it on a Play internal-testing track, then complete the store listing and policy declarations.

Google Play requires Android App Bundles for new apps. Keep release signing credentials backed up securely; losing them can complicate future updates.

## Project choices

The starter uses Godot's Compatibility renderer for broad Android GPU support. The placeholder dinosaur is assembled from primitives in `scripts/main.gd`, which proves the complete 3D render path without committing a large model. Replace it with a `.glb` model when art production begins.
