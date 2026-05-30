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
