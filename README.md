# Display Luminance

Display Luminance is a native macOS app for adjusting the hardware brightness of external monitors. Set every connected monitor to one brightness level or adjust them individually.

[Download the latest release](https://github.com/ernest-fine/DisplayLuminance/releases/latest)

## Install

You’ll need an Apple Silicon Mac running macOS 13 or later and an external monitor that supports DDC/CI over USB-C with DisplayPort Alt Mode or a supported HDMI port. [Connection details](https://github.com/waydabber/m1ddc/tree/v1.3.3#readme)

1. Download the Apple Silicon ZIP from the release’s **Assets** section.
2. Unzip it and move **Display Luminance** to **Applications**. Quit any open copy before replacing it.
3. Open the app. If your monitor supports DDC/CI but doesn’t appear, enable DDC/CI in the monitor’s settings and click **Refresh**.

The downloadable build is ad-hoc signed. You can also build the app in Xcode using the instructions below.

## Adjust brightness

- **Adjust one display.** Click **−10%** or **+10%** next to the monitor. The buttons select multiples of 10 from 0% to 100%. If the current level is between steps, the first click moves to the next step in the selected direction.
- **Adjust all displays.** Click **Lower all** or **Raise all** to set every monitor to the level shown on the button. If brightness levels differ, **Lower all** steps below the dimmest monitor and **Raise all** steps above the brightest, within the 0–100% range. With monitors at 40% and 70%, the buttons set both to 30% or 80%.
- **See current brightness.** Each monitor thumbnail reflects that monitor’s brightness. The amber halo follows the shared level or the average of reported levels when the monitors differ.
- **Refresh or retry.** Press **⌘R** to rescan and read the current levels. If a write fails, **Retry** sends the same target to that monitor again.

## Build from source

Open `DisplayLuminance.xcodeproj` in Xcode, select the **DisplayLuminance** scheme, and press **⌘R**. You can also build and run from the project directory in Terminal.

```bash
xcodebuild -project DisplayLuminance.xcodeproj -scheme DisplayLuminance -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/DisplayLuminance.app
```

## Third-party software

The Xcode build compiles m1ddc v1.3.3 from `Vendor/m1ddc/` and bundles the executable and its MIT license inside the app. [m1ddc license](Vendor/m1ddc/LICENSE)
