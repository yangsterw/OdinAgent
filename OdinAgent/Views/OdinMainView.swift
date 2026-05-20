//
//  OdinMainView.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
//


import SwiftUI

struct OdinMainView: View {

    @StateObject private var viewModel = OdinViewModel()

    var body: some View {
        VStack(spacing: 20) {

            Image(viewModel.dogImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)

            Text("Odin")
                .font(.largeTitle)
                .bold()

            Text(viewModel.statusText)
                .multilineTextAlignment(.center)
                .frame(width: 340)

            if !viewModel.latestTranscript.isEmpty {
                Text("Transcript: \(viewModel.latestTranscript)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 340)
            }

            HStack {
                Button("Start Listening") {
                    viewModel.startListening()
                }

                Button("Stop Listening") {
                    viewModel.stopListening()
                }
            }
        }
        .padding()
        .frame(width: 420, height: 520)
    }
}