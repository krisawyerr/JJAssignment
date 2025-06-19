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
    @State private var selectedTab: Tab = .home
    @State private var animateHome = false
    @State private var animateCam = false
    @State private var animateGallery = false
    @State private var isProcessingVideo = false
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Home")
                    }
                    .tag(Tab.home)
                    .background(Color("Background"))

                CreateView(cameraController: appState.cameraController, selectedTab: $selectedTab, isProcessingVideo: $isProcessingVideo)
                    .environmentObject(appState)
                    .tabItem {
                        Image(systemName: "plus.circle.fill")
                        Text("Create")
                    }
                    .tag(Tab.create)
                    .background(Color("Background"))
                
                LibraryView(selectedTab: $selectedTab)
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
                            selectedTab = .home
                            animateHome = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                animateHome = false
                            }
                        }) {
                            TabbarLottieView(
                                animationName: "home",
                                play: animateHome,
                                strokeColor: (selectedTab == .home ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!,
                                fillColor: (selectedTab == .home ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!
                            )
                            .frame(width: 35, height: 35)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    VStack {
                        Button(action: {
                            triggerHaptic(.soft)
                            selectedTab = .create
                            animateCam = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                animateCam = false
                            }
                        }) {
                            TabbarLottieView(
                                animationName: "cam",
                                play: animateCam,
                                strokeColor: (selectedTab == .create ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!,
                                fillColor: (selectedTab == .create ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!
                            )
                            .frame(width: 35, height: 35)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    VStack {
                        Button(action: {
                            triggerHaptic(.soft)
                            selectedTab = .library
                            animateGallery = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                animateGallery = false
                            }
                        }) {
                            TabbarLottieView(
                                animationName: "gallery",
                                play: animateGallery,
                                strokeColor: (selectedTab == .library ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!,
                                fillColor: (selectedTab == .library ? UIColor(named: "JellyPrimary") : UIColor(named: "JellySecondary"))!
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
            
//            if isProcessingVideo {
//                Color.black.opacity(0.9)
//                    .ignoresSafeArea()
//                    .overlay(
//                        VStack(spacing: 20) {
//                            Text("Processing video...")
//                                .font(.custom("Ranchers-Regular", size: 25))
//                                .foregroundColor(.white)
//                                .kerning(1.5)
//                                .padding(.bottom, 10)
//                            ProgressView()
//                                .scaleEffect(2)
//                                .tint(.white)
//                        }
//                    )
//            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
