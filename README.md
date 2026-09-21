# ConvoKit SwiftUI examples

A public iOS example app for the compiled `ConvoKit` and `ConvoKitUI` Swift package products. The SDK implementation remains private.

The app uses a native iOS tab bar and navigation stacks for four examples:

- **Chats** shows `ConversationListView` as a standard Messages-style inbox with latest-message previews, activity times and unread badges from `InboxSummary` values, and pushes a native conversation screen. One room is read but privately marked unread (`isUnread` with a count of 0), so the package's default row renders its numberless dot (accessible name `Unread`) instead of a badge. Every sample `Message` carries its content `revision`; one of Maya's rows was edited once (`revision: 1`, `isEdited`), so the package's default message row shows `Edited` beside its time while its attachment is untouched. The pushed screen is the controlled `ConversationView` with the package's default rows and composer over a `ShowcaseRoom` fixture (local `messages` and `editingMessage` state plus `onEditMessage` / `onCancelEditing` / `onSaveEdit` / `onDeleteMessage`; a save bumps that message's `revision`, a delete drops it), so Maya's own rows get the default context menu and the named accessibility actions **Edit message** / **Delete message**, `remove` runs the package's "Delete this message?" confirmation, and the default composer switches to its edit mode (the `Editing message` banner, `Cancel editing`, `Save message`) without the backend.
- **Support** demonstrates brand tinting without replacing the navigation bar or system controls, over the same `ShowcaseRoom` fixture, so the tinted default rows and composer offer the same edit and delete actions and edit mode.
- **Ops** demonstrates dense, host-rendered message rows inside a normal iOS conversation screen, again over a `ShowcaseRoom` fixture: the custom row's context menu offers **Edit message** / **Delete message** from `MessageContext.edit` / `remove` on Maya's own rows only, `remove` runs the package's "Delete this message?" confirmation, the composer switches to its edit mode and the row shows `Edited` from `MessageContext.isEdited`. Nothing is re-implemented: eligibility, the confirmation and the edit-mode composer come from the released package.
- **Live** joins an authorized room through the demo backend and opens the SDK-backed inbox (`ConvoKitConversationList`) with the joined room on top; previews, unread counts and the private mark-unread state come from the released package. A custom `row:` adds a leading swipe action, **Mark unread**, that calls `ConversationListController.markUnread(_:)` on the controller handed over by `onController`; the controller patches the row's summary (dot on, `privateStateVersion` bumped), other devices catch up through `inbox_activity`, and opening the room acknowledges with the version captured at open, which clears the marker. The room itself is the package's `ConvoKitConversation` with its default rows and composer, so your own confirmed messages get the context menu and the named accessibility actions **Edit message** / **Delete message**, saves send the snapshot revision (a `REVISION_CONFLICT` reloads the row and keeps your draft), deletions tombstone the row on every device, and edited rows show `Edited`. The author endpoints need the 0.8 backend, which the hosted ConvoKit API the example talks to already serves; against an older backend a save or delete fails with a 404 that keeps the row and edit mode.

![Standard components](doc/screenshots/standard-components.png)

![Branded support](doc/screenshots/branded-support.png)

![Compact operations](doc/screenshots/compact-operations.png)

## Run

Open `ConvoKitSwiftExample.xcodeproj` in Xcode and run the `ConvoKitSwiftExample` scheme on an iOS 15+ simulator.

The live example sends the public client ID to `https://convokit-open-chatroom.vercel.app`. The client secret is not present in this repository or the app binary; the backend owns token issuance and room membership policy.
