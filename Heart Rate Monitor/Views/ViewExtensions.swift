//
//  ViewExtensions.swift
//  Heart Rate Monitor
//

import SwiftUI

extension View {
    // Conditionally applies a transform to a view.
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, @ViewBuilder then transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
