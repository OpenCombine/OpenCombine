# 0.12.0 (29 Jan 2021)

This release adds a new `OpenCombineShim` product that will conditionally re-export either
Combine on Apple platforms, or OpenCombine on other platforms. Additionally, `ObservableObject`
protocol is now available and working on all platforms.

A bug with `Timer(timeInterval:repeats:block:)` firing immediately not accounting for the passed
`timeInterval` is fixed.

**Merged pull requests:**

- Fix `Timer(timeInterval:repeats:block:)` not accounting `timeInterval` ([#196](https://github.com/OpenCombine/OpenCombine/pull/196)) via [@grigorye](https://github.com/grigorye)
- Add `OpenCombineShim` product for easier importing ([#197](https://github.com/OpenCombine/OpenCombine/pull/197)) via [@MaxDesiatov](https://github.com/MaxDesiatov)
- Implementation for `ObservableObject` with `Mirror` ([#201](https://github.com/OpenCombine/OpenCombine/pull/201)) via [@kateinoigakukun](https://github.com/kateinoigakukun)

# 0.11.0 (29 Oct 2020)

This release is compatible with Xcode 12.1.

### Additions
- `Publisher.assigned(to:)` method that accepts a `Published.Publisher`.
- New `Publisher.switchToLatest()` overloads.
- New `Publisher.flatMap(maxPublishers:_:)` overloads.
- `Optional.publisher` property.
- New `_Introspection` protocol that allows to track and explore the subscription graph and data flow.

### Bugfixes
- The project should now compile without warnings.
- The following entities have been updated to match the behavior of the newest Combine version:
  - `Subscribers.Assign`
  - `Publishers.Breakpoint`
  - `Publishers.Buffer`
  - `CombineIdentifier`
  - `Publishers.CompactMap`
  - `Publishers.Concatenate`
  - `Publishers.Debounce`
  - `Publishers.Delay`
  - `DispatchQueue.SchedulerTimeType.Stride`
  - `Publishers.Drop`
  - `Publishers.Encode`
  - `Publishers.Decode`
  - `Publishers.Filter`
  - `Publishers.HandleEvents`
  - `Publishers.IgnoreOutput`
  - `Publishers.MeasureInterval`
  - `OperationQueue` scheduler
  - `Published`
  - `Publishers.ReceiveOn`
  - `Publishers.ReplaceError`
  - `RunLoop scheduler`
  - `Publishers.Sequence`
  - `Subscribers.Sink`
  - `Publishers.SubscribeOn`
  - `Publishers.Timeout`
  - `Timer` publisher

### Known issues
- The default implementation of the `objectWillChange` requirement of the `ObservableObject` protocol is not available in Swift 5.1 and later.

# 0.10.2 (23 Oct 2020)

### Bugfixes
- Fixed a crash caused by recursive acquisition of a non-recursive lock in SubbjectSubscriber (#186, thanks @stuaustin for the bug report)

### Known issues
- The default implementation of the `objectWillChange` requirement of the `ObservableObject` protocol is not available in Swift 5.1 and later.

# 0.10.1 (4 Oct 2020)

### Bugfixes
- Fixed build errors on Linux with Swift 5.0 and Swift 5.3 toolchains (thanks, @adamleonard and @devmaximilian)

### Known issues
- The default implementation of the `objectWillChange` requirement of the `ObservableObject` protocol is not available in Swift 5.1 and later.

# 0.10.0 (28 Jun 2020)

This release is compatible with Xcode 11.5.

### Additions
- `Timer.publish(every:tolerance:on:in:options:)` (#156, thank you @MaxDesiatov)
- `OperationQueue` scheduler (#165)
- `Publishers.Timeout` (#164)
- `Publishers.Debounce` (#133)

### Bugfixes
- `PassthroughSubject`, `CurrentValueSubject` and `Future` have been rewritten from scratch. They are now faster, more correct and no longer leak subscriptions (#170).

### Known issues
- The default implementation of the `objectWillChange` requirement of the `ObservableObject` protocol is not available in Swift 5.1 and later.

# 0.9.0 (12 Jun 2020)

This release is compatible with Xcode 11.5.

### Additions
- The `Subscribers.Demand` struct can be nicely formatted in LLDB (#146, thank you @mayoff).
- `Publishers.SwitchToLatest` (#142).
- The `RunLoop` scheduler in `OpenCombineFoundation` (#131).
- `Publishers.Catch` and `Publishers.TryCatch` (#140).

### Bugfixes
- Worked around a [bug in the Swift compiler](https://bugs.swift.org/browse/SR-11680) when building the `COpenCombineHelpers` target (#145, thank you @mayoff).
- Improved documentation.

### Known issues
- The default implementation of the `objectWillChange` requirement of the `ObservableObject` protocol is not available in Swift 5.1 and later.

# 0.8.0 (17 Jan 2020)

This release is compatible with Xcode 11.3.1.

### Additions
- `Publishers.ReplaceEmpty` (#122, thank you @spadafiva)
- `NotificationCenter.Publisher` (#84)
- `URLSession.DataTaskPublisher` (#127)
- `Publishers.DropUntilOutput` (#136)
- `Publishers.CollectByCount` (#137)
- `Publishers.AssertNoFailure` (#138)
- `Publishers.Buffer` (#143)

### Bugfixes
- Fixed integer overflows in `DispatchQueue.SchedulerTimeType.Stride` (#126, #130)
- Fixed the 'default will never be executed' warning on non-Darwin platforms (like Linux) (#129)

### Known issues
- The default implementation of the `objectWillChange` requirement of the `ObservableObject` protocol is not available in Swift 5.1.

# 0.7.0 (10 Dec 2019)

This release is compatible with Xcode 11.2.1.

### Additions
- `Publishers.Delay` (#114)
- `Publishers.ReceiveOn` (#115)
- `Publishers.SubscribeOn` (#116)
- `Publishers.MeasureInterval` (#117)
- `Publishers.Breakpoint` (#118)
- `Publishers.HandleEvents` (#118)
- `Publishers.Concatenate` (#90)

### Known issues
- The default implementation of the `objectWillChange` requirement of the `ObservableObject` protocol is not available in Swift 5.1.

# 0.6.0 (26 Nov 2019)

This release is compatible with Xcode 11.2.1.

### Thread safety
- `Publishers.IgnoreOutput` has been audited for thread safety (#88)
- `Publishers.DropWhile` and `Publishers.TryDropWhile` have been audited for thread safety (#87)

### Additions
- `Publishers.Output` (#91)
- `Record` (#100)
- `Publishers.RemoveDuplicates`, `Publishers.TryRemoveDuplicates` (#89)
- `Publishers.PrefixWhile`, `Publishers.TryPrefixWhile` (#89)
- `Future` (#107, thanks @MaxDesiatov!)

### Bugfixes
- The behavior of the `Publishers.Encode` and `Publishers.Decode` subscriptions is fixed (#112)
- The behavior of the `Publishers.IgnoreOutput` subscription is fixed (#88)
- The behavior of the `Publishers.Print` subscription is fixed (#92)
- The behavior of the `Publishers.ReplaceError` subscription is fixed (#89)
- The behavior of the `Publishers.Filter` and `Publishers.TryFilter` subscriptions is fixed (#89)
- The behavior of the `Publishers.CompactMap` and `Publishers.TryCompactMap` subscriptions is fixed (#89)
- The behavior of the `Publishers.Multicast` subscription is fixed (#110)
- `Publishers.FlatMap` is reimplemented from scratch. Its behavior is fixed in many ways, it now fully matches that of Combine (#89)
- `@Published` property wrapper is fixed! (#112)
- The behavior of `DispatchQueue.SchedulerTimeType` is fixed to match that of the latest SDKs (#96)
- OpenCombine is now usable on 32 bit platforms. Why? Because we can.


### Known issues
- The default implementation of the `objectWillChange` requirement of the `ObservableObject` protocol is not available in Swift 5.1.

# 0.5.0 (17 Oct 2019)

This release is compatible with Xcode 11.1.

### Additions
- `Publishers.MapKeyPath` (#71)
- `Publishers.Reduce` (#76)
- `Publishers.TryReduce` (#76)
- `Publishers.Last` (#76)
- `Publishers.LastWhere` (#76)
- `Publishers.TryLastWhere` (#76)
- `Publishers.AllSatisfy` (#76)
- `Publishers.TryAllSatisfy` (#76)
- `Publishers.Contains` (#76)
- `Publishers.ContainsWhere` (#76)
- `Publishers.TryContainsWhere` (#76)
- `Publishers.Collect` (#76)
- `Publishers.Comparison` (#76)
- `Publishers.Drop` (#70, thank you @5sw!)
- `Publishers.Scan` (#83, thank you @epatey!)
- `Publishers.TryScan` (#83, thank you @epatey!)

### Bugfixes
- `Publishers.Print` doesn't print a redundant whitespace anymore.

### Known issues
- `@Published` property wrapper doesn't work yet

# 0.4.0 (8 Oct 2019)

This release is compatible with Xcode 11.1.

### Thread safety
- `SubjectSubscriber` (which is used when you subscribe a subject to a publisher) has been audited for thread-safety
- `Publishers.Multicast` has been audited for thread safety (#63)
- `Publishers.TryMap` has been audited for thread safety
- `Just` has been audited for thread safety
- `Optional.Publisher` has been audited for thread safety
- `Publishers.Sequence` has been audited for thread safety
- `Publishers.ReplaceError` has been audited for thread safety
- `Subscribers.Assign` has been audited for thread safety
- `Subscribers.Sink` has been audited for thread safety

### Bugfixes
- The semantics of `Publishers.Print`, `Publishers.TryMap` have been fixed
- Fix `iterator.next()` being called twice in `Publishers.Sequence` (#62)
- The default initializer of `CombineIdentifier` (the one that takes no arguments) is now much faster (#66, #69)
- When `Publishers.Sequence` subscription is cancelled while it emits values, the cancellation is respected (#73, thanks @5sw!)

### Additions
- `DispatchQueueScheduler` (#46)
- `Equatable` conformances for `First`, `ReplaceError`
- Added `eraseToAnyPublisher()` method (#59, thanks @evyasafhouzz for reporting!)
- `Publishers.MakeConnectable` (#61)
- `Publishers.Autoconnect` (#60)
- `Publishers.Share` (#60)

### Known issues
- `@Published` property wrapper doesn't work yet

# 0.3.0 (13 Sep 2019)

Among other things this release is compatible with Xcode 11.0 GM seed.

### Bugfixes
- Store newly send value in internal variable inside CurrentValueObject (#39, thanks @FranzBusch!)

### Additions
- `Filter`/`TryFilter` (#22, thanks @spadafiva!)
- `First`/`FirstWhere`/`TryFirstWhere` (#22, thanks again @spadafiva!)
- `CompactMap`/`TryCompacrMap` (#32)
- `IgnoreOutput` (#44, thanks @epatey!)
- `ReplaceError` (#50, thanks @vladiulianbogdan!)
- `FlatMap` (#45, thanks again @epatey!)

### Known issues
- `@Published` property wrapper doesn't work yet

# 0.2.0 (31 Jul 2019)

Updated for the newest Xcode 11.0 beta 5

# 0.1.0 (4 Jul 2019)

The first pre-pre-pre-alpha release is here!

Lots of stuff still unimplemented.

For now we have:

- `Just`
- `Publishers.Decode`
- `Publishers.DropWhile`
- `Publishers.Empty`
- `Publishers.Encode`
- `Publishers.Fail`
- `Publishers.Map`
- `Publishers.Multicast`
- `Publishers.Once`
- `Publishers.Optional`
- `Publishers.Print`
- `Publishers.Sequence`
- `Subscribers.Assign`
- `Subscribers.Completion`
- `Subscribers.Demand`
- `Subscribers.Sink`
- `AnyCancellable`
- `AnyPublisher`
- `AnySubject`
- `AnySubscriber`
- `Cancellable`
- `CombineIdentifier`
- `ConnectablePublisher`
- `CurrentValueSubject`
- `CustomCombineIdentifierConvertible`
- `ImmediateScheduler`
- `PassthroughSubject`
- `Publisher`
- `Result`
- `Scheduler`
- `Subject`
- `Subscriber`
- `Subscription`
