//
//  Park_RideApp.swift
//  Park&Ride
//
//  Created by Jeannie Huang on 21/5/2026.
//

import SwiftUI

@main
struct Park_RideApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = ParkingViewModel()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(viewModel: viewModel)
                if showSplash {
                    SplashView(
                        canDismiss: !viewModel.carParks.isEmpty || viewModel.errorMessage != nil
                    ) {
                        showSplash = false
                    }
                }
            }
            .task {
                applyColorScheme(UserDefaults.standard.string(forKey: "app_color_scheme") ?? "system")
                viewModel.startAutoRefresh()
                await NotificationService.registerForPushNotifications()
            }
        }
    }
}
