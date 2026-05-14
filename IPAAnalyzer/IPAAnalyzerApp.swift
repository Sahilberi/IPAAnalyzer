//
//  IPAAnalyzerApp.swift
//  IPA Bundle Analyzer
//
//  Main app entry point
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct IPAAnalyzerApp: App {
    
    @StateObject private var ipaViewModel = IPAViewModel()
    @StateObject private var comparisonViewModel = ComparisonViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ipaViewModel)
                .environmentObject(comparisonViewModel)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open IPA...") {
                    openIPAFile()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Button("Compare IPAs...") {
                    // Switch to comparison view
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
    }
    
    private func openIPAFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["ipa", "app", "appex"]
        panel.title = "Select IPA, .app Bundle, or .appex"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await ipaViewModel.analyzeIPA(url: url)
                }
            }
        }
    }
}