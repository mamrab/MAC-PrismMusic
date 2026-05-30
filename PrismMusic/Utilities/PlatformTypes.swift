//
//  PlatformTypes.swift
//  PrismMusic
//
//  Unified typealiases and utilities to bridge differences between UIKit (iOS)
//  and AppKit (macOS).
//

import SwiftUI

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
#endif

#if os(macOS)
extension ToolbarItemPlacement {
    public static var safeTopBarTrailing: ToolbarItemPlacement { .confirmationAction }
}
#else
extension ToolbarItemPlacement {
    public static var safeTopBarTrailing: ToolbarItemPlacement { .topBarTrailing }
}
#endif

extension View {
    @ViewBuilder
    func safeTextInputAutocapitalizationNever() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.never)
        #else
        self
        #endif
    }

    @ViewBuilder
    func safeNavigationBarHidden() -> some View {
        #if os(iOS)
        self.navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func safeNavigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func safeEditModeActive() -> some View {
        #if os(iOS)
        self.environment(\.editMode, .constant(.active))
        #else
        self
        #endif
    }

    @ViewBuilder
    func safeFullScreenCover<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        self.fullScreenCover(isPresented: isPresented, content: content)
        #else
        self.sheet(isPresented: isPresented, content: content)
        #endif
    }
}
