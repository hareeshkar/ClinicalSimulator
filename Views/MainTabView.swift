//
//  MainTabView.swift
//  ClinicalSimulator
//
//  Created by Hareeshkar Ravi on 9/5/25.
//

import SwiftUI

struct MainTabView: View {
    // We create one instance of our navigation manager here.
    // @StateObject ensures it stays alive for the life of the app.
    @StateObject private var navigationManager = NavigationManager()
    
    // Theme preference
    @AppStorage("preferredColorScheme") private var preferredColorScheme: String = "system"

    var body: some View {
        // We bind the TabView's selection to our manager's 'selectedTab' property.
        TabView(selection: $navigationManager.selectedTab) {
            
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }
                .tag(NavigationManager.Tab.dashboard)
            
            CaseLibraryView()
                .tabItem { Label("Cases", systemImage: "list.bullet.clipboard.fill") }
                .tag(NavigationManager.Tab.cases)
            
            ReportsView()
                .tabItem { Label("Reports", systemImage: "chart.bar.doc.horizontal.fill") }
                .tag(NavigationManager.Tab.reports)
            
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
                .tag(NavigationManager.Tab.profile)
        }
        // We make the navigation manager available to all child views.
        .environmentObject(navigationManager)
        // Apply the preferred color scheme
        .preferredColorScheme(colorScheme)
    }
    
    private var colorScheme: ColorScheme? {
        switch preferredColorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil // system
        }
    }
}

