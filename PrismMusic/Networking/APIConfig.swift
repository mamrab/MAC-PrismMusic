//
//  APIConfig.swift
//  PrismMusic
//
//  ONE place to edit when you change the backend host. The user can also
//  override this at runtime from the Settings screen.
//

import Foundation

enum APIConfig {
    /// Default PrismMusic backend URL.
    static let defaultBackendURL = "https://pm.standrise.net"

    /// Pre-configured PrismMusic backend hosts. The first one is the main host.
    static let hosts = [
        "https://pm.standrise.net",
        "https://prism-music-one.vercel.app"
    ]

    /// Request timeout for all API calls in seconds.
    static let timeoutSeconds: TimeInterval = 20

    /// Max bytes of body to log to console for failed requests.
    static let errorBodyLogLimit = 2_048
}
