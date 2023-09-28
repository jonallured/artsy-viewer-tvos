//
//  Something.swift
//  Artsy Viewer
//
//  Created by Jonathan Allured on 11/15/22.
//

import Foundation

class Something {
    static func omg(callback: @escaping (SocketMessage) -> Void) {
        let webSocket = SwiftWebSocketClient.shared
        webSocket.subscribeToService { socketMessage in
            guard let socketMessage = socketMessage else { return }
            callback(socketMessage)
        }
    }
}

final class SwiftWebSocketClient: NSObject {
    static let shared = SwiftWebSocketClient()
    var webSocket: URLSessionWebSocketTask?
    
    var opened = false
    
//    private var urlString = "ws://localhost:3000/cable"
    private var urlString = "wss://app.jonallured.com/cable"
    
    private override init() {
        // noop
    }
    
    func subscribeToService(with completion: @escaping (SocketMessage?) -> Void) {
        if !opened {
            openWebSocket()
        }
        
        guard let webSocket = webSocket else {
            completion(nil)
            return
        }
        
        webSocket.receive(completionHandler: { [weak self] result in
            let receivedAt = Date()
            
            guard let self = self else { return }
            
            switch result {
            case .failure:
                completion(nil)
            case .success(let webSocketTaskMessage):
                switch webSocketTaskMessage {
                case .string(let rawString):
                    let decoded = self.decodeRawString(rawString: rawString)
                    if (decoded as? WelcomeMessage != nil) {
                        self.subscribeToChannel()
                    }
                    let socketMessage = SocketMessage(decoded: decoded, rawString: rawString, receivedAt: receivedAt)
                    completion(socketMessage)
                    self.subscribeToService(with: completion)
                default:
                    fatalError("Failed. Received unknown data format. Expected String")
                }
            }
        })
    }
    
    private func openWebSocket() {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let webSocket = session.webSocketTask(with: request)
            self.webSocket = webSocket
            self.opened = true
            self.webSocket?.resume()
        } else {
            webSocket = nil
        }
    }
    
    private func subscribeToChannel() {
        guard let webSocket = webSocket else {
            return
        }
        
        let subPayload = """
        {"command":"subscribe","identifier":"{\\"channel\\":\\"ArtsyViewerChannel\\"}"}
        """
        
        webSocket.send(URLSessionWebSocketTask.Message.string(subPayload)) { error in
                if let error = error {
                    print("Failed with Error \(error.localizedDescription)")
                }
            
        }
    }
    
    private func decodeRawString(rawString: String) -> Decodable? {
        let data = rawString.data(using: .utf8, allowLossyConversion: false)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let channel = try? decoder.decode(ChannelMessage.self, from: data!)
        let confirm = try? decoder.decode(ConfirmMessage.self, from: data!)
        let ping = try? decoder.decode(PingMessage.self, from: data!)
        let welcome = try? decoder.decode(WelcomeMessage.self, from: data!)
        
        if let channel = channel {
            return channel
        } else if let confirm = confirm {
            return confirm
        } else if let ping = ping {
            return ping
        } else if let welcome = welcome {
            return welcome
        } else {
            return nil
        }
    }
}

extension SwiftWebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        opened = true
    }
    
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.webSocket = nil
        self.opened = false
    }
}

struct ArtworkImage: Decodable {
    let url: String
    let position: Int
    let aspectRatio: Float
}

struct ArtworkPayload: Decodable {
    let href: String
    let blurb: String
    let image: ArtworkImage
    let gravityId: String
}

struct ArtworkInfo: Decodable {
    let id: Int
    let payload: ArtworkPayload
    let gravityId: String
    let createdAt: String
    let updatedAt: String
}

struct SocketMessage {
    let decoded: Decodable?
    let rawString: String
    let receivedAt: Date
    
    func asLog() -> String {
        let format = "yyyy-MM-dd' 'HH:mm:ss"
        let formatter = DateFormatter()
        formatter.dateFormat = format
        let logTime = formatter.string(from: receivedAt)
        return "\(logTime) - \(rawString)"
    }
}

struct ChannelMessage: Decodable {
    let message: [ArtworkInfo]
    let identifier: String
}

struct ConfirmMessage: Decodable {
    let type: String
    let identifier: String
}

struct PingMessage: Decodable {
    let type: String
    let message: Int
}

struct WelcomeMessage: Decodable {
    let type: String
}
