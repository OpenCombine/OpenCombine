//
//  PropertyListEncoder.swift
//  
//
//  Created by Sergej Jaskiewicz on 10.12.2019.
//

import Foundation
import OpenCombine

#if swift(>=5.1)
extension PropertyListEncoder: TopLevelEncoder {
  public typealias Output = Data
}

extension PropertyListDecoder: TopLevelDecoder {
  public typealias Input = Data
}
#endif
