//
//  NetworkMonitor.swift
//  MessageAI
//

import Foundation
import Combine
import Network

final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published private(set) var isOnline: Bool = true
    @Published var simulateOffline: Bool = false
    
    var isOnlineEffective: Bool { isOnline && !simulateOffline }
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}


