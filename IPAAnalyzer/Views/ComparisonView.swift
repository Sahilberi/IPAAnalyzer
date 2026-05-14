//
//  ComparisonView.swift
//  IPA Bundle Analyzer
//
//  Main view for comparing two IPA files
//

import SwiftUI
import UniformTypeIdentifiers

struct ComparisonView: View {
    
    @EnvironmentObject var viewModel: ComparisonViewModel
    @State private var selectedSection: ComparisonSection = .overview
    @State private var isDraggingFirst = false
    @State private var isDraggingSecond = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            sidebar
        } detail: {
            // Main content
            if viewModel.isAnalyzingFirst || viewModel.isAnalyzingSecond {
                analyzingView
            } else if let result = viewModel.comparisonResult {
                detailView(for: result)
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
            Section("Comparison") {
                ForEach(ComparisonSection.allCases) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
            }
            
            Section("Actions") {
                Button(action: viewModel.clearAll) {
                    Label("Clear All", systemImage: "trash")
                }
                .foregroundStyle(.red)
                .disabled(viewModel.firstIPA == nil && viewModel.secondIPA == nil)
                
                if viewModel.comparisonResult != nil {
                    Button(action: exportJSON) {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: exportCSV) {
                        Label("Export CSV", systemImage: "tablecells")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Compare IPAs")
        .frame(minWidth: 200)
    }
    
    // MARK: - Detail View
    
    @ViewBuilder
    private func detailView(for result: ComparisonResult) -> some View {
        switch selectedSection {
        case .overview:
            ComparisonOverviewView(result: result)
        case .sizeChanges:
            SizeChangesView(result: result)
        case .fileChanges:
            FileChangesView(result: result)
        case .frameworkChanges:
            FrameworkChangesView(result: result)
        case .binaryChanges:
            BinaryChangesView(result: result)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            Text("Compare Two IPA Files")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack(spacing: 32) {
                // First IPA dropzone
                IPADropZone(
                    title: "First IPA",
                    subtitle: "Newer Version",
                    ipa: viewModel.firstIPA,
                    isDragging: isDraggingFirst,
                    onSelect: selectFirstIPA,
                    onClear: viewModel.clearFirstIPA
                )
                .onDrop(of: [.fileURL], isTargeted: $isDraggingFirst) { providers in
                    handleFirstDrop(providers: providers)
                }
                
                Image(systemName: "arrow.right")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                // Second IPA dropzone
                IPADropZone(
                    title: "Second IPA",
                    subtitle: "Older Version",
                    ipa: viewModel.secondIPA,
                    isDragging: isDraggingSecond,
                    onSelect: selectSecondIPA,
                    onClear: viewModel.clearSecondIPA
                )
                .onDrop(of: [.fileURL], isTargeted: $isDraggingSecond) { providers in
                    handleSecondDrop(providers: providers)
                }
            }
            .frame(maxWidth: 900)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Analyzing View
    
    private var analyzingView: some View {
        VStack(spacing: 20) {
            if viewModel.isAnalyzingFirst {
                ProgressView {
                    Text("Analyzing first IPA...")
                }
            }
            
            if viewModel.isAnalyzingSecond {
                ProgressView {
                    Text("Analyzing second IPA...")
                }
            }
            
            if viewModel.isComparing {
                ProgressView {
                    Text("Comparing IPAs...")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func selectFirstIPA() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["ipa", "app", "appex"]
        panel.title = "Select First IPA / .app / .appex (Newer Version)"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await viewModel.loadFirstIPA(url: url)
                }
            }
        }
    }
    
    private func selectSecondIPA() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["ipa", "app", "appex"]
        panel.title = "Select Second IPA / .app / .appex (Older Version)"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await viewModel.loadSecondIPA(url: url)
                }
            }
        }
    }
    
    private func handleFirstDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, error == nil else { return }
            
            let ext = url.pathExtension.lowercased()
            if ext == "ipa" || ext == "app" || ext == "appex" {
                Task { @MainActor in
                    await viewModel.loadFirstIPA(url: url)
                }
            }
        }
        
        return true
    }
    
    private func handleSecondDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, error == nil else { return }
            
            let ext = url.pathExtension.lowercased()
            if ext == "ipa" || ext == "app" || ext == "appex" {
                Task { @MainActor in
                    await viewModel.loadSecondIPA(url: url)
                }
            }
        }
        
        return true
    }
    
    private func exportJSON() {
        guard let content = viewModel.exportComparisonJSON() else { return }
        let fileName = "comparison-\(Date().formatted(date: .numeric, time: .omitted)).json"
      Task { @MainActor in
        viewModel.saveReport(content: content, fileName: fileName)
      }
    }
    
    private func exportCSV() {
        guard let content = viewModel.exportComparisonCSV() else { return }
        let fileName = "comparison-\(Date().formatted(date: .numeric, time: .omitted)).csv"
      Task { @MainActor in
        viewModel.saveReport(content: content, fileName: fileName)
      }
    }
}

// MARK: - IPA Drop Zone

struct IPADropZone: View {
    let title: String
    let subtitle: String
    let ipa: IPAInfo?
    let isDragging: Bool
    let onSelect: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if let ipa = ipa {
                // Loaded state
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.green)
                    
                    Text(ipa.metadata.appName)
                        .font(.headline)
                    
                    Text("v\(ipa.metadata.version) (\(ipa.metadata.buildNumber))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(ipa.fileSize.formattedSize)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    
                    Button("Change", action: onSelect)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    
                    Button("Clear", action: onClear)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundStyle(.red)
                }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    
                    Text(title)
                        .font(.headline)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("Select IPA", action: onSelect)
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 300, height: 300)
        .background(isDragging ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundStyle(isDragging ? Color.accentColor : Color.secondary.opacity(0.3))
        )
    }
}

// MARK: - Comparison Section

enum ComparisonSection: String, CaseIterable, Identifiable {
    case overview
    case sizeChanges
    case fileChanges
    case frameworkChanges
    case binaryChanges
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .sizeChanges: return "Size Changes"
        case .fileChanges: return "File Changes"
        case .frameworkChanges: return "Framework Changes"
        case .binaryChanges: return "Binary Changes"
        }
    }
    
    var icon: String {
        switch self {
        case .overview: return "list.bullet.rectangle"
        case .sizeChanges: return "chart.bar"
        case .fileChanges: return "doc.text"
        case .frameworkChanges: return "shippingbox"
        case .binaryChanges: return "cpu"
        }
    }
}

