# OdinAgent

OdinAgent is a local AI-powered desktop dog assistant for macOS built with SwiftUI, Whisper.cpp, Ollama, and animated phoneme-based mouth sprites.

Odin listens for wake phrases such as:

- "Hi Odin"
- "Hey Oden"
- "Yo Uden"

After hearing a wake phrase, Odin:
1. Transcribes speech locally using Whisper.cpp
2. Sends the command to a local LLM using Ollama
3. Speaks the response with animated mouth movement
4. Saves conversation memory locally

Everything runs locally on-device.

---

# Features

## Voice Activation
Supports dynamic wake phrase combinations:

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

---

## Local Speech Recognition
Uses Whisper.cpp with:
- `ggml-base.en.bin`

Speech recording automatically:
- starts when voice detected
- stops after 2 seconds of silence
- transcribes locally

No cloud transcription required.

---

## Local AI Brain
Uses Ollama with:
- `llama3.2:3b`

Odin can:
- answer questions
- remember conversations
- tell jokes
- respond conversationally
- maintain personality

No OpenAI API required.

---

## Animated Talking Dog
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

---

## Idle Animation
Odin supports:
- idle state
- blinking
- speaking state
- thinking state
- listening state

---

## Local Persistent Memory
Conversation history is stored locally in:

```text
~/Documents/OdinMemory.txt