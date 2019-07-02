//
//  TopLevelDecoder+Extensions.swift
//  
//
//  Created by Joseph Spadafora on 6/29/19.
//

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import Foundation
import OpenCombine

extension JSONDecoder: TopLevelDecoder {}
extension JSONEncoder: TopLevelEncoder {}
#endif
