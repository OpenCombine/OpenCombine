/*
 * Copyright (C) 2011-2020 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
 */

#pragma once

/* COMPILER_HAS_CLANG_FEATURE() - whether the compiler supports a particular language or library feature. */
/* http://clang.llvm.org/docs/LanguageExtensions.html#has-feature-and-has-extension */
#ifdef __has_feature
#define COMPILER_HAS_CLANG_FEATURE(x) __has_feature(x)
#else
#define COMPILER_HAS_CLANG_FEATURE(x) 0
#endif

/* ==== COMPILER_SUPPORTS - additional compiler feature detection, in alphabetical order ==== */

/* ASAN_ENABLED and SUPPRESS_ASAN */

#ifdef __SANITIZE_ADDRESS__
#define ASAN_ENABLED 1
#else
#define ASAN_ENABLED COMPILER_HAS_CLANG_FEATURE(address_sanitizer)
#endif

#if ASAN_ENABLED
#define SUPPRESS_ASAN __attribute__((no_sanitize_address))
#else
#define SUPPRESS_ASAN
#endif

/* TSAN_ENABLED and SUPPRESS_TSAN */

#ifdef __SANITIZE_THREAD__
#define TSAN_ENABLED 1
#else
#define TSAN_ENABLED COMPILER_HAS_CLANG_FEATURE(thread_sanitizer)
#endif

#if TSAN_ENABLED
#define SUPPRESS_TSAN __attribute__((no_sanitize_thread))
#else
#define SUPPRESS_TSAN
#endif

/* COVERAGE_ENABLED and SUPPRESS_COVERAGE */

#define COVERAGE_ENABLED COMPILER_HAS_CLANG_FEATURE(coverage_sanitizer)

#if COVERAGE_ENABLED
#define SUPPRESS_COVERAGE __attribute__((no_sanitize("coverage")))
#else
#define SUPPRESS_COVERAGE
#endif
