//
//  span.h
//  
//
//  Created by Sergej Jaskiewicz on 30.10.2019.
//

#ifndef OPENCOMBINE_SPAN_H
#define OPENCOMBINE_SPAN_H

#include <cstddef>
#include <type_traits>
#include <iterator>

namespace opencombine {

// This is a very simplified implementation of std::span from C++20.
// Not all compilers support it yet.
template <typename T>
class span {
public:
    using element_type = T;
    using value_type = std::remove_cv<T>;
    using index_type = size_t;
    using differenc_type = ptrdiff_t;
    using pointer = T*;
    using const_pointer = const T*;
    using reference = T&;
    using const_reference = const T&;
    using iterator = T*;
    using const_iterator = const T*;
    using reverse_iterator = std::reverse_iterator<iterator>;
    using const_reverse_iterator = std::reverse_iterator<const_iterator>;

    constexpr span() noexcept: span(nullptr, 0) {}
    constexpr span(pointer ptr, index_type count): data_(ptr), size_(count) {}
    constexpr span(pointer first, pointer last): span(first, last - first) {}
    constexpr span(const span& other) noexcept = default;

    constexpr span& operator=(const span& other) noexcept = default;

private:
    pointer data_;
    index_type size_;
};

} // end namespace opencombine

#endif /* OPENCOMBINE_SPAN_H */
