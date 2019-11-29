//
//  EnumerateClassFieldsTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 29.11.2019.
//

import XCTest
import Foundation

#if !OPENCOMBINE_COMPATIBILITY_TEST

final class EnumerateClassFieldsTests: TestCase {

    func testNoFields() {
        enumerateFields(ofType: NoFields.self, allowResilientSuperclasses: true) { _ in
            XCTFail("should not be called")
            return false
        }
    }

    func testVarsAndLets() {
        var fields = [FieldInfo]()
        enumerateFields(ofType: VarsAndLets.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            if field.name == "stopEnumerating" {
                return false
            }
            return true
        }
        XCTAssertEqual(fields, [.init("constant1", 16, Int.self),
                                .init("constant2", 0, Void.self),
                                .init("variable1", 24, String.self),
                                .init("variable2", 40, Double.self),
                                .init("stopEnumerating", 48, Int.self)])
        if hasFailed { return }
        let instance = VarsAndLets()
        XCTAssertEqual(loadField(fields[0], from: instance, as: Int.self), 42)
        loadField(fields[1], from: instance, as: Void.self)
        XCTAssertEqual(loadField(fields[2], from: instance, as: String.self), "hello")
        XCTAssertEqual(loadField(fields[3], from: instance, as: Double.self), 12.3)
        XCTAssertEqual(loadField(fields[4], from: instance, as: Int.self), -1)

    }

    func testRegularDerivedClass() {
        var fields = [FieldInfo]()
        enumerateFields(ofType: RegularDerived.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            return true
        }
        XCTAssertEqual(fields, [.init("field1", 16, Int.self),
                                .init("field2", 24, Bool.self),
                                .init("field3", 25, Bool.self),
                                .init("field4", 32, String.self),
                                .init("field5", 48, Int.self)])
        if hasFailed { return }
        let instance = RegularDerived()
        XCTAssertEqual(loadField(fields[0], from: instance, as: Int.self), 1)
        XCTAssertEqual(loadField(fields[1], from: instance, as: Bool.self), false)
        XCTAssertEqual(loadField(fields[2], from: instance, as: Bool.self), true)
        XCTAssertEqual(loadField(fields[3], from: instance, as: String.self), "3")
        XCTAssertEqual(loadField(fields[4], from: instance, as: Int.self), 4)
    }

    func testRegularDerivedClassEarlyExit() {
        var fields = [FieldInfo]()
        enumerateFields(ofType: RegularDerived.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            if field.name == "field2" {
                return false
            }
            return true
        }
        XCTAssertEqual(fields, [.init("field1", 16, Int.self),
                                .init("field2", 24, Bool.self)])
    }

    func testObjCClass() {
        enumerateFields(ofType: NSNumber.self,
                        allowResilientSuperclasses: true) { _ in
            XCTFail("should not be called")
            return false
        }
    }

    func testSwiftSubclassOfObjCClass() {
        var fields = [FieldInfo]()
        enumerateFields(ofType: ObjCDerived.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            if field.name == "field2" {
                return false
            }
            return true
        }
        XCTAssertEqual(fields, [.init("field1", 8, Int.self),
                                .init("field2", 16, Bool.self)])
        if hasFailed { return }
        let instance = ObjCDerived()
        XCTAssertEqual(loadField(fields[0], from: instance, as: Int.self), 1)
        XCTAssertEqual(loadField(fields[1], from: instance, as: Bool.self), true)
    }

    func testNSObjectSubclass() {
        var fields = [FieldInfo]()
        enumerateFields(ofType: DerivedFromNSObject.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            return true
        }
        XCTAssertEqual(fields, [.init("field1", 8, Int.self),
                                .init("field2", 16, Bool.self),
                                .init("field3", 17, Bool.self)])
        if hasFailed { return }
        let instance = DerivedFromNSObject()
        XCTAssertEqual(loadField(fields[0], from: instance, as: Int.self), 1)
        XCTAssertEqual(loadField(fields[1], from: instance, as: Bool.self), true)
        XCTAssertEqual(loadField(fields[2], from: instance, as: Bool.self), false)
    }

    func testResilientClass() {
        var fields = [FieldInfo]()
        enumerateFields(ofType: JSONDecoder.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            return true
        }
        XCTAssertFalse(fields.isEmpty)
    }

    func testSubclassOfResilientClass() {
        enumerateFields(ofType: DerivedFromResilientClass.self,
                        allowResilientSuperclasses: false) { _ in
            XCTFail("should not be called")
            return true
        }

        var fields = [FieldInfo]()
        enumerateFields(ofType: DerivedFromResilientClass.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            return true
        }
        XCTAssertFalse(fields.isEmpty)
    }

    func testGenericClass() {
        var fields = [FieldInfo]()
        enumerateFields(ofType: GenericBase<String, Decimal>.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            return true
        }
        XCTAssertEqual(fields, [.init("field1", 16, String.self),
                                .init("field2", 32, Decimal.self)])
        if hasFailed { return }
        let instance = GenericBase<String, Decimal>("foo", 13.5)
        XCTAssertEqual(loadField(fields[0], from: instance, as: String.self), "foo")
        XCTAssertEqual(loadField(fields[1], from: instance, as: Decimal.self), 13.5)
    }

    func testGenericSubclassOfGenericClass() {
        var fields = [FieldInfo]()
        enumerateFields(ofType: GenericDerived<String, Int, Bool, [Int]>.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            return true
        }
        XCTAssertEqual(fields, [.init("field1", 16, String.self),
                                .init("field2", 32, Int.self),
                                .init("field3", 40, Bool.self),
                                .init("field4", 48, [Int].self)])
        if hasFailed { return }
        let instance = GenericDerived("foo", 42, true, [1, 2, 3])
        XCTAssertEqual(loadField(fields[0], from: instance, as: String.self), "foo")
        XCTAssertEqual(loadField(fields[1], from: instance, as: Int.self), 42)
        XCTAssertEqual(loadField(fields[2], from: instance, as: Bool.self), true)
        XCTAssertEqual(loadField(fields[3], from: instance, as: [Int].self), [1, 2, 3])
    }

    func testGenericSubclassOfNonGenericResilientClass() {
        enumerateFields(ofType: GenericDerivedFromResilientBase<Int, Int>.self,
                        allowResilientSuperclasses: false) { field in
            XCTFail("should not be called")
            return true
        }

        var superclassFields = [FieldInfo]()
        enumerateFields(ofType: JSONDecoder.self,
                        allowResilientSuperclasses: false) { field in
            superclassFields.append(field)
            return true
        }

        var fields = [FieldInfo]()
        enumerateFields(ofType: GenericDerivedFromResilientBase<Int, Int>.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            return true
        }
        XCTAssertEqual(fields, superclassFields + [.init("field1", 128, Int.self),
                                                   .init("field2", 136, Int.self)])
    }

    func testForeignClass() {
        enumerateFields(ofType: CFMutableArray.self,
                        allowResilientSuperclasses: true) { _ in
            XCTFail("should not be called")
            return true
        }
    }

    func testClassWithFieldsOfResilientTypes() {
        guard #available(macOS 10.12, iOS 10.0, *) else { return }
        var fields = [FieldInfo]()
        enumerateFields(ofType: HasResilientFields.self,
                        allowResilientSuperclasses: true) { field in
            fields.append(field)
            return true
        }
        XCTAssertEqual(fields, [.init("field1", 16, IndexPath.self),
                                .init("field2", 40, Measurement<UnitSpeed>.self),
                                .init("field3", 56, Bool.self)])
        if hasFailed { return }
        let instance = HasResilientFields()
        XCTAssertEqual(loadField(fields[0], from: instance, as: IndexPath.self), [42, 12])
        XCTAssertEqual(loadField(fields[1],
                                 from: instance,
                                 as: Measurement<UnitSpeed>.self),
                       Measurement<UnitSpeed>(value: 12, unit: .metersPerSecond))
        XCTAssertEqual(loadField(fields[2], from: instance, as: Bool.self), true)
    }
}

private func loadField<FieldType>(_ field: FieldInfo,
                                  from instance: AnyObject,
                                  as type: FieldType.Type,
                                  file: StaticString = #file,
                                  line: UInt = #line) -> FieldType? {
    if field.type != type {
        XCTFail("Type mismatch", file: file, line: line)
        return nil
    }
    return Unmanaged
        .passUnretained(instance)
        .toOpaque()
        .load(fromByteOffset: field.offset, as: type)
}

private final class NoFields {}

private final class VarsAndLets {
    let constant1 = 42
    let constant2: Void = ()
    var variable1 = "hello"
    var variable2 = 12.3
    let stopEnumerating = -1
    var neverVisited = 10
}

private class RegularBase {
    var field1 = 1
    var field2 = false
    var field3 = true
}

private final class RegularDerived: RegularBase {
    var field4 = "3"
    var field5 = 4
}

private final class ObjCDerived: NSOrderedSet {
    var field1 = 1
    var field2 = true
    let field3 = false
}

private final class DerivedFromNSObject: NSObject {
    var field1 = 1
    var field2 = true
    let field3 = false
}

private final class DerivedFromResilientClass: JSONDecoder {
    var field1 = 1
    var field2 = "hello"
}

private class GenericBase<A, B> {
    var field1: A
    var field2: B

    init(_ field1: A, _ field2: B) {
        self.field1 = field1
        self.field2 = field2
    }
}

private final class GenericDerived<A, B, C, D>: GenericBase<A, B> {
    var field3: C
    var field4: D

    init(_ field1: A, _ field2: B, _ field3: C, _ field4: D) {
        self.field3 = field3
        self.field4 = field4
        super.init(field1, field2)
    }
}

private class GenericDerivedFromResilientBase<A, B>: JSONDecoder {
    var field1: A
    var field2: B

    init(_ field1: A, _ field2: B) {
        self.field1 = field1
        self.field2 = field2
    }
}

@available(macOS 10.12, iOS 10.0, *)
private final class HasResilientFields {
    // Foundation.IndexPath is resilient struct
    var field1 = IndexPath(indexes: [42, 12])

    // Foundation.Measurement is resilient generic struct
    let field2 = Measurement<UnitSpeed>(value: 12, unit: .metersPerSecond)

    var field3 = true
}

#endif
