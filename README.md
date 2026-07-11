## M3RCI - UniMind iOS App

A native iOS client for the M3RCI UniMind AI multi-agent workforce platform.

### Prerequisites

- macOS Ventura (14.0) or newer
- Xcode 15.0 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Setup

```bash
# 1. Generate Xcode project
xcodegen

# 2. Open the project
open BYOK.xcodeproj

# 3. Select a simulator or your device, then Build & Run (Cmd+R)
```

### Architecture

- **SwiftUI** with **MVVM** pattern
- **Swift Concurrency** (async/await) for networking
- **URLSession** with SSE streaming for real-time chat
- **Keychain** for secure token storage
- **iOS 16+** deployment target