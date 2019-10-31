//
//  FieldDescriptor.h
//  
//
//  Created by Sergej Jaskiewicz on 30.10.2019.
//

#ifndef OPENCOMBINE_FIELD_DESCRIPTOR_H
#define OPENCOMBINE_FIELD_DESCRIPTOR_H

#include "RelativePointer.h"
#include "span.h"

#include <cstdint>
#include "string_view.h"

namespace opencombine {
namespace swift {

class Metadata;
class ContextDescriptor;

// This function is defined in the Swift runtime.
OPENCOMBINE_SWIFT_CALLING_CONVENTION
extern "C"
const Metadata *
swift_getTypeByMangledNameInContext(const char* typeNameStart,
                                    size_t typeNameLength,
                                    const ContextDescriptor* context,
                                    void const* const* genericArgs);

string_view makeSymbolicMangledNameStringRef(const char* base);

namespace reflection {

// Field records describe the type of a single stored property or case member
// of a class, struct or enum.
class FieldRecordFlags {
    using int_type = uint32_t;
    enum : int_type {
        // Is this an indirect enum case?
        IsIndirectCase = 0x1,

        // Is this a mutable `var` property?
        IsVar = 0x2,
    };
    int_type data = 0;

public:
    OPENCOMBINE_NO_CONSTRUCTORS(FieldRecordFlags)

    bool isIndirectCase() const {
        return (data & IsIndirectCase) == IsIndirectCase;
    }

    bool isVar() const {
        return (data & IsVar) == IsVar;
    }
};

enum class FieldDescriptorKind : uint16_t {
    // Swift nominal types.
    Struct,
    Class,
    Enum,

    // Fixed-size multi-payload enums have a special descriptor format that
    // encodes spare bits.
    //
    // For now, a descriptor with this kind
    // just means we also have a builtin descriptor from which we get the
    // size and alignment.
    MultiPayloadEnum,

    // A Swift opaque protocol. There are no fields, just a record for the
    // type itself.
    Protocol,

    // A Swift class-bound protocol.
    ClassProtocol,

    // An Objective-C protocol, which may be imported or defined in Swift.
    ObjCProtocol,

    // An Objective-C class, which may be imported or defined in Swift.
    // In the former case, field type metadata is not emitted, and
    // must be obtained from the Objective-C runtime.
    ObjCClass
};

struct FieldRecord {
    OPENCOMBINE_NO_CONSTRUCTORS(FieldRecord)

    bool hasMangledTypeName() const {
        return !mangledTypeName.isNull();
    }

    string_view getMangledTypeName() const {
        return makeSymbolicMangledNameStringRef(mangledTypeName.get());
    }

    string_view getFieldName() const {
        return fieldName.get();
    }

    const Metadata* getTypeMetadata(const ContextDescriptor* context) const {
        string_view mangledTypeName = getMangledTypeName();

        // FIXME: the last argument shouldn't be nullptr
        return swift_getTypeByMangledNameInContext(mangledTypeName.data(),
                                                   mangledTypeName.size(),
                                                   context,
                                                   nullptr);
    }

    bool isIndirectCase() const {
        return flags.isIndirectCase();
    }

private:
    const FieldRecordFlags flags;
    const RelativeDirectPointer<const char> mangledTypeName;
    const RelativeDirectPointer<const char> fieldName;
};

struct FieldRecordIterator {
    FieldRecordIterator(const FieldRecord* current, const FieldRecord* end)
        : current(current), end(end) {}

    const FieldRecord& operator*() const {
        return *current;
    }

    const FieldRecord* operator->() const {
        return current;
    }

    FieldRecordIterator& operator++() {
        ++current;
        return *this;
    }

    bool operator==(const FieldRecordIterator& other) const {
        return current == other.current && end == other.end;
    }

    bool operator!=(const FieldRecordIterator& other) const {
        return !(*this == other);
    }
private:
    const FieldRecord* current;
    const FieldRecord* const end;
};

// Field descriptors contain a collection of field records for a single
// class, struct or enum declaration.
class FieldDescriptor {
    const FieldRecord* getFieldRecordBuffer() const {
        return reinterpret_cast<const FieldRecord *>(this + 1);
    }
public:
    OPENCOMBINE_NO_CONSTRUCTORS(FieldDescriptor)

    using const_iterator = FieldRecordIterator;

    bool isEnum() const {
        return (kind == FieldDescriptorKind::Enum ||
                kind == FieldDescriptorKind::MultiPayloadEnum);
    }

    bool isClass() const {
        return (kind == FieldDescriptorKind::Class ||
                kind == FieldDescriptorKind::ObjCClass);
    }

    bool isProtocol() const {
        return (kind == FieldDescriptorKind::Protocol ||
                kind == FieldDescriptorKind::ClassProtocol ||
                kind == FieldDescriptorKind::ObjCProtocol);
    }

    bool isStruct() const {
        return kind == FieldDescriptorKind::Struct;
    }

    const_iterator begin() const {
        auto begin = getFieldRecordBuffer();
        auto end = begin + numFields;
        return const_iterator { begin, end };
    }

    const_iterator end() const {
        auto Begin = getFieldRecordBuffer();
        auto End = Begin + numFields;
        return const_iterator { End, End };
    }

    span<const FieldRecord> getFields() const {
        return {getFieldRecordBuffer(), numFields};
    }

    bool hasMangledTypeName() const {
        return !mangledTypeName.isNull();
    }

    string_view getMangledTypeName() const {
        return makeSymbolicMangledNameStringRef(mangledTypeName.get());
    }

    bool hasSuperclass() const {
        return !superclass.isNull();
    }

    string_view getSuperclass() const {
        return makeSymbolicMangledNameStringRef(superclass.get());
    }
private:
    const RelativeDirectPointer<const char> mangledTypeName;
    const RelativeDirectPointer<const char> superclass;
    const FieldDescriptorKind kind;
    const uint16_t fieldRecordSize;
    const uint32_t numFields;
};

} // end namespace reflection
} // end namespace swift
} // end namespace opencombine

#endif /* OPENCOMBINE_FIELD_DESCRIPTOR_H */
