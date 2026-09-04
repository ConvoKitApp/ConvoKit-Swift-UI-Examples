import ConvoKit
import ConvoKitUI
import SwiftUI

struct LiveChatView: View {
    @State private var userId = "swift_guest"
    @State private var roomId = ""
    @State private var client: ConvoKitClient?
    @State private var connectedRoomId: String?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Group {
            if let client, let connectedRoomId, let chat = try? ConvoKitConversation(client: client, conversationId: connectedRoomId, onBack: disconnect) {
                chat
            } else {
                Form {
                    Section("Open chatroom") {
                        TextField("App user ID", text: $userId).textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("Chatroom ID", text: $roomId).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button { Task { await connect() } } label: { if busy { ProgressView() } else { Label("Join room", systemImage: "arrow.right.circle.fill") } }.disabled(busy || userId.isEmpty || roomId.isEmpty)
                    }
                    Section { Text("The example sends only the public client ID to the demo broker. The ConvoKit client secret stays on the backend.").font(.footnote).foregroundStyle(.secondary) }
                    if let error { Section { Text(error).foregroundStyle(.red) } }
                }
            }
        }
    }

    private func connect() async {
        busy = true; error = nil
        do {
            try await DemoBroker.join(roomId: roomId, userId: userId)
            let value = try ConvoKitClient(backendURL: URL(string: "https://convokit-backend.onrender.com")!, clientId: DemoBroker.clientId) { userId in
                try await DemoBroker.token(userId: userId)
            }
            try await value.connectUser(userId)
            client = value; connectedRoomId = roomId
        } catch { self.error = error.localizedDescription }
        busy = false
    }

    private func disconnect() { Task { await client?.disconnectUser(); client = nil; connectedRoomId = nil } }
}

enum DemoBroker {
    static let clientId = "998da6ce-2572-42b1-8c60-734ce09c88e4"
    private static let baseURL = URL(string: "https://convokit-open-chatroom.vercel.app")!

    static func token(userId: String) async throws -> String {
        let data = try await post(path: "/api/auth/token", body: ["appUserId": userId])
        let value = try JSONDecoder().decode(TokenResponse.self, from: data)
        return value.data.token
    }

    static func join(roomId: String, userId: String) async throws {
        let encoded = roomId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#")))!
        _ = try await post(path: "/api/chatrooms/\(encoded)/join", body: ["appUserId": userId])
    }

    private static func post(path: String, body: [String: String]) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        request.httpMethod = "POST"; request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientId, forHTTPHeaderField: "x-client-id")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return data
    }
}

private struct TokenResponse: Decodable { struct Payload: Decodable { let token: String }; let data: Payload }
