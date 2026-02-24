# Google Flip Clock for macOS

[English](README.md) | [中文](README_CN.md)

A premium, mechanical-style flip clock application built with SwiftUI for macOS. Experience the classic aesthetic of split-flap displays on your desktop.

## ✨ Features

- **Classic Flip Clock**: Precise time display with mechanical 3D flip animations.
- **Dynamic Animations**: Snappy, spring-based animations with realistic overshoot and bounce.
- **Mechanical Design**: Digit cards designed to look like physical plastic plates with a middle hinge and separate plate lighting.
- **Multiple Modes**:
    - **Clock Mode**: Displays current time, date, and weekday (in Chinese).
    - **Timer Mode**: Stop-watch functionality for tracking elapsed time.
    - **Countdown Mode**: Customizable countdown timer (defaults to 10 minutes) with quick-set presets.
- **Responsive Layout**: Automatically scales to maintain a 16:9 aspect ratio at any window size.
- **Menu Bar Integration**: Quick access and mode switching directly from the macOS menu bar.
- **Premium Aesthetics**: Dark-mode optimized with soft gradients, subtle shadows, and mechanical hinge details.
- **Screen Saver**: Same flip clock as a macOS screen saver (GoogleFlipClockSaver) — select it in System Settings.

## 🛠 Technical Details

- **Framework**: SwiftUI (macOS 12.0+)
- **Architecture**: Single-file consolidation for maximum build stability.
- **Animations**: Custom `rotation3DEffect` with spring physics and physical plate clipping.
- **State Management**: Using `ObservableObject` and `Combine` for real-time updates.

## 🚀 Getting Started

1. Open the project in **Xcode**.
2. Select your Mac as the target.
3. Press **Cmd + R** to Build & Run.

## 💡 Usage Tips

- **Switch Modes**: Use the navigation bar at the bottom or the "Switch Mode" menu in the Menu Bar.
- **Reset Timer/Countdown**: Click the circular reset button to return to your last set time.
- **Custom Countdown**: Type any number of minutes in the countdown field and click "Set".

## 🖥 Screen Saver

1. In Xcode, select the **GoogleFlipClockSaver** scheme and press **Cmd + B** to build.
2. The built product is at `build/Build/Products/Debug/GoogleFlipClockSaver.saver` (or the Release path).
3. Install: double-click the `.saver` file to open Screen Saver options, or copy it to `~/Library/Screen Savers/`, then choose **GoogleFlipClockSaver** in **System Settings → Screen Saver**.

---
*Created with care to bring mechanical charm to modern desktops.*
