# ConvoKit SwiftUI examples

A public iOS example app for the compiled `ConvoKit` and `ConvoKitUI` Swift package products. The SDK implementation remains private.

The app includes four modes:

- **Standard** shows `ConversationListView` and `ConversationView` as independent controlled components.
- **Branded** demonstrates a custom theme and header slot.
- **Compact** demonstrates dense, host-rendered message rows.
- **Live** joins an authorized room through the demo backend and opens the SDK-backed realtime component.

![Standard components](doc/screenshots/standard-components.png)

![Branded support](doc/screenshots/branded-support.png)

![Compact operations](doc/screenshots/compact-operations.png)

## Run

Open `ConvoKitSwiftExample.xcodeproj` in Xcode and run the `ConvoKitSwiftExample` scheme on an iOS 15+ simulator.

The live example sends the public client ID to `https://convokit-open-chatroom.vercel.app`. The client secret is not present in this repository or the app binary; the backend owns token issuance and room membership policy.
