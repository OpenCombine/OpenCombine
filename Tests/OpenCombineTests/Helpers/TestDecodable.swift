//
//  File.swift
//  
//
//  Created by Joseph Spadafora on 6/22/19.
//
import Foundation

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

struct TestDecodable: Codable, Equatable {
    let identifier: String
}

extension TestDecodable {
    init() {
        self.identifier = UUID().uuidString
    }
}

extension JSONDecoder: TopLevelDecoder {}
extension JSONEncoder: TopLevelEncoder {}
