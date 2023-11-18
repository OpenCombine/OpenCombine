# ``OpenCombine``

Customize handling of asynchronous events by combining event-processing operators.

## Overview

Open-source implementation of Apple's [Combine](https://developer.apple.com/documentation/combine) framework for processing values over time.

The main goal of this project is to provide a compatible, reliable and efficient implementation which can be used on Apple's operating systems before macOS 10.15 and iOS 13, as well as Linux, Windows and WebAssembly.

The OpenCombine framework provides a declarative Swift API for processing values over time. These values can represent many kinds of asynchronous events. OpenCombine declares publishers to expose values that can change over time, and subscribers to receive those values from the publishers.
The ``Publisher`` protocol declares a type that can deliver a sequence of values over time. Publishers have operators to act on the values received from upstream publishers and republish them.
At the end of a chain of publishers, a ``Subscriber`` acts on elements as it receives them. Publishers only emit values when explicitly requested to do so by subscribers. This puts your subscriber code in control of how fast it receives events from the publishers it’s connected to.
Several Foundation types expose their functionality through publishers, including [Timer](https://developer.apple.com/documentation/foundation/timer), [NotificationCenter](https://developer.apple.com/documentation/foundation/notificationcenter), and [URLSession](https://developer.apple.com/documentation/foundation/urlsession). OpenCombine also provides a built-in publisher for any property that’s compliant with Key-Value Observing.
You can combine the output of multiple publishers and coordinate their interaction. For example, you can subscribe to updates from a text field’s publisher, and use the text to perform URL requests. You can then use another publisher to process the responses and use them to update your app.
By adopting OpenCombine, you’ll make your code easier to read and maintain, by centralizing your event-processing code and eliminating troublesome techniques like nested closures and convention-based callbacks.

## Topics

### Publishers

- ``Publisher``
- ``Publishers``
- ``AnyPublisher``
- ``Published-swift.struct``
- ``Cancellable``
- ``AnyCancellable``

### Convenience Publishers

- ``Future``
- ``Just``
- ``Deferred``
- ``Empty``
- ``Fail``
- ``Record``

### Connectable Publishers

- ``ConnectablePublisher``

### Subscribers

- ``Subscriber``
- ``Subscribers``
- ``AnySubscriber``
- ``Subscription``
- ``Subscriptions``

### Subjects

- ``Subject``
- ``CurrentValueSubject``
- ``PassthroughSubject``

### Schedulers

- ``Scheduler``
- ``ImmediateScheduler``
- ``SchedulerTimeIntervalConvertible``

### Observable Objects

- ``ObservableObject``
- ``ObservableObjectPublisher``

### Asynchronous Publishers

- ``AsyncPublisher``
- ``AsyncThrowingPublisher``

### Encoders and Decoders

- ``TopLevelEncoder``
- ``TopLevelDecoder``

### Debugging Identifiers

- ``CustomCombineIdentifierConvertible``
- ``CombineIdentifier``
