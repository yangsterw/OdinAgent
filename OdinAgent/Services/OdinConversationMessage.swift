//
//  OdinConversationMessage.swift
//  OdinAgent
//
//  Created by yang on 5/20/26.
//


import Foundation

struct OdinConversationMessage {
    let role: String
    let text: String
    let date: Date
}

actor OdinConversationService {

    private var messages: [OdinConversationMessage] = []

    private let maxMessages = 8
    private let conversationTimeout: TimeInterval = 10 * 60

    func addUserMessage(_ text: String) {
        resetIfExpired()

        messages.append(
            OdinConversationMessage(
                role: "User",
                text: text,
                date: Date()
            )
        )

        trim()
    }

    func addOdinMessage(_ text: String) {
        resetIfExpired()

        messages.append(
            OdinConversationMessage(
                role: "Odin",
                text: text,
                date: Date()
            )
        )

        trim()
    }

    func contextText() -> String {
        resetIfExpired()

        guard !messages.isEmpty else {
            return ""
        }

        return messages
            .map { "\($0.role): \($0.text)" }
            .joined(separator: "\n")
    }

    func clear() {
        messages.removeAll()
    }

    private func trim() {
        if messages.count > maxMessages {
            messages = Array(messages.suffix(maxMessages))
        }
    }

    private func resetIfExpired() {
        guard let lastMessage = messages.last else {
            return
        }

        let elapsed = Date().timeIntervalSince(lastMessage.date)

        if elapsed > conversationTimeout {
            messages.removeAll()
        }
    }
}
