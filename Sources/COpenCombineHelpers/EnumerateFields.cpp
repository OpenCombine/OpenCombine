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

string_view nextTupleLabel(const char*& labels) {
    const char* start = labels;
    while (true) {
        char current = *labels++;
        if (current == ' ' || current == '\0') {
            break;
        }
    }
    return { start, size_t(labels - start - 1) };
}

} // end anonymous namespace

bool opencombine_enumerate_fields(const void* opaqueMetadataPtr,
                                        bool allowResilientSuperclasses,
                                        void* enumeratorContext,
                                        OpenCombineFieldEnumerator enumerator) {

    auto enumerateFields = [&](const auto* metadata,
                               const TypeContextDescriptor* description) -> bool {
        const auto* fieldOffsets = metadata->getFieldOffsets();
        const FieldDescriptor& fieldDescriptor = *description->Fields;

        for (const FieldRecord& fieldRecord : fieldDescriptor) {
            if (!enumerator(enumeratorContext,
                            fieldRecord.getFieldName(0).data(),
                            *fieldOffsets++,
                            getTypeMetadata(fieldRecord, metadata))) {
                return false;
            }
        }

        return true;
    };

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
            if (!opencombine_enumerate_fields(superclassMetadata,
                                              allowResilientSuperclasses,
                                              enumeratorContext,
                                              enumerator)) {
                return false;
            }
        }

        return enumerateFields(classMetadata, description);
    }

    if (const auto* structMetadata = llvm::dyn_cast<StructMetadata>(metadata)) {
        return enumerateFields(structMetadata, structMetadata->getDescription());
    }

    if (const auto* tupleMetadata = llvm::dyn_cast<TupleTypeMetadata>(metadata)) {
        const char* labels = tupleMetadata->Labels;
        for (TupleTypeMetadata::StoredSize i = 0; i < tupleMetadata->NumElements; ++i) {
            const TupleTypeMetadata::Element& element = tupleMetadata->getElement(i);
            string_view nextLabel = nextTupleLabel(labels);
            std::string label(nextLabel.data(), nextLabel.size());
            if (!enumerator(enumeratorContext,
                            label.c_str(),
                            element.Offset,
                            element.Type)) {
                return false;
            }
        }
    }

    return false;
}
