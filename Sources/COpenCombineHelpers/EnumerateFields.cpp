//
//  EnumerateFields.cpp
//  
//
//  Created by Sergej Jaskiewicz on 25.10.2019.
//

#include "COpenCombineHelpers.h"
#include "swift/ABI/Metadata.h"
#include "swift/Runtime/Metadata.h"
#include "swift/Reflection/Records.h"
#include "stl_polyfill/string_view.h"

using namespace opencombine;
using namespace swift;
using namespace reflection;

// This function is defined in the Swift runtime.
OPENCOMBINE_SWIFT_CALLING_CONVENTION
extern "C"
const Metadata *
swift_getTypeByMangledNameInContext(const char* typeNameStart,
                                    size_t typeNameLength,
                                    const ContextDescriptor* context,
                                    const Metadata* const* genericArgs);

namespace {
const Metadata* getTypeMetadata(const FieldRecord& record,
                                const Metadata* fieldOwner) {
    string_view mangledTypeName = record.getMangledTypeName(0);
    return swift_getTypeByMangledNameInContext(mangledTypeName.data(),
                                               mangledTypeName.size(),
                                               fieldOwner->getTypeContextDescriptor(),
                                               fieldOwner->getGenericArgs());
}
} // end anonymous namespace

bool opencombine_enumerate_class_fields(const void* opaqueMetadataPtr,
                                        bool allowResilientSuperclasses,
                                        void* enumeratorContext,
                                        OpenCombineFieldEnumerator enumerator) {

    const Metadata* metadata = static_cast<const Metadata*>(opaqueMetadataPtr);

    if (metadata->isClassObject()) {
        auto anyClassMetadata = static_cast<const AnyClassMetadata*>(metadata);
        if (!anyClassMetadata->isTypeMetadata()) {
            return true;
        }
        auto classMetadata = static_cast<const ClassMetadata*>(anyClassMetadata);

        const ClassDescriptor* description = classMetadata->getDescription();

        if (!allowResilientSuperclasses && description->hasResilientSuperclass()) {
            return false;
        }

        if (auto superclassMetadata = classMetadata->Superclass) {
            if (!opencombine_enumerate_class_fields(superclassMetadata,
                                                    allowResilientSuperclasses,
                                                    enumeratorContext,
                                                    enumerator)) {
                return false;
            }
        }

        const ClassMetadata::StoredPointer* fieldOffsets =
            classMetadata->getFieldOffsets();
        const FieldDescriptor& fieldDescriptor = *description->Fields;

        for (const FieldRecord& fieldRecord : fieldDescriptor) {
            if (!enumerator(enumeratorContext,
                            fieldRecord.getFieldName(0).data(),
                            *fieldOffsets++,
                            getTypeMetadata(fieldRecord, classMetadata))) {
                return false;
            }
        }

        return true;
    }

    return false;
}
