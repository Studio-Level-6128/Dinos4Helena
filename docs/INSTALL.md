# Install Dinos4Helena

## Play on Android with an APK

An APK is the file that installs the game on your phone. If you don’t have one, follow the Linux build steps below first.

1. Copy the game’s `.apk` file to the phone’s **Downloads** folder.
2. Open **Files**, find the APK in **Downloads**, and tap it. If Android asks to allow installs from this app, allow it only if you trust the file. You can turn that permission off again afterward.
3. Tap **Install**, then **Open**. Choose **Quests → Getting Started** to play the first campaign.

## Run from source on Linux

The included setup script is for **64-bit Intel or AMD Linux**. You’ll need an internet connection, Bash, Git, `curl`, `unzip`, and `tar`. Setup downloads Godot and the Android build tools into the project folder and accepts the Android SDK licenses.

```bash
git clone https://github.com/Studio-Level-6128/Dinos4Helena.git
cd Dinos4Helena
./scripts/setup-dev.sh
./scripts/godot.sh --path .
```

The last command launches the desktop game. If you already have the source, start in the project folder and skip the first two commands.

## Build the Android APK on Linux

1. Complete the Linux setup above and close the game.
2. From the project folder, run `./scripts/godot.sh --editor --path .`. In Godot, choose **Project → Install Android Build Template**, confirm, and close the editor after installation.
3. Run `./scripts/build-android.sh`. The installer is `build/android/Dinos4Helena-debug.apk`. Copy that file to your phone and follow **Play on Android with an APK** above.

For USB installation instead, enable **USB debugging** in the phone’s developer options, connect it to the computer, and approve the debugging prompt. Then run:

```bash
.tools/android-sdk/platform-tools/adb devices
.tools/android-sdk/platform-tools/adb install -r build/android/Dinos4Helena-debug.apk
```

If the device list says `unauthorized`, unlock the phone and approve the prompt before running the install command. Once the game opens, the [player guide](PLAY_GUIDE.md) explains the controls.