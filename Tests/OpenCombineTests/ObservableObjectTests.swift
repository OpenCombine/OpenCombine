//
//  ObservableObjectTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 26.10.2019.
//

#if swift(>=5.1)

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST

import Combine

@available(macOS 10.15, iOS 13.0, *)
private typealias ObservableObject = Combine.ObservableObject

@available(macOS 10.15, iOS 13.0, *)
private typealias Published = Combine.Published

#else

import OpenCombine

private typealias ObservableObject = OpenCombine.ObservableObject
private typealias Published = OpenCombine.Published

#endif

@available(macOS 10.15, iOS 13.0, *)
final class ObservableObjectTests: XCTestCase {

    var disposeBag = [AnyCancellable]()

    override func tearDown() {
        disposeBag = []
        super.tearDown()
    }

    func testNoFields() {
        let observableObject = NoFields()
        let publisher1 = observableObject.objectWillChange
        let publisher2 = observableObject.objectWillChange
        XCTAssert(publisher1 !== publisher2,
                  """
                  If there are no fields, objectWillChange property should return \
                  a new instance every time
                  """)
    }

    func testNoPublishedFields() {
        let observableObject = NoPublishedFields()
        let publisher1 = observableObject.objectWillChange
        let publisher2 = observableObject.objectWillChange
        XCTAssert(publisher1 !== publisher2,
                  """
                  If there are no @Published fields, objectWillChange property should \
                  return a new instance every time
                  """)
    }

    func testPublishedFieldIsConstant() {
        let observableObject = PublishedFieldIsConstant()

        let publisher1 = observableObject.objectWillChange
        let publisher2 = observableObject.objectWillChange

        XCTAssert(publisher1 === publisher2,
                  """
                  Even if the Published field is a constant, a publisher \
                  should be installed there.
                  """)
    }

    func testDerivedClassWithPublishedField() {
        let observableObject = ObservedDerivedWithObservedBase()

        var counter = 0

        observableObject.objectWillChange.sink { counter += 1 }.store(in: &disposeBag)

        XCTAssertEqual(observableObject.publishedValue0, 0)
        XCTAssertEqual(observableObject.simpleValue, "what")
        XCTAssertEqual(observableObject.subclassPublished0, 0)
        XCTAssertEqual(observableObject.subclassPublished1, 1)
        XCTAssertEqual(observableObject.subclassPublished2, 2)

        observableObject.publishedValue0 += 5

        XCTAssertEqual(counter, 1)
        XCTAssertEqual(observableObject.publishedValue0, 5)

        Published<String>[_enclosingInstance: observableObject,
                          wrapped: \.simpleValue,
                          storage: \.publishedValue1] += "???"

        XCTAssertEqual(counter, 2)
        XCTAssertEqual(observableObject.simpleValue, "what")

        observableObject.subclassPublished0 += 3

        XCTAssertEqual(counter, 3)
        XCTAssertEqual(observableObject.subclassPublished0, 3)

        observableObject.subclassPublished1 += 3

        XCTAssertEqual(counter, 4)
        XCTAssertEqual(observableObject.subclassPublished1, 4)

        observableObject.subclassPublished2 += 3

        XCTAssertEqual(counter, 5)
        XCTAssertEqual(observableObject.subclassPublished1, 4)
    }

    func testObjCClassRetroactiveConformance() {
        let observableObject = NSNumber(value: 42.0)
        let publisher1 = observableObject.objectWillChange
        let publisher2 = observableObject.objectWillChange
        XCTAssert(publisher1 !== publisher2,
                  """
                  For instances of Objective-C classes objectWillChange property should \
                  return a new instance every time
                  """)
    }

    func testObjCClassSubclass() {
        let observableObject = ObjCClassSubclass()
        let publisher1 = observableObject.objectWillChange
        let publisher2 = observableObject.objectWillChange
        XCTAssert(publisher1 === publisher2)
    }

    func testResilientClassSubclass() {
        let observableObject = ResilientClassSubclass()
        let publisher1 = observableObject.objectWillChange
        let publisher2 = observableObject.objectWillChange
#if canImport(Darwin)
        XCTAssert(publisher1 !== publisher2,
                  """
                  For subclasses of resilient classes objectWillChange property should \
                  return a new instance every time
                  """)
#else
        // There are no resilient classes on non-Darwin platforms.
        XCTAssert(publisher1 === publisher2)
#endif
    }

    func testResilientClassRetroactiveConformance() {
        let observableObject = JSONEncoder()
        let publisher1 = observableObject.objectWillChange
        let publisher2 = observableObject.objectWillChange
        XCTAssert(publisher1 !== publisher2,
                  """
                  For instances of resilient classes objectWillChange property should \
                  return a new instance every time
                  """)
    }

    // FIXME: This test crashes
//    func testGenericClass() {
//        let observableObject = GenericClass(123, true)
//
//        var counter = 0
//
//        observableObject.objectWillChange.sink { counter += 1 }.store(in: &disposeBag)
//        XCTAssertEqual(counter, 0)
//        XCTAssertEqual(observableObject.value1, 123)
//        XCTAssertEqual(observableObject.value2, true)
//
//        observableObject.value1 += 1
//
//        XCTAssertEqual(counter, 1)
//        XCTAssertEqual(observableObject.value1, 124)
//
//        observableObject.value2.toggle()
//
//        XCTAssertEqual(counter, 2)
//        XCTAssertEqual(observableObject.value2, false)
//    }

    func testObservableDerivedWithNonObservableBase() {
        let observableObject = ObservedDerivedWithNonObservedBase()
        var counter = 0
        observableObject.objectWillChange.sink { counter += 1 }.store(in: &disposeBag)

        XCTAssertEqual(counter, 0)
        XCTAssertEqual(observableObject.nonObservedBaseValue0, 10)
        XCTAssertEqual(observableObject.nonObservedBaseValue1, .pi)
        XCTAssertEqual(observableObject.observedDerivedValue2,
                       "Asuka is obviously the best girl.")
        XCTAssertEqual(observableObject.observedDerivedValue3, 255)

        observableObject.nonObservedBaseValue0 -= 1
        XCTAssertEqual(counter, 1)
        XCTAssertEqual(observableObject.nonObservedBaseValue0, 9)

        observableObject.nonObservedBaseValue1 *= 2
        XCTAssertEqual(counter, 2)
        XCTAssertEqual(observableObject.nonObservedBaseValue1, 2 * .pi)

        observableObject.observedDerivedValue2 = "Nevermind."
        XCTAssertEqual(counter, 3)
        XCTAssertEqual(observableObject.observedDerivedValue2, "Nevermind.")

        observableObject.observedDerivedValue3 &+= 1
        XCTAssertEqual(counter, 4)
        XCTAssertEqual(observableObject.observedDerivedValue3, 0)
    }

    func testNSObjectSubclass() {
        let observableObject = NSObjectSubclass()
        var counter = 0
        observableObject.objectWillChange.sink { counter += 1 }.store(in: &disposeBag)

        XCTAssertEqual(counter, 0)
        XCTAssertEqual(observableObject.value0, 0)
        XCTAssertEqual(observableObject.value1, 42)

        observableObject.value0 += 1
        XCTAssertEqual(counter, 1)
        XCTAssertEqual(observableObject.value0, 1)

        observableObject.value1 += 1
        XCTAssertEqual(counter, 2)
        XCTAssertEqual(observableObject.value1, 43)
    }
}

@available(macOS 10.15, iOS 13.0, *)
private final class NoFields: ObservableObject {}

@available(macOS 10.15, iOS 13.0, *)
private final class NoPublishedFields: ObservableObject {
    var field = NoFields()
    var int = 0
}

@available(macOS 10.15, iOS 13.0, *)
private final class PublishedFieldIsConstant: ObservableObject {
    let publishedValue = Published(initialValue: 42)
}

@available(macOS 10.15, iOS 13.0, *)
private class ObservedBase: ObservableObject {
    @Published var publishedValue0 = 0
    var publishedValue1 = Published(initialValue: "Hello!")
    let publishedValue2 = Published(initialValue: 42)
    var simpleValue = "what"
}

@available(macOS 10.15, iOS 13.0, *)
private final class ObservedDerivedWithObservedBase: ObservedBase {
    @Published var subclassPublished0 = 0
    @Published var subclassPublished1 = 1
    @Published var subclassPublished2 = 2
}

@available(macOS 10.15, iOS 13.0, *)
extension NSNumber: ObservableObject {}

@available(macOS 10.15, iOS 13.0, *)
private final class ObjCClassSubclass: NSOrderedSet, ObservableObject {
    @Published var published = 10
}

@available(macOS 10.15, iOS 13.0, *)
private final class ResilientClassSubclass: JSONDecoder, ObservableObject {
    @Published var published0 = 10
    @Published var published1 = "hello!"
}

@available(macOS 10.15, iOS 13.0, *)
extension JSONEncoder: ObservableObject {}

@available(macOS 10.15, iOS 13.0, *)
private final class GenericClass<Value1, Value2>: ObservableObject {
    @Published var value1: Value1
    @Published var value2: Value2

    init(_ value1: Value1, _ value2: Value2) {
        self.value1 = value1
        self.value2 = value2
    }
}

@available(macOS 10.15, iOS 13.0, *)
private class NonObservedBase {
    @Published var nonObservedBaseValue0 = 10
    @Published var nonObservedBaseValue1 = Double.pi
}

@available(macOS 10.15, iOS 13.0, *)
private class ObservedDerivedWithNonObservedBase: NonObservedBase, ObservableObject {
    @Published var observedDerivedValue2 = "Asuka is obviously the best girl."
    @Published var observedDerivedValue3: UInt8 = 255
}

@available(macOS 10.15, iOS 13.0, *)
private class NSObjectSubclass: NSObject, ObservableObject {
    @Published var value0 = 0
    @Published var value1: UInt8 = 42
}

#endif // swift(>=5.1)
