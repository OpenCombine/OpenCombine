//
//  TypeMetadata.hpp
//  
//
//  Created by Sergej Jaskiewicz on 25.10.2019.
//

// The contents of this file is partially taken from
// https://github.com/apple/swift/blob/master/include/swift/ABI/Metadata.h
// and must be updated accordingly.

#ifndef OPENCOMBINE_TYPE_METADATA_H
#define OPENCOMBINE_TYPE_METADATA_H

#define OPENCOMBINE_NO_CONSTRUCTORS(type_name)                                           \
    type_name(const type_name&) = delete;                                                \
    type_name& operator=(const type_name&) = delete;                                     \
    type_name(type_name&&) = delete;                                                     \
    type_name& operator=(type_name&&) = delete;

#if __has_attribute(swiftcall)
# define OPENCOMBINE_SWIFT_CALLING_CONVENTION __attribute__((swiftcall))
#else
# define OPENCOMBINE_SWIFT_CALLING_CONVENTION
#endif

#include "FieldDescriptor.h"
#include "RelativePointer.h"
#include "FlagSet.h"

#include <atomic>
#include <cstdint>
#include <cstddef>

namespace opencombine {

namespace swift {

/// A "full" metadata pointer is simply an adjusted address point on a
/// metadata object; it points to the beginning of the metadata's
/// allocation, rather than to the canonical address point of the
/// metadata object.
template <class T> struct FullMetadata : T::HeaderType, T {
    using HeaderType = typename T::HeaderType;
    FullMetadata() = default;
    FullMetadata(const HeaderType &header, const T &metadata)
        : HeaderType(header), T(metadata) {}
};

// MARK: - Type metadata kinds and flags

/// Non-type metadata kinds have this bit set.
const unsigned MetadataKindIsNonType = 0x400;

/// Non-heap metadata kinds have this bit set.
const unsigned MetadataKindIsNonHeap = 0x200;

// The above two flags are negative because the "class" kind has to be zero,
// and class metadata is both type and heap metadata.

/// Runtime-private metadata has this bit set. The compiler must not statically
/// generate metadata objects with these kinds, and external tools should not
/// rely on the stability of these values or the precise binary layout of
/// their associated data structures.
const unsigned MetadataKindIsRuntimePrivate = 0x100;

/// Kinds of Swift metadata records.  Some of these are types, some
/// aren't.
enum class MetadataKind : uint32_t {
#define METADATAKIND(name, value) name = value,
#define ABSTRACTMETADATAKIND(name, start, end)                                           \
name##_Start = start, name##_End = end,
#include "MetadataKind.def"

    /// The largest possible non-isa-pointer metadata kind value.
    ///
    /// This is included in the enumeration to prevent against attempts to
    /// exhaustively match metadata kinds. Future Swift runtimes or compilers
    /// may introduce new metadata kinds, so for forward compatibility, the
    /// runtime must tolerate metadata with unknown kinds.
    /// This specific value is not mapped to a valid metadata kind at this time,
    /// however.
    LastEnumerated = 0x7FF,
};

const unsigned LastEnumeratedMetadataKind =
static_cast<unsigned>(MetadataKind::LastEnumerated);

/// Swift class flags.
/// These flags are valid only when isTypeMetadata().
/// When !isTypeMetadata() these flags will collide with other Swift ABIs.
enum class ClassFlags : uint32_t {
    /// Is this a Swift class from the Darwin pre-stable ABI?
    /// This bit is clear in stable ABI Swift classes.
    /// The Objective-C runtime also reads this bit.
    IsSwiftPreStableABI = 0x1,

    /// Does this class use Swift refcounting?
    UsesSwiftRefcounting = 0x2,

    /// Has this class a custom name, specified with the @objc attribute?
    HasCustomObjCName = 0x4
};

struct Metadata;
struct HeapMetadata;
struct AnyClassMetadata;
struct ClassMetadata;

struct ContextDescriptor;
struct TypeContextDescriptor;
struct ClassDescriptor;

// MARK: - Type metadata objects

/// The common structure of all type metadata.
struct Metadata {
    OPENCOMBINE_NO_CONSTRUCTORS(Metadata)

    /// Get the metadata kind.
    MetadataKind getKind() const {
        return kindOrISA > LastEnumeratedMetadataKind
        ? MetadataKind::Class
        : MetadataKind(kindOrISA);
    }

    /// Is this a class object--the metadata record for a Swift class (which also
    /// serves as the class object), or the class object for an ObjC class (which
    /// is not metadata)?
    bool isClassObject() const {
        return getKind() == MetadataKind::Class;
    }
private:
    /// The kind. Only valid for non-class metadata; getKind() must be used to get
    /// the kind value.
    uintptr_t kindOrISA;
};

/// The prefix on a heap metadata.
struct HeapMetadataHeaderPrefix {
  /// Destroy the object, returning the allocated size of the object
  /// or 0 if the object shouldn't be deallocated.
  void* destroy;
};

/// The header before a metadata object which appears on all type
/// metadata.  Note that heap metadata are not necessarily type
/// metadata, even for objects of a heap type: for example, objects of
/// Objective-C type possess a form of heap metadata (an Objective-C
/// Class pointer), but this metadata lacks the type metadata header.
/// This case can be distinguished using the isTypeMetadata() flag
/// on ClassMetadata.
struct TypeMetadataHeader {
  /// A pointer to the value-witnesses for this type.  This is only
  /// present for type metadata.
  void* valueWitnesses;
};

/// The header present on all heap metadata.
struct HeapMetadataHeader : HeapMetadataHeaderPrefix, TypeMetadataHeader {
    HeapMetadataHeader(const HeapMetadataHeaderPrefix& heapPrefix,
                       const TypeMetadataHeader& typePrefix)
        : HeapMetadataHeaderPrefix(heapPrefix),
          TypeMetadataHeader(typePrefix) {}
};

/// The common structure of all metadata for heap-allocated types. A
/// pointer to one of these can be retrieved by loading the 'isa'
/// field of any heap object, whether it was managed by Swift or by
/// Objective-C.  However, when loading from an Objective-C object,
/// this metadata may not have the heap-metadata header, and it may
/// not be the Swift type metadata for the object's dynamic type.
struct HeapMetadata : Metadata {
    OPENCOMBINE_NO_CONSTRUCTORS(HeapMetadata)

    using HeaderType = HeapMetadataHeader;
};

/// The portion of a class metadata object that is compatible with
/// all classes, even non-Swift ones.
struct AnyClassMetadata : HeapMetadata {
    OPENCOMBINE_NO_CONSTRUCTORS(AnyClassMetadata)

    /// Is this object a valid swift type metadata?  That is, can it be
    /// safely downcast to ClassMetadata?
    bool isTypeMetadata() const {
        return data & 2ULL;
    }
    /// A different perspective on the same bit
    bool isPureObjC() const {
      return !isTypeMetadata();
    }

    const ClassMetadata* getSuperclass() const { return superclass; }
private:
    // Note that ObjC classes does not have a metadata header.

    /// The metadata for the superclass.  This is null for the root class.
    const ClassMetadata* superclass;

    /// The cache data is used for certain dynamic lookups; it is owned
    /// by the runtime and generally needs to interoperate with
    /// Objective-C's use.
    void* cacheData[2];

    /// The data pointer is used for out-of-line metadata and is
    /// generally opaque, except that the compiler sets the low bit in
    /// order to indicate that this is a Swift metatype and therefore
    /// that the type metadata header is present.
    size_t data;
};

static inline unsigned getFieldOffsetVectorOffset(const ClassDescriptor* description);

static inline size_t fullClassMetadataHeaderSize();

static inline size_t fullClassMetadataSize();

/// Bounds for metadata objects.
struct MetadataBounds {

    /// The negative extent of the metadata, in words.
    uint32_t negativeSizeInWords;

    /// The positive extent of the metadata, in words.
    uint32_t positiveSizeInWords;
};

struct ClassMetadataBounds : public MetadataBounds {
    /// The offset from the address point of the metadata to the immediate
    /// members.
    ptrdiff_t immediateMembersOffset;

    ClassMetadataBounds() = default;
    ClassMetadataBounds(ptrdiff_t immediateMembersOffset,
                        uint32_t negativeSizeInWords,
                        uint32_t positiveSizeInWords)
        : MetadataBounds{negativeSizeInWords, positiveSizeInWords},
          immediateMembersOffset(immediateMembersOffset) {}

    /// Return the basic bounds of all Swift class metadata.
    /// The immediate members offset will not be meaningful.
    static ClassMetadataBounds forSwiftRootClass() {
        return forAddressPointAndSize(fullClassMetadataHeaderSize(),
                                      fullClassMetadataSize());
    }

    /// Return the bounds of a Swift class metadata with the given address
    /// point and size (both in bytes).
    /// The immediate members offset will not be meaningful.
    static ClassMetadataBounds
    forAddressPointAndSize(uintptr_t addressPoint, uintptr_t totalSize) {
        return {
            // Immediate offset in bytes.
            ptrdiff_t(totalSize - addressPoint),
            // Negative size in words.
            uint32_t(addressPoint / sizeof(uintptr_t)),
            // Positive size in words.
            uint32_t((totalSize - addressPoint) / sizeof(uintptr_t))
        };
    }

    /// Adjust these bounds for a subclass with the given immediate-members
    /// section.
    void adjustForSubclass(bool areImmediateMembersNegative,
                           uint32_t numImmediateMembers) {
        if (areImmediateMembersNegative) {
            negativeSizeInWords += numImmediateMembers;
            immediateMembersOffset =
            -ptrdiff_t(negativeSizeInWords) * sizeof(uintptr_t);
        } else {
            immediateMembersOffset = positiveSizeInWords * sizeof(uintptr_t);
            positiveSizeInWords += numImmediateMembers;
        }
    }
};

/// The structure of all class metadata.  This structure is embedded
/// directly within the class's heap metadata structure and therefore
/// cannot be extended without an ABI break.
///
/// Note that the layout of this type is compatible with the layout of
/// an Objective-C class.
struct ClassMetadata : AnyClassMetadata {
    OPENCOMBINE_NO_CONSTRUCTORS(ClassMetadata)

    const ClassDescriptor* getDescription() const {
        return description;
    }

    /// Get a pointer to the field offset vector, if present, or null.
    const uintptr_t* getFieldOffsets() const {
        assert(isTypeMetadata());
        auto offset = getFieldOffsetVectorOffset(getDescription());
        if (offset == 0) {
            return nullptr;
        }
        auto asWords = reinterpret_cast<const void * const*>(this);
        return reinterpret_cast<const uintptr_t*>(asWords + offset);
    }

    uintptr_t getClassSize() const {
        assert(isTypeMetadata());
        return classSize;
    }

    uintptr_t getClassAddressPoint() const {
        assert(isTypeMetadata());
        return classAddressPoint;
    }

    /// Given that this class is serving as the superclass of a Swift class,
    /// return its bounds as metadata.
    ///
    /// Note that the ImmediateMembersOffset member will not be meaningful.
    ClassMetadataBounds
    getClassBoundsAsSwiftSuperclass() const {

        auto rootBounds = ClassMetadataBounds::forSwiftRootClass();

        // If the class is not type metadata, just use the root-class bounds.
        if (!isTypeMetadata())
            return rootBounds;

        // Otherwise, pull out the bounds from the metadata.
        auto bounds = ClassMetadataBounds::forAddressPointAndSize(getClassAddressPoint(),
                                                                  getClassSize());

        // Round the bounds up to the required dimensions.
        if (bounds.negativeSizeInWords < rootBounds.negativeSizeInWords) {
            bounds.negativeSizeInWords = rootBounds.negativeSizeInWords;
        }
        if (bounds.positiveSizeInWords < rootBounds.positiveSizeInWords) {
            bounds.positiveSizeInWords = rootBounds.positiveSizeInWords;
        }
        return bounds;
    }
private:
    /// Swift-specific class flags.
    ClassFlags flags;

    /// The address point of instances of this type.
    uint32_t instanceAddressPoint;

    /// The required size of instances of this type.
    /// 'InstanceAddressPoint' bytes go before the address point;
    /// 'InstanceSize - InstanceAddressPoint' bytes go after it.
    uint32_t instanceSize;

    /// The alignment mask of the address point of instances of this type.
    uint16_t instanceAlignMask;

    /// Reserved for runtime use.
    uint16_t reserved;

    /// The total size of the class object, including prefix and suffix
    /// extents.
    uint32_t classSize;

    /// The offset of the address point within the class object.
    uint32_t classAddressPoint;

    /// An out-of-line Swift-specific description of the type, or null
    /// if this is an artificial subclass.  We currently provide no
    /// supported mechanism for making a non-artificial subclass
    /// dynamically.
    const ClassDescriptor* description;

    /// A function for destroying instance variables, used to clean up after an
    /// early return from a constructor. If null, no clean up will be performed
    /// and all ivars must be trivial.
    void* ivarDestroyer;
};

struct ContextDescriptor;
class ClassDescriptor;

using RelativeContextPointer = RelativeIndirectablePointer<const ContextDescriptor,
                                                           /*nullable*/ true>;

// MARK: - Context descriptor flags and kinds

/// Kinds of type metadata/protocol conformance records.
enum class TypeReferenceKind : unsigned {
  /// The conformance is for a nominal type referenced directly;
  /// getTypeDescriptor() points to the type context descriptor.
  DirectTypeDescriptor = 0x00,

  /// The conformance is for a nominal type referenced indirectly;
  /// getTypeDescriptor() points to the type context descriptor.
  IndirectTypeDescriptor = 0x01,

  /// The conformance is for an Objective-C class that should be looked up
  /// by class name.
  DirectObjCClassName = 0x02,

  /// The conformance is for an Objective-C class that has no nominal type
  /// descriptor.
  /// getIndirectObjCClass() points to a variable that contains the pointer to
  /// the class object, which then requires a runtime call to get metadata.
  ///
  /// On platforms without Objective-C interoperability, this case is
  /// unused.
  IndirectObjCClass = 0x03,

  // We only reserve three bits for this in the various places we store it.

  First_Kind = DirectTypeDescriptor,
  Last_Kind = IndirectObjCClass,
};


/// Kinds of context descriptor.
enum class ContextDescriptorKind : uint8_t {
    /// This context descriptor represents a module.
    Module = 0,

    /// This context descriptor represents an extension.
    Extension = 1,

    /// This context descriptor represents an anonymous possibly-generic context
    /// such as a function body.
    Anonymous = 2,

    /// This context descriptor represents a protocol context.
    Protocol = 3,

    /// This context descriptor represents an opaque type alias.
    OpaqueType = 4,

    /// First kind that represents a type of any sort.
    Type_First = 16,

    /// This context descriptor represents a class.
    Class = Type_First,

    /// This context descriptor represents a struct.
    Struct = Type_First + 1,

    /// This context descriptor represents an enum.
    Enum = Type_First + 2,

    /// Last kind that represents a type of any sort.
    Type_Last = 31,
};

/// Common flags stored in the first 32-bit word of any context descriptor.
struct ContextDescriptorFlags {
    OPENCOMBINE_NO_CONSTRUCTORS(ContextDescriptorFlags)

    /// The kind of context this descriptor describes.
    constexpr ContextDescriptorKind getKind() const {
        return ContextDescriptorKind(value & 0x1Fu);
    }

    /// Whether the context being described is generic.
    constexpr bool isGeneric() const {
        return (value & 0x80u) != 0;
    }

    /// Whether this is a unique record describing the referenced context.
    constexpr bool isUnique() const {
        return (value & 0x40u) != 0;
    }

    /// The format version of the descriptor. Higher version numbers may have
    /// additional fields that aren't present in older versions.
    constexpr uint8_t getVersion() const {
        return (value >> 8u) & 0xFFu;
    }

    /// The most significant two bytes of the flags word, which can have
    /// kind-specific meaning.
    constexpr uint16_t getKindSpecificFlags() const {
        return (value >> 16u) & 0xFFFFu;
    }
private:
    uint32_t value;
};

/// Flags for nominal type context descriptors. These values are used as the
/// kindSpecificFlags of the ContextDescriptorFlags for the type.
class TypeContextDescriptorFlags : public FlagSet<uint16_t> {
  enum {
    // All of these values are bit offsets or widths.
    // Generic flags build upwards from 0.
    // Type-specific flags build downwards from 15.

    /// Whether there's something unusual about how the metadata is
    /// initialized.
    ///
    /// Meaningful for all type-descriptor kinds.
    MetadataInitialization = 0,
    MetadataInitialization_width = 2,

    /// Set if the type has extended import information.
    ///
    /// If true, a sequence of strings follow the null terminator in the
    /// descriptor, terminated by an empty string (i.e. by two null
    /// terminators in a row).  See TypeImportInfo for the details of
    /// these strings and the order in which they appear.
    ///
    /// Meaningful for all type-descriptor kinds.
    HasImportInfo = 2,

    // Type-specific flags:

    /// The kind of reference that this class makes to its resilient superclass
    /// descriptor.  A TypeReferenceKind.
    ///
    /// Only meaningful for class descriptors.
    Class_ResilientSuperclassReferenceKind = 9,
    Class_ResilientSuperclassReferenceKind_width = 3,

    /// Whether the immediate class members in this metadata are allocated
    /// at negative offsets.  For now, we don't use this.
    Class_AreImmediateMembersNegative = 12,

    /// Set if the context descriptor is for a class with resilient ancestry.
    ///
    /// Only meaningful for class descriptors.
    Class_HasResilientSuperclass = 13,

    /// Set if the context descriptor includes metadata for dynamically
    /// installing method overrides at metadata instantiation time.
    Class_HasOverrideTable = 14,

    /// Set if the context descriptor includes metadata for dynamically
    /// constructing a class's vtables at metadata instantiation time.
    ///
    /// Only meaningful for class descriptors.
    Class_HasVTable = 15,
  };

public:
  explicit TypeContextDescriptorFlags(uint16_t bits) : FlagSet(bits) {}
  constexpr TypeContextDescriptorFlags() {}

  enum MetadataInitializationKind {
    /// There are either no special rules for initializing the metadata
    /// or the metadata is generic.  (Genericity is set in the
    /// non-kind-specific descriptor flags.)
    NoMetadataInitialization = 0,

    /// The type requires non-trivial singleton initialization using the
    /// "in-place" code pattern.
    SingletonMetadataInitialization = 1,

    /// The type requires non-trivial singleton initialization using the
    /// "foreign" code pattern.
    ForeignMetadataInitialization = 2,

    // We only have two bits here, so if you add a third special kind,
    // include more flag bits in its out-of-line storage.
  };

  FLAGSET_DEFINE_FIELD_ACCESSORS(MetadataInitialization,
                                 MetadataInitialization_width,
                                 MetadataInitializationKind,
                                 getMetadataInitialization,
                                 setMetadataInitialization)

  bool hasSingletonMetadataInitialization() const {
    return getMetadataInitialization() == SingletonMetadataInitialization;
  }

  bool hasForeignMetadataInitialization() const {
    return getMetadataInitialization() == ForeignMetadataInitialization;
  }

  FLAGSET_DEFINE_FLAG_ACCESSORS(HasImportInfo, hasImportInfo, setHasImportInfo)

  FLAGSET_DEFINE_FLAG_ACCESSORS(Class_HasVTable,
                                class_hasVTable,
                                class_setHasVTable)
  FLAGSET_DEFINE_FLAG_ACCESSORS(Class_HasOverrideTable,
                                class_hasOverrideTable,
                                class_setHasOverrideTable)
  FLAGSET_DEFINE_FLAG_ACCESSORS(Class_HasResilientSuperclass,
                                class_hasResilientSuperclass,
                                class_setHasResilientSuperclass)
  FLAGSET_DEFINE_FLAG_ACCESSORS(Class_AreImmediateMembersNegative,
                                class_areImmediateMembersNegative,
                                class_setAreImmediateMembersNegative)

  FLAGSET_DEFINE_FIELD_ACCESSORS(Class_ResilientSuperclassReferenceKind,
                                 Class_ResilientSuperclassReferenceKind_width,
                                 TypeReferenceKind,
                                 class_getResilientSuperclassReferenceKind,
                                 class_setResilientSuperclassReferenceKind)
};

/// Extra flags for resilient classes, since we need more than 16 bits of
/// flags there.
class ExtraClassDescriptorFlags : public FlagSet<uint32_t> {
  enum {
    /// Set if the context descriptor includes a pointer to an Objective-C
    /// resilient class stub structure. See the description of
    /// TargetObjCResilientClassStubInfo in Metadata.h for details.
    ///
    /// Only meaningful for class descriptors when Objective-C interop is
    /// enabled.
    HasObjCResilientClassStub = 0,
  };

public:
  explicit ExtraClassDescriptorFlags(uint32_t bits) : FlagSet(bits) {}
  constexpr ExtraClassDescriptorFlags() {}

  FLAGSET_DEFINE_FLAG_ACCESSORS(HasObjCResilientClassStub,
                                hasObjCResilientClassStub,
                                setObjCResilientClassStub)
};

// MARK: - Context descriptor classes

struct ContextDescriptor {
    OPENCOMBINE_NO_CONSTRUCTORS(ContextDescriptor)
protected:
    /// Flags describing the context, including its kind and format version.
    ContextDescriptorFlags flags;

    /// The parent context, or null if this is a top-level context.
    RelativeContextPointer parent;
};

struct TypeContextDescriptor : ContextDescriptor {
    OPENCOMBINE_NO_CONSTRUCTORS(TypeContextDescriptor)

    const reflection::FieldDescriptor* getFields() const {
        return fields.get();
    }

    const char* getName() const { return name.get(); }
private:
    /// The name of the type.
    RelativeDirectPointer<const char, /*nullable*/ false> name;

    /// A pointer to the metadata access function for this type.
    ///
    /// The function type here is a stand-in. You should use getAccessFunction()
    /// to wrap the function pointer in an accessor that uses the proper calling
    /// convention for a given number of arguments.
    RelativeDirectPointer<void, /*nullable*/ true> accessFunctionPtr;

    /// A pointer to the field descriptor for the type, if any.
    RelativeDirectPointer<const reflection::FieldDescriptor, /*nullable*/ true> fields;
};

class StoredClassMetadataBounds {
    OPENCOMBINE_NO_CONSTRUCTORS(StoredClassMetadataBounds)

    /// The offset to the immediate members.  This value is in bytes so that
    /// clients don't have to sign-extend it.


    /// It is not necessary to use atomic-ordered loads when accessing this
    /// variable just to read the immediate-members offset when drilling to
    /// the immediate members of an already-allocated metadata object.
    /// The proper initialization of this variable is always ordered before
    /// any allocation of metadata for this class.
    std::atomic<ptrdiff_t> immediateMembersOffset;

    /// The positive and negative bounds of the class metadata.
    MetadataBounds bounds;
public:

    /// Attempt to read the cached immediate-members offset.
    ///
    /// \return true if the read was successful, or false if the cache hasn't
    ///   been filled yet
    bool tryGetImmediateMembersOffset(ptrdiff_t &output) {
      output = immediateMembersOffset.load(std::memory_order_relaxed);
      return output != 0;
    }

    /// Attempt to read the full cached bounds.
    ///
    /// \return true if the read was successful, or false if the cache hasn't
    ///   been filled yet
    bool tryGet(ClassMetadataBounds& output) {
      auto offset = immediateMembersOffset.load(std::memory_order_acquire);
      if (offset == 0) return false;

      output.immediateMembersOffset = offset;
      output.negativeSizeInWords = bounds.negativeSizeInWords;
      output.positiveSizeInWords = bounds.positiveSizeInWords;
      return true;
    }

    void initialize(ClassMetadataBounds value) {
      assert(value.immediateMembersOffset != 0 &&
             "attempting to initialize metadata bounds cache to a zero state!");

        bounds.negativeSizeInWords = value.negativeSizeInWords;
        bounds.positiveSizeInWords = value.positiveSizeInWords;
        immediateMembersOffset.store(value.immediateMembersOffset,
                                     std::memory_order_release);
    }
};

struct ResilientSuperclass {
  /// The superclass of this class.  This pointer can be interpreted
  /// using the superclass reference kind stored in the type context
  /// descriptor flags.  It is null if the class has no formal superclass.
  ///
  /// Note that SwiftObject, the implicit superclass of all Swift root
  /// classes when building with ObjC compatibility, does not appear here.
  RelativeDirectPointer<const void, /*nullable*/true> superclass;
};

struct ClassDescriptor final : TypeContextDescriptor {
    OPENCOMBINE_NO_CONSTRUCTORS(ClassDescriptor)

    friend int32_t getResilientImmediateMembersOffset(const ClassDescriptor*);

    friend ClassMetadataBounds getResilientMetadataBounds(const ClassDescriptor*);

    TypeContextDescriptorFlags getTypeContextDescriptorFlags() const {
        return TypeContextDescriptorFlags(flags.getKindSpecificFlags());
    }

    bool hasResilientSuperclass() const {
        return getTypeContextDescriptorFlags().class_hasResilientSuperclass();
    }

    /// True if metadata records for this type have a field offset vector for
    /// its stored properties.
    bool hasFieldOffsetVector() const { return fieldOffsetVectorOffset != 0; }

    /// Are the immediate members of the class metadata allocated at negative
    /// offsets instead of positive?
    bool areImmediateMembersNegative() const {
      return getTypeContextDescriptorFlags().class_areImmediateMembersNegative();
    }

    /// Return the bounds of this class's metadata.
    ClassMetadataBounds getMetadataBounds() const {
        if (!hasResilientSuperclass()) {
            return getNonResilientMetadataBounds();
        }

        // This lookup works by ADL and will intentionally fail for
        // non-InProcess instantiations.
        return getResilientMetadataBounds(this);
    }

    /// Given that this class is known to not have a resilient superclass
    /// return its metadata bounds.
    ClassMetadataBounds getNonResilientMetadataBounds() const {
      return { getNonResilientImmediateMembersOffset() * uint32_t(sizeof(void*)),
               metadataNegativeSizeInWords,
               metadataPositiveSizeInWords };
    }

    /// Given that this class is known to not have a resilient superclass,
    /// return the offset of its immediate members in words.
    int32_t getNonResilientImmediateMembersOffset() const {
      assert(!hasResilientSuperclass());
      return areImmediateMembersNegative()
               ? -int32_t(metadataNegativeSizeInWords)
               : int32_t(metadataPositiveSizeInWords - numImmediateMembers);
    }

    /// Given that this class is known to not have a resilient superclass,
    /// return the offset of its generic arguments in words.
    int32_t getNonResilientGenericArgumentOffset() const {
      return getNonResilientImmediateMembersOffset();
    }

    const RelativeDirectPointer<const void, /*nullable*/true>&
    getResilientSuperclass() const {
      assert(hasResilientSuperclass());
        // TODO
//      return this->template getTrailingObjects<ResilientSuperclass>()->superclass;
    }

    TypeReferenceKind getResilientSuperclassReferenceKind() const {
      return getTypeContextDescriptorFlags()
        .class_getResilientSuperclassReferenceKind();
    }

    unsigned getFieldOffsetVectorOffset() const {
        if (hasResilientSuperclass()) {
            auto bounds = getMetadataBounds();
            return (bounds.immediateMembersOffset / sizeof(size_t)
                    + fieldOffsetVectorOffset);
        }

        return fieldOffsetVectorOffset;
    }

    /// Return the offset of the start of generic arguments in the nominal
    /// type's metadata. The returned value is measured in words.
    int32_t getGenericArgumentOffset() const {
      if (!hasResilientSuperclass())
        return getNonResilientGenericArgumentOffset();

      // This lookup works by ADL and will intentionally fail for
      // non-InProcess instantiations.
      return getResilientImmediateMembersOffset(this);
    }

    uint32_t getNumImmediateMembers() const {
        return numImmediateMembers;
    }

private:
    /// The type of the superclass, expressed as a mangled type name that can
    /// refer to the generic arguments of the subclass type.
    RelativeDirectPointer<const char> superclassType;

    union {
      /// If this descriptor does not have a resilient superclass, this is the
      /// negative size of metadata objects of this class (in words).
      uint32_t metadataNegativeSizeInWords;

      /// If this descriptor has a resilient superclass, this is a reference
      /// to a cache holding the metadata's extents.
      RelativeDirectPointer<StoredClassMetadataBounds> resilientMetadataBounds;
    };

    union {
      /// If this descriptor does not have a resilient superclass, this is the
      /// positive size of metadata objects of this class (in words).
      uint32_t metadataPositiveSizeInWords;

      /// Otherwise, these flags are used to do things like indicating
      /// the presence of an Objective-C resilient class stub.
      uint32_t extraClassFlags;
    };

    /// The number of additional members added by this class to the class
    /// metadata.  This data is opaque by default to the runtime, other than
    /// as exposed in other members; it's really just
    /// NumImmediateMembers * sizeof(void*) bytes of data.
    ///
    /// Whether those bytes are added before or after the address point
    /// depends on areImmediateMembersNegative().
    uint32_t numImmediateMembers;

    /// The number of stored properties in the class, not including its
    /// superclasses. If there is a field offset vector, this is its length.
    uint32_t numFields;

    /// The offset of the field offset vector for this class's stored
    /// properties in its metadata, in words. 0 means there is no field offset
    /// vector.
    ///
    /// If this class has a resilient superclass, this offset is relative to
    /// the size of the resilient superclass metadata. Otherwise, it is
    /// absolute.
    uint32_t fieldOffsetVectorOffset;
};

static inline unsigned getFieldOffsetVectorOffset(const ClassDescriptor* description) {
    return description->getFieldOffsetVectorOffset();
}

static inline size_t fullClassMetadataHeaderSize() {
    return sizeof(typename FullMetadata<ClassMetadata>::HeaderType);
}

static inline size_t fullClassMetadataSize() {
    return sizeof(FullMetadata<ClassMetadata>);
}

} // end namespace swift
} // end namespace opencombine

#endif /* OPENCOMBINE_TYPE_METADATA_H */
