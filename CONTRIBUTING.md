# Contributing

In order to work on this project you will need Xcode 10.2 and Swift 5.0 or later.

Please refer to the [issue #1](https://github.com/OpenCombine/OpenCombine/issues/1) for the list of operators that remain unimplemented, as well as the [RemainingCombineInterface.swift](https://github.com/OpenCombine/OpenCombine/blob/master/RemainingCombineInterface.swift) file. The latter contains the generated interface of Apple's Combine from the latest Xcode version. When the functionality is implemented in OpenCombine, it should be removed from the RemainingCombineInterface.swift file.

You can refer to [this repo](https://github.com/OpenCombine/combine-interfaces) to observe Apple's Combine API and documentation changes between different Xcode (beta) versions.

You can run compatibility tests against Apple's Combine. In order to do that you will need either macOS 10.14 with iOS 13 simulator installed (since the only way we can get Apple's Combine on macOS 10.14 is using the simulator), or macOS 10.15 (Apple's Combine is bundled with the OS). Execute the following command from the root of the package:

```
$ make test-compatibility
```

Or enable the `-DOPENCOMBINE_COMPATIBILITY_TEST` compiler flag in Xcode's build settings. Note that on iOS only the latter will work.

> NOTE: Before starting to work on some feature, please consult the [GitHub project](https://github.com/OpenCombine/OpenCombine/projects/2) to make sure that nobody's already making progress on the same feature! If not, then please create a draft PR to indicate that you're beginning your work.

#### Releasing a new version

1. Create a new branch from master and call it `release/<major>.<minor>.<patch>`.
1. Replace the usages of the old version in `README.md` with the new version (make sure to check the [Swift Package Manager](#swift-package-manager) and [CocoaPods](#cocoapods) sections).
1. Bump the version in `OpenCombine.podspec`, `OpenCombineDispatch.podspec` and `OpenCombineFoundation.podspec`. In the latter two you will also need to set the `spec.dependency "OpenCombine"` property to the **previous** version. Why? Because otherwise the `pod lib lint` command that we run on our regular CI will fail when validating the `OpenCombineDispatch` and `OpenCombineFoundation` podspecs, since the dependencies are not yet in the trunk. If we set the dependencies to the previous version (which is already in the trunk), everything will be fine. This is purely to make the CI work. The clients will not experience any issues, since the version is specified as `>=`.
1. Create a pull request to master for the release branch and make sure the CI passes.
1. Merge the pull request.
1. In the GitHub web interface on the [releases](https://github.com/OpenCombine/OpenCombine/releases) page, click the **Draft a new release** button.
1. The **Tag version** and **Release title** fields should be filled with the version number.
1. The description of the release should be consistent with the previous releases. It is a good practice to divide the description into several sections: additions, bugfixes, known issues etc. Also, be sure to mention the nicknames of the contributors of the new release.
1. Publish the release.
1. Switch to the master branch and pull the changes.
1. Push the release to CocoaPods trunk. For that, execute the following commands:

    ```
    pod trunk push OpenCombine.podspec --verbose --allow-warnings
    pod trunk push OpenCombineDispatch.podspec --verbose --allow-warnings
    pod trunk push OpenCombineFoundation.podspec --verbose --allow-warnings
    ```
   
   Note that you need to be one of the owners of the pod for that.

#### GYB

Some publishers in OpenCombine (like `Publishers.MapKeyPath`, `Publishers.Merge`) exist in several
different flavors in order to support several arities. For example, there are also `Publishers.MapKeyPath2`
and `Publishers.MapKeyPath3`, which are very similar but different enough that Swift's type system
can't help us here (because there's no support for variadic generics). Maintaining multiple instances of
those generic types is tedious and error-prone (they can get out of sync), so we use the GYB tool for
generating those instances from a template.

GYB is a Python script that evaluates Python code written inside a template file, so it's very flexible —
templates can be arbitrarily complex. There is a good article about GYB on
[NSHipster](https://nshipster.com/swift-gyb/).

GYB is part of the [Swift Open Source Project](https://github.com/apple/swift/blob/master/utils/gyb.py)
and can be distributed under the same license as Swift itself.

GYB template files have the `.gyb` extension. Run `make gyb` to generate Swift code from those
templates. The generated files are prefixed with `GENERATED-`  and are checked into source control. Those
files should never be edited directly. Instead, the `.gyb` template should be edited, and after that the files
should be regenerated using `make gyb`.