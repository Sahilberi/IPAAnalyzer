//
//  DashboardView.swift
//  IPA Bundle Analyzer
//
//  Main dashboard for single IPA analysis
//

import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    
    @EnvironmentObject var viewModel: IPAViewModel
    @State private var selectedSection: DashboardSection = .overview
    @State private var isDraggingOver = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            sidebar
        } detail: {
            // Main content
            if viewModel.isAnalyzing {
                analyzingView
            } else if let ipa = viewModel.currentIPA {
                detailView(for: ipa)
            } else {
                emptyStateView
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        List(selection: $selectedSection) {
            Section("Analysis") {
                ForEach(DashboardSection.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            
            Section("Actions") {
                Button(action: openIPA) {
                    Label("Open IPA", systemImage: "doc.badge.plus")
                }
                
                if viewModel.currentIPA != nil {
                    Button(action: exportJSON) {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: exportCSV) {
                        Label("Export CSV", systemImage: "tablecells")
                    }
                    
                    Button(action: viewModel.clearAnalysis) {
                        Label("Clear", systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("IPA Analyzer")
        .frame(minWidth: 200)
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private func detailView(for ipa: IPAInfo) -> some View {
        switch selectedSection {
        case .overview:
            OverviewView(ipa: ipa)
        case .files:
            FileTreeView(ipa: ipa)
        case .binary:
            BinaryView(ipa: ipa)
        case .frameworks:
            FrameworksView(ipa: ipa)
        case .assets:
            AssetsView(ipa: ipa)
        case .charts:
            ChartsView(ipa: ipa)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            
            Text("No IPA Loaded")
                .font(.title)
            
            Text("Drag and drop an IPA(.app)file, or click Open to analyze")
                .foregroundStyle(.secondary)
            
            Button(action: openIPA) {
                Text("Open IPA")
                    .frame(width: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isDraggingOver ? Color.accentColor.opacity(0.1) : Color.clear)
        .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
    }
    
    // MARK: - Analyzing View
    
    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView(value: viewModel.progress) {
                Text("Analyzing IPA...")
            }
            .frame(width: 300)
            
            Text("Please wait while we extract and analyze the IPA file")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func openIPA() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        // Some iOS .app bundles are not recognized as file-packages by Launch Services and show up as directories.
        // Allow directory selection so those bundles can be picked.
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        
        // Prefer extension-based filtering over UTType-based filtering here.
        // It works even when a bundle is treated as a directory.
        panel.allowedFileTypes = ["ipa", "app", "appex"]
        panel.title = "Select IPA, .app Bundle, or .appex"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await viewModel.analyzeIPA(url: url)
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, error == nil else { return }
            
            let ext = url.pathExtension.lowercased()
            if ext == "ipa" || ext == "app" || ext == "appex" {
                Task { @MainActor in
                    await viewModel.analyzeIPA(url: url)
                }
            }
        }
        
        return true
    }
    
    private func exportJSON() {
        guard let content = viewModel.exportJSON() else { return }
        let fileName = "\(viewModel.currentIPA?.fileName ?? "ipa-analysis").json"
      
      Task { @MainActor in
        viewModel.saveReport(content: content, fileName: fileName)
      }
    }
    
  private func exportCSV() {
    guard let content = viewModel.exportCSV() else { return }
    let fileName = "\(viewModel.currentIPA?.fileName ?? "ipa-analysis").csv"
    Task { @MainActor in
      viewModel.saveReport(content: content, fileName: fileName)
    }
  }
}

// MARK: - Dashboard Section

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case files
    case binary
    case frameworks
    case assets
    case charts
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .files: return "Files"
        case .binary: return "Binary"
        case .frameworks: return "Frameworks"
        case .assets: return "Assets"
        case .charts: return "Charts"
        }
    }
    
    var icon: String {
        switch self {
        case .overview: return "list.bullet.rectangle"
        case .files: return "folder"
        case .binary: return "cpu"
        case .frameworks: return "shippingbox"
        case .assets: return "photo.stack"
        case .charts: return "chart.pie"
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(IPAViewModel())
}
