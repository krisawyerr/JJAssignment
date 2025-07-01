//
//  ContentView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import CoreData
import Lottie

enum Tab {
    case home
    case create
    case library
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var animateHome = false
    @State private var animateCam = false
    @State private var animateGallery = false
    @State private var isProcessingVideo = false
    
    var body: some View {
        ZStack {
            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(Tab.home)
                    .background(Color("Background"))

                CreateView(cameraController: appState.cameraState.cameraController, selectedTab: $appState.selectedTab, isProcessingVideo: $isProcessingVideo)
                    .environmentObject(appState)
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                        Text("Create")
                    }
                    .tag(Tab.create)
                    .background(Color("Background"))
                
                LibraryView(selectedTab: $appState.selectedTab)
                    .tabItem {
                        Image(systemName: "photo.fill")
                        Text("Library")
                    }
                    .tag(Tab.library)
            }
            
            VStack {
                Spacer()
                HStack(alignment: .center) {
                    Spacer()

                    VStack {
                        Button(action: {
                            triggerHaptic(.soft)
                            appState.selectedTab = .home
                            animateHome = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                animateHome = false
                            }
                        }) {
                            TabbarLottieView(
                                animationName: "home",
                                play: animateHome,
                                strokeColor: (appState.selectedTab == .home ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!,
                                fillColor: (appState.selectedTab == .home ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!
                            )
                            .frame(width: 35, height: 35)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    VStack {
                        Button(action: {
                            triggerHaptic(.soft)
                            appState.selectedTab = .create
                            animateCam = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                animateCam = false
                            }
                        }) {
                            TabbarLottieView(
                                animationName: "cam",
                                play: animateCam,
                                strokeColor: (appState.selectedTab == .create ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!,
                                fillColor: (appState.selectedTab == .create ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!
                            )
                            .frame(width: 35, height: 35)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    VStack {
                        Button(action: {
                            triggerHaptic(.soft)
                            appState.selectedTab = .library
                            animateGallery = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                animateGallery = false
                            }
                        }) {
                            TabbarLottieView(
                                animationName: "gallery",
                                play: animateGallery,
                                strokeColor: (appState.selectedTab == .library ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!,
                                fillColor: (appState.selectedTab == .library ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!
                            )
                            .frame(width: 35, height: 35)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()
                }
                .padding(.top, 15)
                .background(Color("Background"))
            }
        }
        .onChange(of: appState.selectedTab) { _, newTab in
            handleTabChange(newTab)
        }
    }
    
    private func handleTabChange(_ newTab: Tab) {
        switch newTab {
        case .create:
            appState.cameraState.cameraController.resumeCamera()
        case .home, .library:
            appState.cameraState.cameraController.pauseCamera()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
