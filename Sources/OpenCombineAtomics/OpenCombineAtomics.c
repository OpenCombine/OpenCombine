//
//  OpenCombineAtomics.c
//  
//
//  Created by Sergej Jaskiewicz on 23/09/2019.
//

#include "OpenCombineAtomics.h"

#include <stdatomic.h>
#include <stdlib.h>

#define OPENCOMBINE_ATOMIC_DEFINITION(type)                                              \
    struct opencombine_atomic_##type { atomic_##type value; };                           \
                                                                                         \
    opencombine_atomic_##type * _Nonnull opencombine_atomic_##type##_create(type value) {\
        opencombine_atomic_##type *wrapper = malloc(sizeof(*wrapper));                   \
        if (!wrapper) abort();                                                           \
        atomic_init(&wrapper->value, value);                                             \
        return wrapper;                                                                  \
    }                                                                                    \
                                                                                         \
    void                                                                                 \
    opencombine_atomic_##type##_destroy(opencombine_atomic_##type * _Nonnull wrapper) {  \
        free(wrapper);                                                                   \
    }                                                                                    \
                                                                                         \
    type                                                                                 \
    opencombine_atomic_##type##_add(opencombine_atomic_##type * _Nonnull wrapper,        \
                                    type value) {                                        \
        return atomic_fetch_add_explicit(&wrapper->value, value, memory_order_relaxed);  \
    }

OPENCOMBINE_ATOMIC_DEFINITION(uintptr_t)
