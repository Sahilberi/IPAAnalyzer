//
//  OverviewView.swift
//  IPA Bundle Analyzer
//
//  Overview of IPA metadata and size breakdown
//

import SwiftUI

struct OverviewView: View {
    
    let ipa: IPAInfo
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                header
                
                Divider()
                
                // Metadata
                metadataSection
                
                Divider()
                
                // Size Summary
                sizeSummarySection
                
                Divider()
                
                // Quick Stats
                quickStatsSection
            }
            .padding(24)
        }
        .navigationTitle("Overview")
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "app.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ipa.metadata.appName)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(ipa.fileName)
                    .foregroundStyle(.secondary)
                
                Text("Analyzed: \(ipa.analysisDate.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Metadata
    
    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Metadata")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                InfoCard(title: "Bundle ID", value: ipa.metadata.bundleIdentifier)
                InfoCard(title: "Version", value: ipa.metadata.version)
                InfoCard(title: "Build", value: ipa.metadata.buildNumber)
                InfoCard(title: "Min iOS", value: ipa.metadata.minimumOSVersion)
                InfoCard(title: "Devices", value: deviceFamiliesString)
                
                if let sdkName = ipa.metadata.sdkName {
                    InfoCard(title: "SDK", value: sdkName)
                }
            }
        }
    }
    
    private var deviceFamiliesString: String {
        ipa.metadata.supportedDeviceFamilies
            .map { $0.displayName }
            .joined(separator: ", ")
    }
    
    // MARK: - Size Summary
    
    private var sizeSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Size Summary")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                SizeRow(
                    label: "IPA Size (Compressed)",
                    size: ipa.fileSize,
                    color: .blue,
                    isTotal: true
                )
                
                SizeRow(
                    label: "Uncompressed Size",
                    size: ipa.uncompressedSize,
                    color: .purple,
                    isTotal: true
                )
                
                Divider()
                    .padding(.vertical, 4)
                
                SizeRow(label: "Binary", size: ipa.sizeBreakdown.binarySize, color: .orange)
                SizeRow(label: "Frameworks", size: ipa.sizeBreakdown.frameworksSize, color: .green)
                SizeRow(label: "Assets", size: ipa.sizeBreakdown.assetsSize, color: .pink)
                SizeRow(label: "Plugins", size: ipa.sizeBreakdown.pluginsSize, color: .cyan)
                SizeRow(label: "Others", size: ipa.sizeBreakdown.othersSize, color: .gray)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Stats")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Frameworks",
                    value: "\(ipa.frameworks.count)",
                    icon: "shippingbox.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Large Assets",
                    value: "\(ipa.assets.count)",
                    icon: "photo.stack.fill",
                    color: .pink
                )
                
                if let binary = ipa.binaryInfo {
                    StatCard(
                        title: "Architectures",
                        value: "\(binary.architectures.count)",
                        icon: "cpu",
                        color: .orange
                    )
                    
                    StatCard(
                        title: "Bitcode",
                        value: binary.hasBitcode ? "Yes" : "No",
                        icon: "bolt.fill",
                        color: binary.hasBitcode ? .blue : .gray
                    )
                    
                    if let symbolsCount = binary.symbolsCount {
                        StatCard(
                            title: "Symbols",
                            value: "\(symbolsCount)",
                            icon: "list.bullet",
                            color: .purple
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct SizeRow: View {
    let label: String
    let size: Int64
    let color: Color
    var isTotal: Bool = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(isTotal ? .headline : .body)
            
            Spacer()
            
            Text(size.formattedSize)
                .font(isTotal ? .headline : .body)
                .fontWeight(isTotal ? .semibold : .regular)
                .monospacedDigit()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    OverviewView(ipa: IPAInfo(
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
            supportedDeviceFamilies: [.iPhone, .iPad],
            platformBuild: nil,
            sdkName: "iphoneos17.0"
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
        fileTree: FileNode(name: "Test", path: "/", size: 0, isDirectory: true)
    ))
}