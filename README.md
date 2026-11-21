# Focus Shade

Focus Shade is a resizable overlay for macOS. Use it to cover part of a display and reveal a window underneath when you need it.

**macOS 13 or later** · **Swift and AppKit**

**[Download for macOS](https://github.com/HanbeenMoon/focus-shade/releases/latest/download/FocusShade-macOS.zip)** · [Build from source](#build) · [한국어](README.ko.md)

![Focus Shade overlay with its settings in English](docs/preview.png)

## Install

The download works on Apple silicon and Intel Macs running macOS 13 or later.

1. Download the ZIP and open it.
2. Move **가림막.app** into **Applications**, then open it.
3. Read the quick guide and click **Get Started**. To open it later, choose **Focus Shade → Quick Start** from the menu bar.

The download is ad hoc signed and has no Apple notarization. If macOS blocks the first launch, check that you downloaded it from this repository. Apple explains the **Open Anyway** option in **System Settings → Privacy & Security**. You can also [build locally](#build). [Apple’s guidance on opening apps](https://support.apple.com/en-us/102445)

## Why Focus Shade exists

While working across several displays, I kept glancing at windows I still needed later. Closing them meant finding and opening them again when I needed a reference.

The design question was how to put those windows out of sight and still reach them in one gesture. A movable, resizable shade covers just the distracting area. Double-clicking the shade brings the window beneath it into view. A small dot and an opacity bar keep everyday controls within reach of the shaded area.

## Use it

| To | Do this |
| --- | --- |
| Cover part of the screen | Drag the solid area to move the shade. Drag an edge or corner to resize it. The shade can span displays. |
| Fill a display | Double-click the top edge on that display. Double-click the top edge again to restore the previous size and position. |
| Reveal a covered window | Double-click the solid area over the window. Click the shade once or reopen it from the Dock to cover it again. |
| Adjust the look | Drag the thin bar at the top right. Open the small dot menu to change the color or toggle always-on-top. |

The dot menu also lets you hide or quit the overlay. The app remembers its position, size, color, and transparency in local macOS preferences. Use the globe icon in the dot menu to switch between English and Korean.

## Build

Install Xcode Command Line Tools or Xcode, then open the downloaded source directory in Terminal.

```sh
mkdir -p dist
build_dir=$(mktemp -d "$PWD/dist/build.XXXXXXXX")
./build.sh "$build_dir/가림막.app"
open "$build_dir/가림막.app"
```

The script builds and signs the bundle locally. Move the finished app to Applications before using **Options → Keep in Dock** on its Dock icon.

## Report a problem

Open a [GitHub issue](../../issues/new/choose) with your macOS version and steps to reproduce. For build and test commands, see [Contributing](CONTRIBUTING.md).
