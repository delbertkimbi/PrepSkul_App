# Emoji reactions – send/receive path and log points

Use this to trace why emojis might not show on the other device. All log tags are from `LogService` (info/warning/error/success/debug).

---

## 1. Send path (user taps emoji)

| Step | Location | What to look for in logs |
|------|----------|---------------------------|
| User taps emoji | `agora_video_session_screen.dart` → `_handleReaction(emoji)` | N/A (UI) |
| Local animation | `_addReactionAnimation(emoji)` | N/A |
| Send call | `AgoraService.sendReaction(emoji)` | **`[EMOJI] sendReaction called:`** `emoji="…", dataStreamId=…, inChannel=…` |
| No stream / not in channel | `sendReaction` early return | **`Cannot send reaction (other user will not see it):`** `dataStreamId=…, … On web, data stream is often unavailable` |
| Encode & send via Agora | `sendReaction` → `_engine.sendStreamMessage` | **`Sending reaction:`** `emoji="…", message="reaction:…", bytes=…, streamId=…` then **`Sent reaction via data stream:`** |
| Send via Realtime (fallback) | `sendReaction` when using Supabase fallback | **`[EMOJI] Sent reaction via Realtime fallback:`** |
| Send error | `sendReaction` catch | **`Failed to send reaction:`** and **`Reaction send details:`** |

**Grep tips (sender):**
- `[EMOJI] sendReaction` – entry and whether it bailed (dataStreamId null, etc.)
- `Sent reaction via data stream` or `Sent reaction via Realtime` – success
- `Failed to send reaction` – Agora send failed

---

## 2. Data stream creation (required for Agora path)

| Step | Location | What to look for in logs |
|------|----------|---------------------------|
| After join success | `agora_service.dart` → `onJoinChannelSuccess` | **`Data stream created: streamId=…`** or **`createDataStream attempt … returned invalid id: 0`** / **`failed`** |
| Web deferred | Same, `kIsWeb` branch | Data stream is created 400 ms after join; look for the same messages after a short delay |
| Final failure | After 2 retries | **`Data stream creation failed after retries - emoji reactions and screen-share sync will not work. On web this is a known SDK limitation`** |

**Grep tips:**
- `Data stream created` – Agora path will work for sending
- `createDataStream attempt.*returned invalid id: 0` – typical on web (use Realtime fallback)
- `Data stream creation failed after retries` – only Realtime (or nothing) will work

---

## 3. Receive path (other peer)

| Step | Location | What to look for in logs |
|------|----------|---------------------------|
| Agora stream message | `agora_service.dart` → `onStreamMessage` | **`Received data stream: UID=…: "reaction:…"`** |
| Parsed as reaction | Same, `message.startsWith('reaction:')` | **`[EMOJI] Received reaction:`** `remoteUid=…, emoji="…"` and **`Received reaction from UID=…`** |
| Pushed to UI stream | `_reactionController.add(...)` | **`Reaction added to stream:`** `UID=…, emoji="…"` |
| Realtime fallback receive | Same file, Realtime `onBroadcast` | **`[EMOJI] Received reaction via Realtime:`** `fromUid=…, emoji="…"` |
| Screen subscribes | `agora_video_session_screen.dart` → `_setupListeners` | **`Displaying remote reaction:`** `… from UID=…` |
| Filter self | Same, `if (uid == myUid) return` | Reactions from self are not shown (no log). |

**Grep tips (receiver):**
- `Received data stream:` or `Received reaction via Realtime:` – something arrived
- `[EMOJI] Received reaction` – parsed and pushed to stream
- `Displaying remote reaction` – UI is showing it
- `Received reaction with empty emoji` – format/encoding issue

---

## 4. Quick checklist

- **Sender (e.g. web):** Do you see **`Sent reaction via data stream`** or **`Sent reaction via Realtime fallback`**? If neither, check **`Cannot send reaction`** and **`Data stream created`** / **`Data stream creation failed`**.
- **Receiver:** Do you see **`Received data stream:`** or **`Received reaction via Realtime:`** with `reaction:…`? If yes but no animation, check **`Displaying remote reaction`** and that `reactionStream` is subscribed.
- **Web:** If **`createDataStream … returned invalid id: 0`**, the app uses the Supabase Realtime fallback for reactions; both peers subscribe to `session_reactions_$sessionId` so delivery works. Look for **`Reaction Realtime channel subscribed`** and **`Sent reaction via Realtime fallback`**.

---

## 5. Code references

- Send: `lib/features/sessions/services/agora_service.dart` → `sendReaction`
- Data stream creation: same file → `onJoinChannelSuccess` → `tryCreateDataStream`
- Receive (Agora): same file → `onStreamMessage` (reaction: branch)
- Receive (Realtime): same file → Realtime channel `session_reactions_$sessionId` → `onBroadcast` → `_reactionController.add`
- UI: `lib/features/sessions/screens/agora_video_session_screen.dart` → `_reactionSubscription` (reactionStream), `_handleReaction`, `_addReactionAnimation`
