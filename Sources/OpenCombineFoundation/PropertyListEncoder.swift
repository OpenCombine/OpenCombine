//
//  PropertyListEncoder.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.12.2019.
//

import Foundation
import OpenCombine

extension PropertyListEncoder: TopLevelEncoder {
  public typealias Output = Data
}

extension PropertyListDecoder: TopLevelDecoder {
  public typealias Input = Data
}
