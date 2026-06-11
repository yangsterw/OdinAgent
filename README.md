# OdinAgent

OdinAgent is a local AI-powered desktop dog assistant for macOS built with SwiftUI, Whisper.cpp, Ollama, EventKit, Trello, and animated phoneme-based mouth sprites.

Odin listens for wake phrases such as:

- "Hi Odin"
- "Hey Oden"
- "Yo Uden"

After hearing a wake phrase, Odin:

1. Transcribes speech locally using Whisper.cpp.
2. Routes app, Trello, Calendar, and assistant commands.
3. Uses a local Ollama model when an LLM response or intent parse is needed.
4. Speaks the response with animated mouth movement.
5. Saves conversation memory locally.

Most assistant behavior runs locally on-device. Trello commands call the Trello API, and Calendar commands use macOS Calendar permissions through EventKit.

## Features

### Voice Activation

Supports dynamic wake phrase combinations.

Prefixes:

- hey
- hi
- okay
- okey
- ok
- yo
- hello

Names:

- odin
- oden
- uden

Examples:

- "Hi Odin"
- "Yo Oden"
- "Okay Uden"

### Local Speech Recognition

Uses Whisper.cpp with `ggml-base.en.bin`.

Speech recording automatically:

- starts when voice is detected
- stops after silence
- transcribes locally

### Local AI Brain

Uses Ollama. The default configured model is:

```text
gemma4:31b-it-qat
```

Odin can:

- answer questions
- remember conversations
- respond conversationally
- maintain a concise dog-assistant personality
- stream partial responses while thinking

No OpenAI API is required.

### App Commands

Odin can open and close supported macOS apps, including:

- Spotify
- Safari
- Xcode
- Visual Studio Code
- Terminal
- Microsoft Outlook

### Trello Commands

Odin can:

- list available Trello boards and columns
- show open cards in a column
- add cards to Trello lists
- clarify incomplete Trello requests

Trello access is configured through `OdinAgent/Config/Secrets.swift`.

### Calendar Commands

Odin can:

- read today's schedule
- read tomorrow's schedule
- read this week, next week, or the next N weeks
- create calendar events after confirmation
- clarify incomplete calendar requests

Calendar support uses EventKit and requires macOS Calendar permission.

### Animated Talking Dog

Odin uses phoneme mouth sprites:

- A
- E
- O
- U
- SH
- MBP
- FV
- TH
- etc.

Mouth movement synchronizes with TTS speech.

### Idle Animation

Odin supports:

- idle
- listening
- thinking
- speaking
- blinking

Runtime state is represented by `OdinState` instead of raw strings.

### Local Persistent Memory

Conversation history is stored locally in:

```text
~/Documents/OdinMemory.txt
```

## Architecture

The app is assembled through `OdinDependencyContainer`, with live defaults defined in `OdinAppConfiguration`.

Key layers:

- `OdinMainView`: SwiftUI layout and bindings.
- `OdinMainViewModel`: main UI orchestration, state transitions, command submission, model loading, speech/listening coordination, and brain task cancellation.
- `OdinBrainService`: assistant response flow, built-in commands, memory recording, command routing, and LLM fallback.
- `OdinIntentRouterService`: routes commands to app, Trello, Calendar, or general assistant handling.
- `OdinCommandService`: executes routed commands and manages pending confirmations/clarifications.
- `OdinOllamaService`: Ollama generate, stream, and model-list API access.
- `OdinTrelloService`: user-facing Trello assistant behavior.
- `OdinTrelloRepository`: Trello caching, board/list lookup, and list resolution.
- `OdinTrelloClient`: raw Trello HTTP API calls.
- `OdinCalendarService`: EventKit calendar reads and writes.
- `OdinPromptBuilders`: prompt construction for brain, Trello intent parsing, and Calendar intent parsing.
- `OdinHTTPClient`: shared HTTP abstraction used by Ollama and Trello code.

The app intentionally keeps app alias and bundle ID mappings in their existing services for now.

## Configuration

Runtime defaults live in:

```text
OdinAgent/Config/OdinAppConfiguration.swift
```

This includes:

- Ollama base URL
- preferred Ollama model
- Ollama context window
- Trello API base URL
- Trello cache duration
- default Trello list
- day/night theme hours

Secrets live separately in:

```text
OdinAgent/Config/Secrets.swift
```

That file should provide Trello API keys, tokens, and configured list IDs.

## Testing

Run the app test suite with:

```sh
xcodebuild -project OdinAgent/OdinAgent.xcodeproj -scheme OdinAgent -destination 'platform=macOS' test
```

Current tests cover:

- app command routing
- Trello rule-based parsing
- Calendar rule-based routing
- LLM intent routing with board context
- prompt builder behavior
- brain service command handling without real memory or Ollama calls
- pending Calendar confirmation flow
- Trello repository list resolution

## Build

Build the macOS app with:

```sh
xcodebuild -project OdinAgent/OdinAgent.xcodeproj -scheme OdinAgent -destination 'platform=macOS' build
```
