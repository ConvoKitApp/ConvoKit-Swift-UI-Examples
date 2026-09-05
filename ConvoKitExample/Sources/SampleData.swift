import ConvoKit
import UIKit

enum SampleData {
    static let now = Date(timeIntervalSince1970: 1_788_528_000)
    static let maya = Participant(id: "member_maya", appUserId: "maya", name: "Maya Chen", role: "READ_WRITE", lastReadAt: now)
    static let alex = Participant(id: "member_alex", appUserId: "alex", name: "Alex Rivera", role: "READ_WRITE", lastReadAt: now.addingTimeInterval(-20))
    static let sam = Participant(id: "member_sam", appUserId: "sam", name: "Sam Patel", role: "READ_WRITE", lastReadAt: now.addingTimeInterval(-300))

    static let launch = Conversation(
        id: "launch-room", title: "Launch room", appId: "demo", displayTitle: "Launch room",
        description: "Release coordination", participants: [maya, alex, sam],
        createdAt: now.addingTimeInterval(-86_400), updatedAt: now
    )
    static let support = Conversation(
        id: "support-room", title: "Customer support", appId: "demo", displayTitle: "Customer support",
        description: "Priority inbox", participants: [maya, alex],
        createdAt: now.addingTimeInterval(-172_800), updatedAt: now.addingTimeInterval(-120)
    )
    static let design = Conversation(
        id: "design-room", title: "Design review", appId: "demo", displayTitle: "Design review",
        description: "New onboarding flow", participants: [maya, sam],
        createdAt: now.addingTimeInterval(-259_200), updatedAt: now.addingTimeInterval(-1_800)
    )
    static let incident = Conversation(
        id: "incident-room", title: "Incident response", appId: "demo", displayTitle: "Incident response",
        description: "API status and customer updates", participants: [maya, alex, sam],
        createdAt: now.addingTimeInterval(-345_600), updatedAt: now.addingTimeInterval(-7_200)
    )
    static let research = Conversation(
        id: "research-room", title: "User research", appId: "demo", displayTitle: "User research",
        description: "September interview notes", participants: [maya, alex],
        createdAt: now.addingTimeInterval(-432_000), updatedAt: now.addingTimeInterval(-86_400)
    )

    static let conversations = [launch, support, design, incident, research]
    static let messages = [
        Message(id: "m1", conversationId: launch.id, senderId: alex.appUserId, text: "The new onboarding is ready for review.", createdAt: now.addingTimeInterval(-420)),
        Message(id: "m2", conversationId: launch.id, senderId: maya.appUserId, text: "Looks great. I added the latest product shot.", media: [.image(name: "onboarding.png", url: "https://cdn.example.com/onboarding.png", size: 184_320)], createdAt: now.addingTimeInterval(-300)),
        Message(id: "m3", conversationId: launch.id, senderId: sam.appUserId, text: "Sharing the launch checklist too.", media: [.file(name: "launch-checklist.pdf", url: "https://cdn.example.com/launch-checklist.pdf", size: 923_000)], createdAt: now.addingTimeInterval(-180)),
        Message(id: "m4", conversationId: launch.id, senderId: maya.appUserId, text: "Perfect. We are cleared for Friday.", createdAt: now.addingTimeInterval(-40)),
    ]

    static func imageData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 520))
        return renderer.pngData { context in
            let cg = context.cgContext
            let colors = [UIColor(red: 0.12, green: 0.08, blue: 0.35, alpha: 1).cgColor, UIColor(red: 0.55, green: 0.25, blue: 0.95, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 800, y: 520), options: [])
            let style = NSMutableParagraphStyle(); style.alignment = .center
            ("CONVOKIT\nSHIP CHAT, NOT INFRA" as NSString).draw(in: CGRect(x: 80, y: 180, width: 640, height: 180), withAttributes: [
                .font: UIFont.systemFont(ofSize: 42, weight: .bold), .foregroundColor: UIColor.white, .paragraphStyle: style,
            ])
        }
    }
}
