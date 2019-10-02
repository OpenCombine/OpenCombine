//
//  COpenCombineHelpers.cpp
//  
//
//  Created by Sergej Jaskiewicz on 23/09/2019.
//

#include "COpenCombineHelpers.h"

#include <atomic>

extern "C" uintptr_t opencombine_next_combine_identifier() {
    static std::atomic<uintptr_t> next_combine_identifier;
    return next_combine_identifier.fetch_add(1);
}
