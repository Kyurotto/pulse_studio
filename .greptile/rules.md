# Greptile PR Review Rules

This repository is a **Flutter / Dart** cross-platform music application utilizing **SQLite** for local storage, **just_audio** for audio playback, and **Firebase** (Auth & Firestore) for cloud features.

When reviewing pull requests in this repository, prioritize the following standards:

---

## 1. Flutter & Dart Standards
- **Asynchronous Safety (`mounted` checks)**:
  - Any `BuildContext` usage or `setState()` call that occurs after an `await` within a `State` class must verify `if (!mounted) return;` or `if (mounted)`.
- **Resource Management & Disposal**:
  - All controllers (`TextEditingController`, `AnimationController`, `ScrollController`), audio players (`AudioPlayer`), and `StreamSubscription` instances must be cleaned up in the `dispose()` method.
- **Null Safety & Exceptions**:
  - Avoid force-unwrapping with `!` unless nullability has been explicitly guarded.
  - Wrap network, Firebase, and audio streaming calls in structured `try-catch` blocks with user-friendly error handling.

---

## 2. Database & Data Safety (sqflite / Firestore)
- **Parameterized Queries**:
  - Always use `whereArgs` in `sqflite` operations. Do not concatenate user-provided strings into raw SQL queries.
- **Batching & Transactions**:
  - When performing multiple write or update operations, use transactions or batch operations to prevent partial writes.

---

## 3. Audio Lifecycle & Concurrency
- **Audio Session & States**:
  - Ensure audio operations handle errors (such as network loss, missing file path, or audio decoding failures) gracefully.
  - Avoid race conditions when rapidly changing tracks or playback states.

---

## 4. Security & Sensitive Data
- **No Hardcoded Secrets**:
  - Do not introduce hardcoded API keys, private tokens, or authentication secrets into repository source code.
