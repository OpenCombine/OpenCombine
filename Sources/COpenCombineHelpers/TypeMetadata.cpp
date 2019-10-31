//
//  TypeMetadata.cpp
//  
//
//  Created by Sergej Jaskiewicz on 25.10.2019.
//

#include "TypeMetadata.h"
#include "COpenCombineHelpers.h"

#if __APPLE__
#include <objc/runtime.h>

extern "C" Class swift_getInitializedObjCClass(Class c);
#endif

using namespace opencombine;
using namespace opencombine::swift;

string_view opencombine::swift::makeSymbolicMangledNameStringRef(const char* base) {
    if (!base)
        return {};

    const char* end = base;
    while (*end != '\0') {
        // Skip over symbolic references.
        if (*end >= '\x01' && *end <= '\x17') {
            end += sizeof(uint32_t);
        } else if (*end >= '\x18' && *end <= '\x1F') {
            end += sizeof(void*);
        }
        ++end;
    }
    return { base, size_t(end - base) };
}

#if __APPLE__
static ClassMetadataBounds computeMetadataBoundsForObjCClass(Class cls) {
  cls = swift_getInitializedObjCClass(cls);
  auto metadata = reinterpret_cast<const ClassMetadata *>(cls);
  return metadata->getClassBoundsAsSwiftSuperclass();
}
#endif

static ClassMetadataBounds
computeMetadataBoundsForSuperclass(const void *ref,
                                   TypeReferenceKind refKind) {
    switch (refKind) {
    case TypeReferenceKind::IndirectTypeDescriptor: {
        auto description = *reinterpret_cast<const ClassDescriptor * const *>(ref);
        if (!description) {
            fprintf(stderr,
                    "instantiating class metadata for class with "
                    "missing weak-linked ancestor");
            abort();
        }
        return description->getMetadataBounds();
    }

    case TypeReferenceKind::DirectTypeDescriptor: {
        auto description = reinterpret_cast<const ClassDescriptor *>(ref);
        return description->getMetadataBounds();
    }

    case TypeReferenceKind::DirectObjCClassName: {
#if __APPLE__
        auto cls = objc_lookUpClass(reinterpret_cast<const char *>(ref));
        return computeMetadataBoundsForObjCClass(cls);
#else
        break;
#endif
        }

    case TypeReferenceKind::IndirectObjCClass: {
#if __APPLE__
        auto cls = *reinterpret_cast<const Class *>(ref);
        return computeMetadataBoundsForObjCClass(cls);
#else
        break;
#endif
    }
    }
}

static ClassMetadataBounds computeMetadataBoundsFromSuperclass(
    const ClassDescriptor *description,
    StoredClassMetadataBounds &storedBounds
) {
    ClassMetadataBounds bounds;

    // Compute the bounds for the superclass, extending it to the minimum
    // bounds of a Swift class.
    if (const void *superRef = description->getResilientSuperclass()) {
        bounds = computeMetadataBoundsForSuperclass(
            superRef, description->getResilientSuperclassReferenceKind());
    } else {
        bounds = ClassMetadataBounds::forSwiftRootClass();
    }

    // Add the subclass's immediate members.
    bounds.adjustForSubclass(description->areImmediateMembersNegative(),
                             description->getNumImmediateMembers());

    // Cache before returning.
    storedBounds.initialize(bounds);
    return bounds;
}

ClassMetadataBounds
opencombine::swift::getResilientMetadataBounds(const ClassDescriptor *description) {
    assert(description->hasResilientSuperclass());
    auto &storedBounds = *description->resilientMetadataBounds.get();

    ClassMetadataBounds bounds;
    if (storedBounds.tryGet(bounds)) {
      return bounds;
    }

    return computeMetadataBoundsFromSuperclass(description, storedBounds);
}

int32_t opencombine::swift::getResilientImmediateMembersOffset(
    const ClassDescriptor* description
) {
    assert(description->hasResilientSuperclass());
    auto &storedBounds = *description->resilientMetadataBounds.get();

    ptrdiff_t result;
    if (storedBounds.tryGetImmediateMembersOffset(result)) {
      return result / sizeof(void*);
    }

    auto bounds = computeMetadataBoundsFromSuperclass(description, storedBounds);
    return bounds.immediateMembersOffset / sizeof(void*);
}

bool opencombine_enumerate_class_fields(const void* opaqueMetadataPtr,
                                        void* enumeratorContext,
                                        OpenCombineFieldEnumerator enumerator) {

    using namespace reflection;

    const Metadata* metadata = static_cast<const Metadata*>(opaqueMetadataPtr);

    if (metadata->isClassObject()) {
        auto anyClassMetadata = static_cast<const AnyClassMetadata*>(metadata);
        if (!anyClassMetadata->isTypeMetadata()) {
            return true;
        }
        auto classMetadata = static_cast<const ClassMetadata*>(anyClassMetadata);
        
        if (auto superclassMetadata = classMetadata->getSuperclass()) {
            if (!opencombine_enumerate_class_fields(superclassMetadata,
                                                    enumeratorContext,
                                                    enumerator)) {
                return false;
            }
        }

        const ClassDescriptor* description = classMetadata->getDescription();

        if (description->hasResilientSuperclass()) {
            return false;
        }

        const uintptr_t* fieldOffsets = classMetadata->getFieldOffsets();
        const FieldDescriptor& fieldDescriptor = *description->getFields();

        for (const FieldRecord& fieldRecord : fieldDescriptor) {
            if (!enumerator(enumeratorContext,
                            fieldRecord.getFieldName().data(),
                            *fieldOffsets++,
                            fieldRecord.getTypeMetadata(description))) {
                return true;
            }
        }

        return true;
    }

    return false;
}
