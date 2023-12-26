# OpenCombine
[![codecov](https://codecov.io/gh/OpenSwiftUIProject/OpenCombine/graph/badge.svg?token=BJSI3J7RZQ)](https://codecov.io/gh/OpenSwiftUIProject/OpenCombine)
![Language](https://img.shields.io/badge/Swift-5.9-orange.svg)

Open-source implementation of Apple's [Combine](https://developer.apple.com/documentation/combine) framework for processing values over time.

The main goal of this project is to provide a compatible, reliable and efficient implementation which can be used on Apple's operating systems before macOS 10.15 and iOS 13, as well as Linux, Windows and WebAssembly.

The documentation of the package can be found at [OpenCombine Documentation](https://swiftpackageindex.com/OpenSwiftUIProject/OpenCombine/main/documentation/OpenCombine)

| **CI Status** |
|---|
|[![Compatibility tests](https://github.com/OpenSwiftUIProject/OpenCombine/actions/workflows/compatibility_tests.yml/badge.svg)](https://github.com/OpenSwiftUIProject/OpenCombine/actions/workflows/compatibility_tests.yml)|
|[![macOS](https://github.com/OpenSwiftUIProject/OpenCombine/actions/workflows/macos.yml/badge.svg)](https://github.com/OpenSwiftUIProject/OpenCombine/actions/workflows/macos.yml)|
|[![Ubuntu](https://github.com/OpenSwiftUIProject/OpenCombine/actions/workflows/ubuntu.yml/badge.svg)](https://github.com/OpenSwiftUIProject/OpenCombine/actions/workflows/ubuntu.yml)|
|[![Windows](https://github.com/OpenSwiftUIProject/OpenCombine/actions/workflows/windows.yml/badge.svg)](https://github.com/OpenSwiftUIProject/OpenCombine/actions/workflows/windows.yml)|
|[![Wasm](https://github.com/OpenSwiftUIProject/OpenCombine/actions/workflows/wasm.yml/badge.svg)](https://github.com/OpenSwiftUIProject/OpenCombine/actions/workflows/wasm.yml)|


### Installation
`OpenCombine` contains three public targets: `OpenCombine`, `OpenCombineFoundation` and `OpenCombineDispatch` (the fourth one, `COpenCombineHelpers`, is considered private. Don't import it in your projects).

OpenCombine itself does not have any dependencies. Not even Foundation or Dispatch. If you want to use OpenCombine with Dispatch (for example for using `DispatchQueue` as `Scheduler` for operators like `debounce`, `receive(on:)` etc.), you will need to import both `OpenCombine` and `OpenCombineDispatch`. The same applies to Foundation: if you want to use, for instance, `NotificationCenter` or `URLSession` publishers, you'll need to also import `OpenCombineFoundation`.

If you develop code for multiple platforms, you may find it more convenient to import the
`OpenCombineShim` module instead. It conditionally re-exports Combine on Apple platforms (if
available), and all OpenCombine modules on other platforms.

##### Swift Package Manager

###### Swift Package
To add `OpenCombine` to your [SwiftPM](https://swift.org/package-manager/) package, add the `OpenCombine` package to the list of package and target dependencies in your `Package.swift` file. `OpenCombineDispatch` and `OpenCombineFoundation` products are currently not supported on WebAssembly. If your project targets WebAssembly exclusively, you should omit them from the list of your dependencies. If it targets multiple platforms including WebAssembly, depend on them only on non-WebAssembly platforms with [conditional target dependencies](https://github.com/apple/swift-evolution/blob/main/proposals/0273-swiftpm-conditional-target-dependencies.md).

```swift
dependencies: [
    .package(url: "https://github.com/OpenSwiftUIProject/OpenCombine.git", from: "0.14.0")
],
targets: [
    .target(
        name: "MyAwesomePackage",
        dependencies: [
            "OpenCombine",
            .product(name: "OpenCombineFoundation", package: "OpenCombine"),
            .product(name: "OpenCombineDispatch", package: "OpenCombine")
        ]
    ),
]
```

###### Xcode
`OpenCombine` can also be added as a SwiftPM dependency directly in your Xcode project *(requires Xcode 11 upwards)*.

To do so, open Xcode, use **File** → **Swift Packages** → **Add Package Dependency…**, enter the [repository URL](https://github.com/OpenSwiftUIProject/OpenCombine.git), choose the latest available version, and activate the checkboxes:

<p align="center">
<img alt="Select the OpenCombine and OpenCombineDispatch targets" 
	src="https://user-images.githubusercontent.com/16309982/67618468-bd379f80-f7f8-11e9-917f-e76e878a1aee.png" width="70%">
</p>

#### Debugger Support

The file `opencombine_lldb.py`  defines some `lldb` type summaries for easier debugging. These type summaries improve the way `lldb` and Xcode display some OpenCombine values.

To use `opencombine_lldb.py`, figure out its full path. Let's say the full path is `~/projects/OpenSwiftUIProject/OpenCombine_lldb.py`. Then the following statement to your `~/.lldbinit` file:

    command script import ~/projects/OpenSwiftUIProject/OpenCombine_lldb.py

Currently, `opencombine_lldb.py` defines type summaries for these types:

- `Subscribers.Demand`
- That's all for now.

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).
