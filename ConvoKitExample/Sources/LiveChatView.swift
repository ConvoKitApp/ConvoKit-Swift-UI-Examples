import ConvoKit
import ConvoKitUI
import SwiftUI

/// Joins a room through the demo broker, then shows the SDK-backed inbox
/// (`ConvoKitConversationList` serves previews, activity times, unread counts
/// and the private mark-unread state itself) with the joined room pushed on
/// top of it. The package ships no row affordance for "mark unread", so the
/// list uses a custom `row:` that adds a swipe action calling the wrapper's
/// `ConversationListController`, handed over once through `onController`.
struct LiveChatView: View {
    @State private var userId = "swift_guest"
    @State private var roomId = ""
    @State private var client: ConvoKitClient?
    @State private var inbox: ConversationListController?
    @State private var openRoomId: String?
    @State private var openRoom: Conversation?
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            if let client {
                ConvoKitConversationList(client: client, selectedConversationId: openRoomId, onSelect: { openRoom = $0; openRoomId = $0.id }, row: { context in
                    AnyView(LiveInboxRow(context: context).swipeActions(edge: .leading) {
                        Button { Task { await inbox?.markUnread(context.conversation.id) } } label: { Label("Mark unread", systemImage: "envelope.badge") }
                            .tint(.blue)
                    })
                }, onController: { inbox = $0 })
                .navigationTitle("Inbox")
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Leave", action: disconnect) } }
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
                .navigationTitle("Join a room")
            }
        }
        .background(roomLink)
    }

    private var roomLink: some View {
        NavigationLink(isActive: Binding(get: { openRoomId != nil }, set: { if !$0 { openRoomId = nil; openRoom = nil } })) {
            if let client, let openRoomId, let chat = try? ConvoKitConversation(client: client, conversationId: openRoomId, configuration: .init(showsHeader: false)) {
                chat.navigationTitle(openRoom?.displayTitle ?? openRoomId).navigationBarTitleDisplayMode(.inline)
            }
        } label: {
            EmptyView()
        }
        .hidden()
    }

    private func connect() async {
        busy = true; error = nil
        do {
            try await DemoBroker.join(roomId: roomId, userId: userId)
            let value = try ConvoKitClient(clientId: DemoBroker.clientId) { userId in
                try await DemoBroker.token(userId: userId)
            }
            try await value.connectUser(userId)
            client = value; openRoom = nil; openRoomId = roomId
        } catch { self.error = error.localizedDescription }
        busy = false
    }

    private func disconnect() { Task { await client?.disconnectUser(); client = nil; inbox = nil; openRoomId = nil; openRoom = nil } }
}

/// A host-rendered inbox row over the summary the list controller keeps for
/// the conversation: the count badge (`99+` when capped) while messages are
/// unread, otherwise the numberless dot when the room is only marked unread
/// (`isUnread` with a count of 0), and a bold title in both cases. The
/// controller patches `isUnread`, `unreadMarkedAt` and `privateStateVersion`
/// after `markUnread`, and the same room's acknowledgement clears them.
private struct LiveInboxRow: View {
    let context: ConversationItemContext
    @Environment(\.convoKitTheme) private var theme

    var body: some View {
        let conversation = context.conversation, summary = context.summary
        let unread = summary?.isUnread ?? false
        HStack(spacing: 12) {
            ConvoKitAvatar(name: conversation.displayTitle, imageURL: conversation.imageUrl)
            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.displayTitle).font(unread ? .headline.weight(.bold) : .headline).foregroundStyle(.primary).lineLimit(1)
                Text(preview ?? conversation.description ?? "No messages yet").font(.subheadline).foregroundStyle(theme.secondaryText).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(summary?.activityAt ?? conversation.updatedAt, style: .time).font(.caption2).foregroundStyle(theme.secondaryText)
                if let summary, summary.unreadCount > 0 || summary.unreadCountCapped {
                    Text(summary.unreadCountCapped || summary.unreadCount > 99 ? "99+" : String(summary.unreadCount))
                        .font(.caption2.weight(.semibold)).foregroundStyle(theme.outgoingText).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(theme.badge))
                        .accessibilityLabel(summary.unreadCountCapped ? "99+ unread" : "\(summary.unreadCount) unread")
                } else if unread {
                    Circle().fill(theme.badge).frame(width: 8, height: 8).accessibilityLabel("Unread")
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var preview: String? {
        guard let message = context.summary?.latestMessage else { return nil }
        let body = message.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = body.isEmpty ? (message.media.first?.name ?? (message.media.isEmpty ? "" : "Attachment")) : body
        guard !text.isEmpty else { return nil }
        return message.senderId == context.currentUserId ? "You: " + text : text
    }
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
