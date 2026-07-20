# textify

A real-time chat app built with **Flutter** and **Firebase**, with a distinctive
liquid-glass UI. Users are discovered by a unique **@username**, chat 1:1 or in
groups, reply and react to messages, and get on-device notifications for new
messages — all backed by live Firestore streams and Riverpod state management.

---

## Table of contents

- [Functionality](#functionality)
- [Tech stack](#tech-stack)
- [Architecture](#architecture)
- [Project structure](#project-structure)
- [Firestore data model](#firestore-data-model)
- [Security rules](#security-rules)
- [Notable implementation details](#notable-implementation-details)
- [Running the app](#running-the-app)
- [Limitations & roadmap](#limitations--roadmap)

---

## Functionality

### Authentication & identity
- **Email/password** and **Google** sign-in.
- **Email verification gate** — email sign-ups must verify before entering the app. A dedicated screen auto-polls and advances the instant the link is clicked; Google accounts are pre-verified and skip it.
- **Unique usernames** — every user has a globally unique, space-free `@username` (how people find each other) and a free-form **display name** (which may be duplicated).
- **Atomic sign-up** — the account and the username reservation succeed or fail together; a taken username fails at the form with no orphaned account.

### Messaging
- **1:1 and group chats.** Start a direct chat by searching an exact `@username`, or select several people to create a group.
- **Real-time everything** — the chat list, messages, unread counts, and mute state are all live Firestore streams; new messages appear across devices with no refresh.
- **Unread badges & mute** — per-user unread counters (incremented server-side via `FieldValue.increment`) and a per-user mute toggle.
- **Swipe-to-reply** — drag a bubble past a small threshold to quote it (with haptic feedback); a glass reply-preview bar appears above the composer. Replies render a tappable quoted strip that scrolls to and highlights the original message. The quote snippet is denormalized so it survives even if the original is deleted.
- **Hold-to-react** — long-press a message for an emoji reaction picker; reactions aggregate by emoji with counts, and your own is highlighted.
- Message payload types are modeled for **text / image / video / audio**; text is fully wired, media rendering is present and media sending is gated until the Storage phase.

### Notifications
- **On-device local notifications** for new messages while the app is alive (foreground or backgrounded), driven by the live chats listener — **no FCM / push / backend**.
- Skips messages you sent, muted chats, and the chat you're currently viewing; deduped on message id.
- Tapping a notification **deep-links** straight into that conversation.

### Settings & profile
- Change username (only if free, enforced by a transaction), edit display name and status/note.
- Light / dark / system **theme switch**.
- Sign out and delete account.

### Design language
- **Liquid-glass** cards, buttons, and chips (blurred, translucent, bright-rimmed).
- A soft top **color-glow gradient** over a flat background.
- Rounded **Fredoka** typography, deterministic per-user avatar colors, a custom hand-drawn **speech-bubble "T" logo**, and a typewriter intro on the login screen.

---

## Tech stack

| Concern | Choice |
| --- | --- |
| Framework / language | Flutter, Dart (SDK ^3.8) |
| State management | `flutter_riverpod` |
| Navigation | `go_router` (with auth-driven redirects) |
| Auth | `firebase_auth` + `google_sign_in` |
| Database | `cloud_firestore` (real-time streams) |
| Core | `firebase_core` |
| Local notifications | `flutter_local_notifications` |
| Typography | `google_fonts` (Fredoka) |
| Media picking | `image_picker` |
| Utilities | `intl` (dates), `uuid` (ids) |

> Firebase config is provided via the native files (`google-services.json` /
> `GoogleService-Info.plist`) — there is intentionally **no** `firebase_options.dart`.

---

## Architecture

Textify is organized **feature-first**, with each feature split into three layers:

```
feature/
  data/          repositories + Riverpod providers (all Firebase access lives here)
  domain/        immutable models with fromDoc/toMap serialization
  presentation/  screens & widgets (pure UI, no Firebase calls)
```

Cross-cutting concerns (theme, shared widgets, router, notifications, utils) live
under `core/`.

### Key principles

**1. Repository pattern — Firebase is behind a seam.**
The UI never calls `FirebaseFirestore`/`FirebaseAuth` directly. Three repositories
own all backend access:
- `AuthRepository` — FirebaseAuth + Google + email verification.
- `UserRepository` — profiles, the `usernames/{name}` uniqueness index, and username transactions.
- `ChatRepository` — real-time chat/message streams, idempotent chat creation, batched sends, reactions.

This keeps all Firebase knowledge in ~3 files and makes the data source swappable/testable.

**2. Reactive state via Riverpod providers.**
- `StreamProvider`s expose live data: `authStateProvider`, `currentUserProfileProvider`, `userProfileProvider(uid)`, `chatsStreamProvider`, `chatProvider(chatId)`, `chatMessagesProvider(chatId)`.
- Plain `Provider`s expose repositories and derived values (`chatRepositoryProvider`, `unreadTotalProvider`, `currentUidProvider`).
- `StateProvider`s hold ephemeral UI/coordination state (`openChatIdProvider`, `pendingChatIdProvider`, `authStateVersionProvider`).

**3. Routing driven by a single derived auth status.**
`appAuthStatusProvider` collapses auth + profile into one enum:

```
loading → signedOut → needsVerification → needsProfile → ready
```

`go_router` reads it in `redirect` and sends the user to the right screen
(splash, login, verify-email, choose-username, or the app). A `ChangeNotifier`
bridge re-evaluates the redirect whenever the status changes.

**4. Security enforced in Firestore rules**, not just the client (see below).

### Data flow (sending a message)

```
MessageInputBar ──onSendText──▶ ChatDetailScreen
      │ (attaches replyTo draft)
      ▼
ChatRepository.sendText()  ──batch──▶ Firestore
      • add message doc (serverTimestamp, optional replyTo)
      • update chat: lastMessage summary + lastMessageAt + unread increments
      ▼
chatMessagesProvider / chatsStreamProvider  ──snapshot──▶ UI updates live
      ▼
messageNotifier (watching chatsStreamProvider) ──▶ local notification (if applicable)
```

---

## Project structure

```
lib/
  main.dart                         # Firebase init, ProviderScope, app root + notification wiring
  core/
    theme/
      app_colors.dart               # palette (gradient glow, accent, glass fills, avatar colors)
      app_theme.dart                # light/dark ThemeData, Fredoka typography
      theme_controller.dart         # ThemeMode notifier
    widgets/
      gradient_background.dart       # top color-glow over flat background
      glass_surface.dart            # GlassSurface + GlassButton (liquid glass)
      frosted_card.dart             # card wrapper over GlassSurface
      user_avatar.dart              # deterministic colored initials avatar
      textify_logo.dart             # hand-drawn speech-bubble "T" mark
      typewriter_text.dart          # one-shot typewriter animation
    router/app_router.dart          # go_router + appAuthStatus redirects
    notifications/
      notification_service.dart     # flutter_local_notifications wrapper + provider
      message_notifier.dart         # watches chats stream → fires notifications
    utils/time_format.dart          # timestamp/duration formatting
  features/
    auth/
      data/       auth_repository.dart · auth_controller.dart
      domain/     app_user.dart
      presentation/ login · splash · choose_username · verify_email screens
    users/
      data/       user_repository.dart   # profiles, username index, appAuthStatus provider
    chats/
      data/       chat_repository.dart
      domain/     chat.dart · message.dart (Message, ReplyRef, MessageType)
      presentation/ chats · chat_detail · new_chat screens
                    widgets/ chat_tile · message_bubble · message_input_bar · swipe_to_reply
    settings/
      presentation/ settings_screen.dart
firestore.rules                     # security rules (paste into Firebase console)
```

---

## Firestore data model

```
users/{uid}
  username       string     // unique, lowercase, no spaces
  displayName    string     // free text, may duplicate
  email          string
  note           string     // status line
  photoUrl       string?
  createdAt      timestamp

usernames/{username}         // uniqueness index + O(1) "find by username" lookup
  uid            string      // doc id IS the username

chats/{chatId}
  isGroup        bool
  title          string?     // group name; 1:1 titles derived from the other member
  memberIds      [uid]
  createdBy      uid
  createdAt      timestamp
  lastMessage    { id, text, senderId, type }   // summary for the list + notif dedupe
  lastMessageAt  timestamp   // orders the chat list
  unread         { uid: int }
  muted          { uid: bool }

chats/{chatId}/messages/{messageId}
  senderId       uid
  type           string      // 'text' (image/video/audio reserved)
  text           string
  sentAt         timestamp   // serverTimestamp
  replyTo        { messageId, senderName, snippet }?   // set only at creation
  reactions      { uid: emoji }
```

**Username uniqueness** is guaranteed two ways: the `usernames/{username}` doc id
is the username (so a create only succeeds if it doesn't exist), and the client
writes the profile + reservation in a single **transaction**.

---

## Security rules

Enforced server-side in [`firestore.rules`](firestore.rules):

- **`users/{uid}`** — readable by any signed-in user (needed for search and rendering names/avatars); writable only by the owner.
- **`usernames/{username}`** — `create` only when absent and pointing at the caller (uniqueness); `delete` only by the owner; never updatable.
- **`chats/{chatId}`** — read/update restricted to members; a creator must include themselves.
- **`chats/.../messages/{id}`** — members read; the sender creates their own message; the **only** allowed `update` is to `reactions.{yourUid}` (a user can never touch another field like `text`/`replyTo`, nor anyone else's reaction).

---

## Notable implementation details

- **Idempotent 1:1 chats.** Direct chats use a deterministic doc id (`sortedUidA__sortedUidB`) and are created with a merge-write **without a read** — reading a not-yet-existing chat is denied by the member-only rule, so a read-before-write would throw.
- **Live `emailVerified`.** `reload()` refreshes `FirebaseAuth.currentUser` but not the auth stream snapshot, so the router reads verification from the live `currentUser` and a version tick forces re-evaluation — the verify screen advances without an app restart.
- **Reply-jump highlight.** Each message carries a `GlobalKey`; tapping a quote uses `Scrollable.ensureVisible` + a soft `AnimatedContainer` accent pulse (with an "Original message unavailable" fallback).
- **Notification dedupe.** The chat's `lastMessage` summary carries the message id so the on-device notifier can dedupe redelivered Firestore snapshots (with an insertion-ordered, size-capped seen-set).
- **Batched sends.** Sending a message writes the message doc and updates the chat's summary + unread counters in one `WriteBatch`.

---

## Running the app

Requires the Flutter SDK and a configured Firebase project (Auth: Email/Password
+ Google; Cloud Firestore enabled).

```bash
flutter pub get
flutter run
```

Firebase setup (done via the console GUI): register the Android/iOS app, drop in
`google-services.json` / `GoogleService-Info.plist`, enable the auth providers,
create the Firestore database, and publish `firestore.rules`. The first live
chats query will prompt you to create a composite index (member + `lastMessageAt`)
via a one-click link.

> **Platforms:** developed and tested on **Android**. iOS is configured but
> requires a Mac to build. Local notifications need a full rebuild (native +
> Gradle changes) and the runtime notification permission.

---

## Limitations & roadmap

- **No push when the app is fully killed** — notifications are a live on-device
  Firestore listener, not FCM (a deliberate scope choice).
- **Media messages** (photo/video/voice) are modeled and rendered but sending is
  gated until **Firebase Storage** is enabled.
- Planned: media/Storage phase, per-message read receipts, and profile photos.
