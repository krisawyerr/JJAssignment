//
//  CreateView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import AVFoundation
import CoreData

struct CreateView: View {
    @StateObject private var cameraController = CameraController()
    @Environment(\.managedObjectContext) private var context
    @Binding var selectedTab: Tab

    var body: some View {
        VStack {
            ZStack {
                CameraPreviewView(controller: cameraController)

                if cameraController.isRecording {
                    Text("\(cameraController.secondsRemaining)")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(cameraController.secondsRemaining <= 3 ? .red : .white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .scaleEffect(cameraController.secondsRemaining <= 3 ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.5), value: cameraController.secondsRemaining)
                }

                HStack {
                    Button("Start") {
                        cameraController.startRecording(context: context)
                    }
                    .padding()
                    .background(cameraController.isRecording ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(cameraController.isRecording)

                    Button("Stop") {
                        cameraController.stopRecording()
                    }
                    .padding()
                    .background(cameraController.isRecording ? Color.red : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!cameraController.isRecording)
                }
            }
            .onAppear {
                print("CreateView appeared - setting up camera")
                cameraController.setupCamera()

                cameraController.onVideoProcessed = {
                    selectedTab = .library
                }
            }
            .onDisappear {
                print("CreateView disappeared - stopping camera")
                cameraController.stopCamera()
            }
            .cornerRadius(16)
        }
        .safeAreaInset(edge: .top) { Spacer().frame(height: 0) }
        .safeAreaInset(edge: .leading) { Spacer().frame(height: 5) }
        .safeAreaInset(edge: .trailing) { Spacer().frame(height: 5) }
        }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
