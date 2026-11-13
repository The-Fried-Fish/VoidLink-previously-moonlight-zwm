//
//  USBStreamTunnel.swift
//  VoidLink
//
//  Created by True砖家 on 2026/11/13.
//  Copyright © 2026 True砖家@Bilibili. All rights reserved.
//


import Foundation
import Network
import UIKit

/// Carries complete GameStream sessions over physical USB connections opened by Sunshine.
/// Video goes directly to common-c. Each remaining local TCP/UDP peer gets its own usbmux connection.
@objc final class USBStreamTunnel: NSObject {
    @objc static let offersDidChangeNotification = "USBStreamTunnelOffersDidChangeNotification"

    private struct Message: Decodable {
        let type: String
        let session: UUID
        let hostId: UUID?
        let hostName: String?
        let ports: [UInt16]?
        let id: UInt32?
        let directVideo: Bool?
        let token: String?
    }

    private static let queue = DispatchQueue(label: "com.voidlink.usb-tunnel")
    private static let port: NWEndpoint.Port = 41849
    private static let maxPeers = 32
    private static let serviceCount = 7
    private static let videoRelayService = 3
    private static let directVideoService = 7
    private static let maxDatagram = 65507
    private static var listener: NWListener?
    private static var offers: [UUID: USBStreamTunnel] = [:]
    private static var pendingHandshakes = 0
    private static var active: USBStreamTunnel?
    private static let activationObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil
    ) { _ in startDiscovery() }

    private final class Peer {
        let local: NWConnection
        let datagrams: Bool
        var usb: NWConnection?
        var finishedDirections = 0

        init(local: NWConnection, datagrams: Bool) {
            self.local = local
            self.datagrams = datagrams
        }
    }

    private final class VideoOpenResult: @unchecked Sendable {
        private let ready = DispatchSemaphore(value: 0)
        private var channel: USBStreamVideoChannel?

        func finish(_ channel: USBStreamVideoChannel?) {
            self.channel = channel
            ready.signal()
        }

        func wait() -> USBStreamVideoChannel? {
            ready.wait()
            return channel
        }
    }

    private let control: NWConnection
    private let session: UUID
    private let hostID: UUID
    private let hostName: String
    private let ports: [UInt16]
    private var listeners: [NWListener] = []
    private var peers: [UInt32: Peer] = [:]
    private var nextPeer: UInt32 = 0
    private var readyListeners = 0
    private var activation: ((TemporaryHost?) -> Void)?
    private var pendingVideo: (id: UInt32, completion: (USBStreamVideoChannel?) -> Void)?
    private var videoChannel: USBStreamVideoChannel?
    private var closed = false

    private init(control: NWConnection, session: UUID, hostID: UUID, hostName: String, ports: [UInt16]) {
        self.control = control
        self.session = session
        self.hostID = hostID
        self.hostName = hostName
        self.ports = ports
    }

    @objc static func startDiscovery() {
        _ = activationObserver
        queue.async {
            guard listener == nil else { return }
            do {
                let parameters = tcpParameters()
                parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: port)
                let server = try NWListener(using: parameters)
                listener = server
                server.stateUpdateHandler = { [weak server] state in
                    guard let server, listener === server else { return }
                    switch state {
                    case .ready:
                        NSLog("USB tunnel listening on 127.0.0.1:%u", port.rawValue)
                    case .failed(let error):
                        NSLog("USB tunnel discovery listener failed: %@", String(describing: error))
                        listener = nil
                        server.cancel()
                    default:
                        break
                    }
                }
                server.newConnectionHandler = { [weak server] connection in
                    guard let server, listener === server, pendingHandshakes < 16,
                          isLoopback(connection.endpoint) else {
                        connection.cancel()
                        return
                    }
                    pendingHandshakes += 1
                    connection.start(queue: queue)
                    readHeader(connection)
                }
                server.start(queue: queue)
            } catch {
                NSLog("USB tunnel listener failed: %@", String(describing: error))
            }
        }
    }

    // A two-byte length header keeps bootstrap messages and the following raw
    // TCP bytes separate even if both arrive in the same USB read.
    private static func readHeader(_ connection: NWConnection) {
        var waiting = true
        func finish(_ message: Message?) {
            guard waiting else { return }
            waiting = false
            pendingHandshakes -= 1
            guard let message else {
                NSLog("USB tunnel bootstrap failed: missing or invalid header")
                connection.cancel()
                return
            }
            switch message.type {
            case "offer":
                guard let hostID = message.hostId, let name = message.hostName,
                      message.directVideo == true, let ports = message.ports, ports.count == serviceCount,
                      ports.allSatisfy({ $0 != 0 && $0 != port.rawValue }),
                      Set(ports.prefix(3)).count == 3, Set(ports.suffix(4)).count == 4,
                      offers.count < 8, offers[hostID] == nil else {
                    NSLog("USB tunnel offer rejected: invalid fields, duplicate host, or offer limit reached (directVideo=%@)",
                          String(describing: message.directVideo))
                    connection.cancel()
                    return
                }
                let tunnel = USBStreamTunnel(control: connection, session: message.session, hostID: hostID,
                                             hostName: name.isEmpty ? hostID.uuidString : name, ports: ports)
                offers[hostID] = tunnel
                NSLog("USB tunnel offer accepted")
                tunnel.monitorControl()
                notifyChange()
            case "channel":
                guard let tunnel = active, tunnel.session == message.session,
                      let id = message.id, let peer = tunnel.peers[id], peer.usb == nil else {
                    connection.cancel()
                    return
                }
                peer.usb = connection
                tunnel.startRelay(id: id, peer: peer)
            case "video":
                guard let tunnel = active, tunnel.session == message.session,
                      let pending = tunnel.pendingVideo, message.id == pending.id,
                      let token = message.token, UUID(uuidString: token) != nil else {
                    connection.cancel()
                    return
                }
                tunnel.pendingVideo = nil
                let channel = USBStreamVideoChannel(connection: connection, queue: queue, token: token)
                tunnel.videoChannel = channel
                pending.completion(channel)
            default:
                connection.cancel()
            }
        }

        queue.asyncAfter(deadline: .now() + .seconds(5)) {
            if waiting { finish(nil) }
        }
        readExactly(2, from: connection) { header in
            guard let header, let size = decodeLength(header), (1...8192).contains(size), waiting else {
                finish(nil)
                return
            }
            readExactly(size, from: connection) { data in
                finish(data.flatMap { try? JSONDecoder().decode(Message.self, from: $0) })
            }
        }
    }

    @objc static func detectedHosts() -> [String: String] {
        queue.sync {
            Dictionary(uniqueKeysWithValues: offers.values.map { ($0.hostID.uuidString, $0.hostName) })
        }
    }

    @objc(isActiveForSessionID:)
    static func isActive(forSessionID sessionID: String?) -> Bool {
        guard let sessionID, let uuid = UUID(uuidString: sessionID) else { return false }
        return queue.sync { active?.session == uuid }
    }

    @objc(activateHostID:completion:)
    static func activate(hostID: String, completion: @escaping (TemporaryHost?) -> Void) {
        queue.async {
            guard let uuid = UUID(uuidString: hostID), let tunnel = offers[uuid], !tunnel.closed else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            if active === tunnel, tunnel.readyListeners == serviceCount - 1 {
                tunnel.deliverHost(completion)
                return
            }
            active?.close()
            active = tunnel
            tunnel.activation = completion
            tunnel.bindServices()
        }
    }

    private func bindServices() {
        do {
            for (service, port) in ports.enumerated() where service != Self.videoRelayService {
                let parameters = service < 3 ? Self.tcpParameters() : NWParameters.udp
                parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
                parameters.allowLocalEndpointReuse = true
                let listener = try NWListener(using: parameters)
                listeners.append(listener)
                listener.stateUpdateHandler = { [weak self] state in
                    guard let self, !self.closed else { return }
                    switch state {
                    case .ready:
                        self.readyListeners += 1
                        if self.readyListeners == Self.serviceCount - 1, let completion = self.activation {
                            self.activation = nil
                            self.deliverHost(completion)
                        }
                    case let .failed(error):
                        NSLog("USB tunnel could not listen on loopback port %u: %@", port, String(describing: error))
                        self.close()
                    default:
                        break
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in
                    guard let self, !self.closed, Self.isLoopback(connection.endpoint) else {
                        connection.cancel()
                        return
                    }
                    self.openPeer(connection, service: service)
                }
                listener.start(queue: Self.queue)
            }
        } catch {
            NSLog("USB tunnel service listener failed: %@", String(describing: error))
            close()
        }
        Self.queue.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
            if let self, self.activation != nil { self.close() }
        }
    }

    @objc(openVideoForSessionID:)
    static func openVideo(forSessionID sessionID: String) -> USBStreamVideoChannel? {
        // Called from StreamManager's worker, never from the main or USB queue.
        let result = VideoOpenResult()
        queue.async {
            guard let tunnel = active, !tunnel.closed, tunnel.session == UUID(uuidString: sessionID),
                  tunnel.pendingVideo == nil else {
                result.finish(nil)
                return
            }
            tunnel.videoChannel?.close()
            tunnel.videoChannel = nil
            let id = tunnel.allocatePeerID()
            tunnel.pendingVideo = (id, result.finish)
            tunnel.requestPeer(id: id, service: directVideoService)
            queue.asyncAfter(deadline: .now() + .seconds(5)) { [weak tunnel] in
                guard let tunnel, let pending = tunnel.pendingVideo, pending.id == id else { return }
                tunnel.pendingVideo = nil
                pending.completion(nil)
            }
        }
        return result.wait()
    }

    private func deliverHost(_ completion: @escaping (TemporaryHost?) -> Void) {
        let host = TemporaryHost()
        host.uuid = hostID.uuidString
        host.name = hostName
        host.activeAddress = "127.0.0.1:\(ports[0])"
        host.httpsPort = ports[1]
        host.usesUSBStreamTunnel = true
        host.usbTunnelSessionID = session.uuidString
        host.state = .online
        DispatchQueue.main.async { completion(host) }
    }

    private func monitorControl() {
        control.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.close()
            default: break
            }
        }
        control.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] _, _, _, _ in
            self?.close()
        }
    }

    private func openPeer(_ connection: NWConnection, service: Int) {
        guard peers.count < Self.maxPeers else { connection.cancel(); return }
        let id = allocatePeerID()
        let peer = Peer(local: connection, datagrams: service >= 3)
        peers[id] = peer
        connection.stateUpdateHandler = { [weak self] state in
            guard let self, self.peers[id]?.usb == nil else { return }
            switch state {
            case .failed, .cancelled: self.closePeer(id)
            default: break
            }
        }
        connection.start(queue: Self.queue)
        requestPeer(id: id, service: service)
        Self.queue.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
            guard let self, self.peers[id]?.usb == nil else { return }
            self.closePeer(id)
        }
    }

    private func allocatePeerID() -> UInt32 {
        repeat { nextPeer &+= 1 } while nextPeer == 0 || peers[nextPeer] != nil || pendingVideo?.id == nextPeer
        return nextPeer
    }

    private func requestPeer(id: UInt32, service: Int) {
        control.send(content: Data("OPEN \(id) \(service)\n".utf8), completion: .contentProcessed { [weak self] error in
            if error != nil { self?.close() }
        })
    }

    private func startRelay(id: UInt32, peer: Peer) {
        guard let usb = peer.usb else { return }
        // Receive/send callbacks drain the established connection. A terminal
        // state notification can arrive before the last receive callback.
        peer.local.stateUpdateHandler = nil
        if peer.datagrams {
            sendDatagrams(id: id, from: peer.local, to: usb)
            receiveDatagrams(id: id, from: usb, to: peer.local)
        } else {
            relayTCP(id: id, from: peer.local, to: usb)
            relayTCP(id: id, from: usb, to: peer.local)
        }
    }

    private func relayTCP(id: UInt32, from source: NWConnection, to target: NWConnection) {
        source.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, complete, error in
            guard let self, self.peers[id] != nil else { return }
            guard error == nil else { self.closePeer(id); return }
            if let data, !data.isEmpty {
                target.send(content: data, completion: .contentProcessed { [weak self] error in
                    if error != nil { self?.closePeer(id) }
                    else if complete { self?.finishTCPDirection(id: id, target: target) }
                    else { self?.relayTCP(id: id, from: source, to: target) }
                })
            } else if complete {
                self.finishTCPDirection(id: id, target: target)
            } else {
                self.relayTCP(id: id, from: source, to: target)
            }
        }
    }

    private func finishTCPDirection(id: UInt32, target: NWConnection) {
        target.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { [weak self] error in
            guard let self, let peer = self.peers[id] else { return }
            if error != nil { self.closePeer(id); return }
            peer.finishedDirections += 1
            if peer.finishedDirections == 2 {
                // Let Network.framework drain bytes queued before both FINs.
                Self.queue.asyncAfter(deadline: .now() + .milliseconds(250)) { [weak self] in
                    self?.closePeer(id)
                }
            }
        })
    }

    private func sendDatagrams(id: UInt32, from source: NWConnection, to target: NWConnection) {
        source.receiveMessage { [weak self] data, _, _, error in
            guard let self, self.peers[id] != nil else { return }
            guard error == nil, let data, data.count <= Self.maxDatagram else { self.closePeer(id); return }
            var frame = Data([UInt8(data.count >> 8), UInt8(data.count & 255)])
            frame.append(data)
            target.send(content: frame, completion: .contentProcessed { [weak self] error in
                if error != nil { self?.closePeer(id) }
                else { self?.sendDatagrams(id: id, from: source, to: target) }
            })
        }
    }

    private func receiveDatagrams(id: UInt32, from source: NWConnection, to target: NWConnection) {
        Self.readExactly(2, from: source) { [weak self] header in
            guard let self, self.peers[id] != nil else { return }
            guard let header, let size = Self.decodeLength(header), size <= Self.maxDatagram else {
                self.closePeer(id)
                return
            }
            Self.readExactly(size, from: source) { [weak self] data in
                guard let self, self.peers[id] != nil else { return }
                guard let data else { self.closePeer(id); return }
                target.send(content: data, completion: .contentProcessed { [weak self] error in
                    if error != nil { self?.closePeer(id) }
                    else { self?.receiveDatagrams(id: id, from: source, to: target) }
                })
            }
        }
    }

    private static func readExactly(_ count: Int, from connection: NWConnection, completion: @escaping (Data?) -> Void) {
        if count == 0 { completion(Data()); return }
        connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
            completion(error == nil && data?.count == count ? data : nil)
        }
    }

    private static func decodeLength(_ data: Data) -> Int? {
        guard data.count == 2 else { return nil }
        return (Int(data[data.startIndex]) << 8) | Int(data[data.index(after: data.startIndex)])
    }

    private static func isLoopback(_ endpoint: NWEndpoint) -> Bool {
        guard case let .hostPort(host, _) = endpoint else { return false }
        switch host {
        case .ipv4(let address): return address.rawValue.first == 127
        case .ipv6(let address):
            let bytes = address.rawValue
            return address == .loopback ||
                (bytes.prefix(10).allSatisfy { $0 == 0 } && bytes[10] == 255 && bytes[11] == 255 && bytes[12] == 127)
        case .name(let name, _): return name == "127.0.0.1" || name == "::1"
        @unknown default: return false
        }
    }

    private static func tcpParameters() -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        return NWParameters(tls: nil, tcp: tcp)
    }

    private func closePeer(_ id: UInt32) {
        guard let peer = peers.removeValue(forKey: id) else { return }
        peer.local.cancel()
        peer.usb?.cancel()
    }

    private func close() {
        guard !closed else { return }
        closed = true
        control.cancel()
        listeners.forEach { $0.cancel() }
        listeners.removeAll()
        for id in Array(peers.keys) { closePeer(id) }
        videoChannel?.close()
        videoChannel = nil
        if let pendingVideo {
            self.pendingVideo = nil
            pendingVideo.completion(nil)
        }
        if let completion = activation {
            activation = nil
            DispatchQueue.main.async { completion(nil) }
        }
        if Self.active === self { Self.active = nil }
        if Self.offers[hostID] === self { Self.offers.removeValue(forKey: hostID) }
        Self.notifyChange()
    }

    private static func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name(offersDidChangeNotification), object: nil)
        }
    }
}

@objc final class USBStreamVideoChannel: NSObject {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let condition = NSCondition()
    private var token: String?
    private var chunk: Data?
    private var offset = 0
    private var ended = false
    private var readerStarted = false

    init(connection: NWConnection, queue: DispatchQueue, token: String) {
        self.connection = connection
        self.queue = queue
        self.token = token
        super.init()
        receive()
    }

    private func receive() {
        condition.lock()
        let canRead = !ended && chunk == nil
        condition.unlock()
        guard canRead else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, complete, error in
            guard let self else { return }
            self.condition.lock()
            if !self.ended {
                if let data, !data.isEmpty {
                    self.chunk = data
                    self.offset = 0
                }
                if complete || error != nil {
                    self.ended = true
                    self.token = nil
                }
                self.condition.broadcast()
            }
            let readAgain = !self.ended && self.chunk == nil
            self.condition.unlock()
            if readAgain { self.receive() }
        }
    }

    @objc func close() {
        condition.lock()
        ended = true
        chunk = nil
        token = nil
        condition.broadcast()
        condition.unlock()
        connection.cancel()
    }

    @objc(requestWithLaunchToken:)
    func requestWithLaunchToken(_ request: URLRequest?) -> URLRequest? {
        guard var request, let url = request.url, url.scheme == "https", url.host == "127.0.0.1",
              url.path == "/launch" || url.path == "/resume" else { return nil }
        condition.lock()
        let launchToken = ended ? nil : token
        token = nil
        condition.unlock()
        guard let launchToken else { return nil }
        request.setValue(launchToken, forHTTPHeaderField: "X-SS-USB-Direct-Video")
        return request
    }

    @objc func videoTransport() -> LI_VIDEO_TRANSPORT {
        LI_VIDEO_TRANSPORT(read: { context, buffer, capacity, timeout in
            guard let context, let buffer, capacity > 0 else { return -1 }
            return Unmanaged<USBStreamVideoChannel>.fromOpaque(context).takeUnretainedValue()
                .read(into: buffer, capacity: Int(capacity), timeout: timeout)
        }, context: Unmanaged.passUnretained(self).toOpaque())
    }

    private func read(into buffer: UnsafeMutableRawPointer, capacity: Int, timeout: Int32) -> Int32 {
        condition.lock()
        if !readerStarted && !ended {
            readerStarted = true
            // common-c reads video only after RTSP has finished negotiating it.
            connection.send(content: Data([0x56]), completion: .contentProcessed { [weak self] error in
                if error != nil { self?.close() }
            })
        }
        if chunk == nil && !ended {
            let deadline = Date(timeIntervalSinceNow: Double(timeout) / 1000)
            while chunk == nil && !ended && condition.wait(until: deadline) {}
        }
        guard let chunk else {
            let result: Int32 = ended ? -1 : 0
            condition.unlock()
            return result
        }
        let count = min(capacity, chunk.count - offset)
        let start = chunk.startIndex + offset
        chunk.copyBytes(to: UnsafeMutableRawBufferPointer(start: buffer, count: count), from: start..<(start + count))
        offset += count
        let drained = offset == chunk.count
        if drained { self.chunk = nil }
        condition.unlock()
        if drained { queue.async { self.receive() } }
        return Int32(count)
    }
}
