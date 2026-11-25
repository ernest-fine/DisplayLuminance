# Display Luminance

Native macOS SwiftUI app that sets hardware brightness (luminance) on **all** external displays using [m1ddc](https://github.com/waydabber/m1ddc) over DDC/CI.

The Xcode build compiles the bundled m1ddc v1.3.3 source into `DisplayLuminance.app/Contents/Resources/m1ddc`.

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 13+
- An external monitor with DDC/CI over USB-C / DisplayPort Alt Mode or a supported HDMI port

See the [m1ddc connection requirements](https://github.com/waydabber/m1ddc/tree/v1.3.3#readme) for details.

## Build & run

From the project directory:

```bash
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
- Use **Lower all** or **Raise all** to set a shared brightness. Each button shows the level it will apply. With mixed levels, lowering steps below the dimmest display and raising steps above the brightest, within the 0–100% range.
- Use **Refresh** (⌘R) to scan for displays and read their brightness again.

## Third-party license

m1ddc is MIT licensed. A copy is included in the app bundle as `m1ddc-LICENSE.txt`. Source lives in `Vendor/m1ddc/`.
