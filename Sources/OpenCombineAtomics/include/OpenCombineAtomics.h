//
//  OpenCombineAtomics.h
//  
//
//  Created by Sergej Jaskiewicz on 23/09/2019.
//

#include <stdbool.h>
#include <stdint.h>

#define OPENCOMBINE_ATOMIC_DECLARATION(type)                                             \
    struct opencombine_atomic_##type;                                                    \
    typedef struct opencombine_atomic_##type opencombine_atomic_##type;                  \
                                                                                         \
    opencombine_atomic_##type * _Nonnull opencombine_atomic_##type##_create(type value); \
                                                                                         \
    void                                                                                 \
    opencombine_atomic_##type##_destroy(opencombine_atomic_##type * _Nonnull wrapper);   \
                                                                                         \
    type                                                                                 \
    opencombine_atomic_##type##_add(opencombine_atomic_##type * _Nonnull wrapper,        \
                                    type value);

OPENCOMBINE_ATOMIC_DECLARATION(uintptr_t)
