//
//  Binding+Optional.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2025-04-21.
//  Copyright © 2025 Jon Fawcett. All rights reserved.
//

import Foundation
import SwiftUI

extension Binding where Value: Equatable {
  /// Create a Binding<Value> out of a Binding<Value?> by substituting `defaultValue` when nil.
  init(_ source: Binding<Value?>, replacingNilWith defaultValue: Value) {
    self.init(
      get:   { source.wrappedValue ?? defaultValue },
      set:   { source.wrappedValue = $0 }
    )
  }
}
