//
//  FileTreeView.swift
//  IPA Bundle Analyzer
//
//  File tree explorer with search and sort
//

import SwiftUI

struct FileTreeView: View {
    
    let ipa: IPAInfo
    @EnvironmentObject var viewModel: IPAViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
            
            Divider()
            
            // File tree
            if viewModel.searchText.isEmpty {
                treeView
            } else {
                searchResultsView
            }
        }
        .navigationTitle("Files")
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search files...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            
            // Sort picker
            Picker("Sort by", selection: $viewModel.sortOption) {
                ForEach(FileSortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding()
    }
    
    // MARK: - Tree View
    
    private var treeView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                FileNodeRow(node: ipa.fileTree, level: 0)
            }
            .padding()
        }
    }
    
    // MARK: - Search Results
    
    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.filteredFiles, id: \.id) { node in
                    SearchResultRow(node: node)
                }
            }
            .padding()
        }
    }
}

// MARK: - File Node Row

struct FileNodeRow: View {
    
    @EnvironmentObject var viewModel: IPAViewModel
    @ObservedObject var node: FileNode
    let level: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Current node
            Button(action: { if node.isDirectory { node.isExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    // Indentation
                    Color.clear
                        .frame(width: CGFloat(level * 20))
                    
                    // Expand icon
                    if node.isDirectory {
                        Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    } else {
                        Color.clear.frame(width: 12)
                    }
                    
                    // File icon
                    Image(systemName: node.iconName)
                        .foregroundStyle(node.isDirectory ? .blue : .secondary)
                    
                    // File name
                    Text(node.name)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Size
                    Text(node.totalSize.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Children
            if node.isDirectory && node.isExpanded {
                ForEach(viewModel.sortedChildren(of: node), id: \.id) { child in
                    FileNodeRow(node: child, level: level + 1)
                }
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    
    let node: FileNode
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: node.iconName)
                .foregroundStyle(node.isDirectory ? .blue : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .lineLimit(1)
                
                Text(node.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(node.totalSize.formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
    }
}

#Preview {
    FileTreeView(ipa: IPAInfo(
        fileName: "TestApp.ipa",
        filePath: URL(fileURLWithPath: "/test.ipa"),
        fileSize: 50_000_000,
        uncompressedSize: 75_000_000,
        metadata: AppMetadata(
            appName: "Test App",
            bundleIdentifier: "com.test.app",
            version: "1.0.0",
            buildNumber: "100",
            minimumOSVersion: "15.0",
            supportedDeviceFamilies: [.iPhone],
            platformBuild: nil,
            sdkName: nil
        ),
        sizeBreakdown: SizeBreakdown(
            totalSize: 75_000_000,
            binarySize: 30_000_000,
            frameworksSize: 20_000_000,
            assetsSize: 15_000_000,
            pluginsSize: 5_000_000,
            othersSize: 5_000_000
        ),
        binaryInfo: nil,
        frameworks: [],
        assets: [],
        fileTree: FileNode(name: "TestApp.app", path: "/", size: 0, isDirectory: true, children: [
            FileNode(name: "TestApp", path: "/TestApp", size: 30_000_000, isDirectory: false),
            FileNode(name: "Info.plist", path: "/Info.plist", size: 5_000, isDirectory: false)
        ])
    ))
    .environmentObject(IPAViewModel())
}