//
//  COpenCombineHelpers.cpp
//  
//
//  Created by Sergej Jaskiewicz on 23/09/2019.
//

#include "COpenCombineHelpers.h"

#include <atomic>

extern "C" uint64_t opencombine_next_combine_identifier() {
    static std::atomic<uint64_t> next_combine_identifier;
    return next_combine_identifier.fetch_add(1);
}
