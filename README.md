<p align="center"><img src="assets/icon1024.png" width="140" alt="HAPPY icon"></p>

# HAPPY

A fast, native macOS AI assistant that lives one hotkey away, named after my Shih Tzu. Press **⌘⇧Space**, ask, get a streamed answer, press **Esc**. Built in Swift 6 with no third-party dependencies, and it runs fully offline on a local model.

<!-- Add your demo here: edit this file on github.com and drag your screen recording into the editor. -->

## Features

- **Instant floating panel**: global hotkey (Carbon `RegisterEventHotKey`, no Accessibility permission) and a non-activating `NSPanel` that never steals focus from the app you're in
- **Streaming responses**: server-sent-events parsing with cancellation (Stop button)
- **Rich rendering**: Markdown, fenced code blocks with language labels and one-click copy
- **Pluggable providers**: local models through [Ollama](https://ollama.com) (free, private, offline) or Google Gemini, behind one `AIService` protocol
- **Local tools, no AI call needed**: exact math, time zones, `open <app>`, `open <website>`
- **Memory you control**: `remember that ...` saves notes to a plain-text file on your Mac; `forget everything` wipes it
- **Secure by default**: API keys live in the macOS Keychain, never in the code or the repo
- **Native**: menu-bar app (no Dock icon), launch at login, configurable shortcut

## Quick start (everything is free)

Requirements: macOS 14+ and Xcode (free from the App Store).

Install [Ollama](https://ollama.com/download), then pull a small model:

    ollama pull llama3.2:3b

Then build and run the app:

    git clone https://github.com/sainishrajput-Apk/happy.git
    cd happy
    ./scripts/bundle.sh
    open build/HAPPY.app

The app is ad-hoc signed. If macOS blocks the first launch, right-click it in Finder and choose **Open**.

## Commands

| Say | What happens |
|---|---|
| `what is 2273 - 83984 + 938839` | Exact answer, instantly (built-in calculator) |
| `time in Tokyo` | Current time in that zone |
| `open Safari` / `open github.com` | Launches the app or website |
| `remember that I prefer short answers` | Saves a note to memory |
| `remember my clipboard` | Saves what you last copied |
| `what do you remember?` / `forget everything` | Shows or wipes memory |
| `... using my clipboard` | Attaches clipboard text to that one message |

## Architecture

    Sources/HAPPY/
    ├── HAPPYApp.swift, AppDelegate.swift   app lifecycle, menu-bar item
    ├── HotkeyManager.swift                 global shortcut (Carbon)
    ├── WindowManager.swift                 floating NSPanel, animations
    ├── Models/                             ChatMessage, AIError, provider config
    ├── Services/
    │   ├── AIService.swift                 provider protocol (AsyncThrowingStream)
    │   ├── OllamaService.swift             streaming SSE client
    │   ├── GeminiService.swift             streaming SSE client
    │   ├── LocalCommandService.swift       local tools + memory layer
    │   ├── MathEvaluator.swift             recursive-descent calculator
    │   └── MemoryStore.swift, KeychainService
    ├── ViewModels/                         ChatViewModel, SettingsViewModel (@MainActor)
    └── Views/                              SwiftUI chat, Markdown, Settings

Design notes:

- Providers are swappable behind a single protocol, and the active one is chosen per message from Settings.
- Streaming updates to the UI are throttled to roughly 10 Hz, and Markdown is rendered only when a reply completes, to keep long answers smooth on older Macs.
- Swift 6 strict concurrency throughout: view models are `@MainActor`, models are `Sendable`.

## Testing

Run `swift test`. The suite has over 90 unit tests covering stream parsing (including chunks split across reads), error mapping, URL building, settings persistence, the calculator, command parsing and the memory store. No test touches the network.

## Privacy

- With **Ollama**, everything stays on your Mac.
- With **Gemini**, your messages (and saved memory, if any) are sent to Google. On the free tier, Google may use them to improve its products, so use Ollama for anything private.
- HAPPY never records the screen or microphone, and it only reads the clipboard when you ask it to.

## Responsible use

HAPPY is a visible, user-driven assistant. It is not designed to hide from other software, and it should not be used where outside assistance is prohibited, such as exams and assessments.

## Limitations

- Small local models can be slow on older Intel Macs and are weaker at facts and math than cloud models.
- The Settings screen has a few cosmetic rough edges (tracked in the roadmap).

## Roadmap

- [ ] Settings: "Test connection" button
- [ ] Conversation history
- [ ] Push-to-talk voice input
- [ ] Notarized release build

## License

MIT
