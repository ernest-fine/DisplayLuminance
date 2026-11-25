# Display Luminance

Native macOS SwiftUI app that sets hardware brightness (luminance) on **all** external displays using [m1ddc](https://github.com/waydabber/m1ddc) over DDC/CI.

**m1ddc is bundled inside the app** — no Homebrew or separate install required. The Xcode build compiles vendored m1ddc v1.2.0 source into `DisplayLuminance.app/Contents/Resources/m1ddc`.

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 13+
- External monitor(s) with DDC/CI over USB-C / DisplayPort Alt Mode

> m1ddc does not control the built-in Mac display or monitors on unsupported ports (e.g. built-in HDMI on base M1/M2 models). See the [m1ddc README](https://github.com/waydabber/m1ddc) for details.

## Build & run

```bash
cd ~/Documents/DisplayLuminance
open DisplayLuminance.xcodeproj
```

In Xcode: select the **DisplayLuminance** scheme and press **Run** (⌘R).

Or from the command line:

```bash
xcodebuild -scheme DisplayLuminance -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/DisplayLuminance.app
```

## Usage

- Use **−10%** or **+10%** next to a display to adjust it in 10-point steps. An in-between level moves to the next multiple of 10 in the chosen direction.
- Use **All displays** to set a shared brightness. Each button shows the level it will apply. With mixed levels, lowering steps below the dimmest display and raising steps above the brightest, within the 0–100% range.
- Use **Refresh** (⌘R) to scan for displays and read their brightness again.

## Third-party license

m1ddc is MIT licensed. A copy is included in the app bundle as `m1ddc-LICENSE.txt`. Source lives in `Vendor/m1ddc/`.
