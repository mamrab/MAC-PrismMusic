//
//  NetworkMonitor.swift
//  PrismMusic
//
//  Observes network reachability status in real-time.
//

import Foundation
import Network
import Observation

@Observable
@MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")
    
    var isConnected: Bool = true
    
    init() {
        // Initial state is true, we update on the first path update
        monitor.pathUpdateHandler = { path in
            let connected = path.status == .satisfied
            Task { @MainActor in
                self.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }
}
