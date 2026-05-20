//
//  SoundListeningService.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
//


import Foundation

protocol SoundListeningService {
    var onTranscript: ((String) -> Void)? { get set }

    func startListening()
    func stopListening()
}