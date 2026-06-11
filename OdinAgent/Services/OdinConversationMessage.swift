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

protocol OdinConversationManaging {
    func addUserMessage(_ text: String) async
    func addOdinMessage(_ text: String) async
    func contextText() async -> String
    func clear() async
}

actor OdinConversationService {

    private var messages: [OdinConversationMessage] = []

    private let maxMessages = 8
    private let conversationTimeout: TimeInterval = 10 * 60

    func addUserMessage(_ text: String) async {
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

    func addOdinMessage(_ text: String) async {
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

    func contextText() async -> String {
        resetIfExpired()

        guard !messages.isEmpty else {
            return ""
        }

        return messages
            .map { "\($0.role): \($0.text)" }
            .joined(separator: "\n")
    }

    func clear() async {
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

extension OdinConversationService: OdinConversationManaging {}
