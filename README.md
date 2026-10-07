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

Requirements: macOS 14+, Xcode (free from the App Store).

```bash
# 1. Install Ollama (https://ollama.com/download), then pull a small model
ollama pull llama3.2:3b

# 2. Build and run
git clone https://github.com/sainishrajput-Apk/happy.git
cd happy
./scripts/bundle.sh
open build/HAPPY.app
```

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
|
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 Sainish Singh

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
