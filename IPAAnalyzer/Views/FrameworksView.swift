//
//  FrameworksView.swift
//  IPA Bundle Analyzer
//
//  Frameworks listing and analysis
//

import SwiftUI

struct FrameworksView: View {
    
    let ipa: IPAInfo
    @State private var searchText = ""
    @State private var sortOption: FrameworkSortOption = .size
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
            
            Divider()
            
            // Content
            if ipa.frameworks.isEmpty {
                emptyState
            } else {
                frameworksList
            }
        }
        .navigationTitle("Frameworks")
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search frameworks...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
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
            Picker("Sort by", selection: $sortOption) {
                ForEach(FrameworkSortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Spacer()
            
            // Stats
            Text("\(filteredFrameworks.count) frameworks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Frameworks List
    
    private var frameworksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredFrameworks) { framework in
                    FrameworkCard(framework: framework)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Frameworks Found")
                .font(.title2)
            
            Text("This IPA doesn't contain embedded frameworks")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Filtering & Sorting
    
    private var filteredFrameworks: [FrameworkInfo] {
        var frameworks = ipa.frameworks
        
        // Apply search filter
        if !searchText.isEmpty {
            frameworks = frameworks.filter { framework in
                framework.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        switch sortOption {
        case .name:
            frameworks.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            frameworks.sort { $0.size > $1.size }
        }
        
        return frameworks
    }
}

// MARK: - Framework Card

struct FrameworkCard: View {
    let framework: FrameworkInfo
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(framework.isDuplicate ? .red : .green)
                .frame(width: 40)
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(framework.name)
                        .font(.headline)
                    
                    if framework.isDuplicate {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help("Duplicate framework detected")
                    }
                }
                
                HStack(spacing: 12) {
                    if let version = framework.version {
                        Label(version, systemImage: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Label(framework.size.formattedSize, systemImage: "archivebox")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            
            Spacer()
            
            // Size bar
            VStack(alignment: .trailing, spacing: 4) {
                Text(framework.size.formattedSize)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                
                Text("Framework")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Sort Option

enum FrameworkSortOption: String, CaseIterable {
    case name = "Name"
    case size = "Size"
}

#Preview {
    FrameworksView(ipa: IPAInfo(
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
        frameworks: [
            FrameworkInfo(name: "Alamofire", size: 5_000_000, version: "5.6.4", path: "/Frameworks/Alamofire.framework", isDuplicate: false),
            FrameworkInfo(name: "SwiftyJSON", size: 3_000_000, version: "5.0.1", path: "/Frameworks/SwiftyJSON.framework", isDuplicate: false),
            FrameworkInfo(name: "SDWebImage", size: 2_500_000, version: "5.12.0", path: "/Frameworks/SDWebImage.framework", isDuplicate: true)
        ],
        assets: [],
        fileTree: FileNode(name: "TestApp.app", path: "/", size: 0, isDirectory: true)
    ))
}