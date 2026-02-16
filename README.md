# nutcracker

A macOS menu bar app that monitors the clipboard for URLs, filters them using installed uBlock filter lists, and replaces them in-place to remove tracking parameters.

## Building

Xcode: Open `nutcracker.xcodeproj` and press Cmd+B to build, or Cmd+R to build and run.

CLI: `xcodebuild -project nutcracker.xcodeproj -scheme nutcracker -configuration Release build`
