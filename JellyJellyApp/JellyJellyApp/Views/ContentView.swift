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

                CreateView(selectedTab: $selectedTab, isProcessingVideo: $isProcessingVideo)
                    .tabItem {
                        Image(systemName: "camera.fill")
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
                            selectedTab = .home
                            animateHome = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                animateHome = false
                            }
                        }) {
                            TabbarLottieView(
                                animationName: "home",
                                play: animateHome,
                                strokeColor: (selectedTab == .home ? UIColor(named: "Primary") : UIColor(named: "Secondary"))!,
                                fillColor: (selectedTab == .home ? UIColor(named: "Primary") : UIColor(named: "Secondary"))!
                            )
                            .frame(width: 35, height: 35)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    VStack {
                        Button(action: {
                            selectedTab = .create
                            animateCam = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                animateCam = false
                            }
                        }) {
                            TabbarLottieView(
                                animationName: "cam",
                                play: animateCam,
                                strokeColor: (selectedTab == .create ? UIColor(named: "Primary") : UIColor(named: "Secondary"))!,
                                fillColor: (selectedTab == .create ? UIColor(named: "Primary") : UIColor(named: "Secondary"))!
                            )
                            .frame(width: 35, height: 35)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Spacer()

                    VStack {
                        Button(action: {
                            selectedTab = .library
                            animateGallery = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                animateGallery = false
                            }
                        }) {
                            TabbarLottieView(
                                animationName: "gallery",
                                play: animateGallery,
                                strokeColor: (selectedTab == .library ? UIColor(named: "Primary") : UIColor(named: "Secondary"))!,
                                fillColor: (selectedTab == .library ? UIColor(named: "Primary") : UIColor(named: "Secondary"))!
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
            
            if isProcessingVideo {
                Color.black.opacity(0.9)
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(2)
                                .tint(.white)
                            Text("Processing video...")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    )
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
