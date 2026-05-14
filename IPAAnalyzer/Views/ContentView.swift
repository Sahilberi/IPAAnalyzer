//
//  ContentView.swift
//  IPA Bundle Analyzer
//
//  Main content view with tab navigation
//

import SwiftUI

struct ContentView: View {
    
    @EnvironmentObject var ipaViewModel: IPAViewModel
    @EnvironmentObject var comparisonViewModel: ComparisonViewModel
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Analyze", systemImage: "doc.text.magnifyingglass")
                }
                .tag(0)
            
            ComparisonView()
                .tabItem {
                    Label("Compare", systemImage: "arrow.left.arrow.right")
                }
                .tag(1)
        }
        .frame(minWidth: 1200, minHeight: 800)
    }
}

#Preview {
    ContentView()
        .environmentObject(IPAViewModel())
        .environmentObject(ComparisonViewModel())
}