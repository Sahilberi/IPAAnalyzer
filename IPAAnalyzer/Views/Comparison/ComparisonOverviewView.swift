//
//  ComparisonOverviewView.swift
//  IPA Bundle Analyzer
//
//  Overview of comparison results
//

import SwiftUI
import Charts

struct ComparisonOverviewView: View {
    
    let result: ComparisonResult
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                header
                
                Divider()
                
                // Size comparison summary
                sizeSummary
                
                Divider()
                
                // Changes summary
                changesSummary
                
                Divider()
                
                // Visual comparison chart
                visualComparison
            }
            .padding(24)
        }
        .navigationTitle("Comparison Overview")
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 32) {
            IPAComparisonCard(title: "First IPA", ipa: result.firstIPA, color: .blue)
            
            Image(systemName: "arrow.right")
                .font(.title)
                .foregroundStyle(.secondary)
            
            IPAComparisonCard(title: "Second IPA", ipa: result.secondIPA, color: .purple)
        }
    }
    
    // MARK: - Size Summary
    
    private var sizeSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Size Changes")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                SizeComparisonRow(
                    label: "Total Size",
                    oldSize: result.secondIPA.fileSize,
                    newSize: result.firstIPA.fileSize,
                    diff: result.sizeComparison.totalSizeDiff
                )
                
                SizeComparisonRow(
                    label: "Binary",
                    oldSize: result.secondIPA.sizeBreakdown.binarySize,
                    newSize: result.firstIPA.sizeBreakdown.binarySize,
                    diff: result.sizeComparison.binarySizeDiff
                )
                
                SizeComparisonRow(
                    label: "Frameworks",
                    oldSize: result.secondIPA.sizeBreakdown.frameworksSize,
                    newSize: result.firstIPA.sizeBreakdown.frameworksSize,
                    diff: result.sizeComparison.frameworksSizeDiff
                )
                
                SizeComparisonRow(
                    label: "Assets",
                    oldSize: result.secondIPA.sizeBreakdown.assetsSize,
                    newSize: result.firstIPA.sizeBreakdown.assetsSize,
                    diff: result.sizeComparison.assetsSizeDiff
                )
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Changes Summary
    
    private var changesSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Changes Summary")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ChangeSummaryCard(
                    title: "Files",
                    added: result.fileChanges.added.count,
                    removed: result.fileChanges.removed.count,
                    modified: result.fileChanges.modified.count,
                    icon: "doc.text",
                    color: .blue
                )
                
                ChangeSummaryCard(
                    title: "Frameworks",
                    added: result.frameworkChanges.added.count,
                    removed: result.frameworkChanges.removed.count,
                    modified: result.frameworkChanges.modified.count,
                    icon: "shippingbox",
                    color: .green
                )
                
                if let binaryChanges = result.binaryChanges {
                    BinaryChangeSummaryCard(changes: binaryChanges)
                }
            }
        }
    }
    
    // MARK: - Visual Comparison
    
    private var visualComparison: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Size Distribution Comparison")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: 40) {
                // First IPA chart
                VStack(spacing: 12) {
                    Text("First IPA")
                        .font(.headline)
                    
                    Chart(result.firstIPA.sizeBreakdown.items.filter { $0.size > 0 }) { item in
                        SectorMark(
                            angle: .value("Size", item.size),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Category", item.name))
                        .cornerRadius(4)
                    }
                    .frame(height: 250)
                    
                    Text(result.firstIPA.fileSize.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Second IPA chart
                VStack(spacing: 12) {
                    Text("Second IPA")
                        .font(.headline)
                    
                    Chart(result.secondIPA.sizeBreakdown.items.filter { $0.size > 0 }) { item in
                        SectorMark(
                            angle: .value("Size", item.size),
                            innerRadius: .ratio(0.5),
                            angularInset: 2
                        )
                        .foregroundStyle(by: .value("Category", item.name))
                        .cornerRadius(4)
                    }
                    .frame(height: 250)
                    
                    Text(result.secondIPA.fileSize.formattedSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
}

// MARK: - Supporting Views

struct IPAComparisonCard: View {
    let title: String
    let ipa: IPAInfo
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "app.fill")
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(ipa.metadata.appName)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("v\(ipa.metadata.version) (\(ipa.metadata.buildNumber))")
                    .foregroundStyle(.secondary)
                
                Text(ipa.fileSize.formattedSize)
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SizeComparisonRow: View {
    let label: String
    let oldSize: Int64
    let newSize: Int64
    let diff: Int64
    
    var percentage: Double {
        guard oldSize > 0 else { return 0 }
        return (Double(diff) / Double(oldSize)) * 100
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 100, alignment: .leading)
            
            Spacer()
            
            // Old size
            Text(oldSize.formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
            
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // New size
            Text(newSize.formattedSize)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
            
            // Diff
            HStack(spacing: 4) {
                Image(systemName: diff > 0 ? "arrow.up" : diff < 0 ? "arrow.down" : "minus")
                    .font(.caption2)
                
                Text(abs(diff).formattedSize)
                    .font(.caption)
                    .monospacedDigit()
                
                Text("(\(String(format: "%+.1f%%", percentage)))")
                    .font(.caption2)
            }
            .foregroundStyle(diff > 0 ? .red : diff < 0 ? .green : .secondary)
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}

struct ChangeSummaryCard: View {
    let title: String
    let added: Int
    let removed: Int
    let modified: Int
    let icon: String
    let color: Color
    
    var totalChanges: Int {
        added + removed + modified
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(title)
                .font(.headline)
            
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                    Text("\(added) added")
                }
                .font(.caption)
                
                HStack {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                    Text("\(removed) removed")
                }
                .font(.caption)
                
                HStack {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.orange)
                    Text("\(modified) modified")
                }
                .font(.caption)
            }
            
            Text("Total: \(totalChanges)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct BinaryChangeSummaryCard: View {
    let changes: BinaryChanges
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(.orange)
            
            Text("Binary")
                .font(.headline)
            
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: changes.sizeDiff > 0 ? "arrow.up" : "arrow.down")
                    Text(abs(changes.sizeDiff).formattedSize)
                }
                .font(.caption)
                .foregroundStyle(changes.sizeDiff > 0 ? .red : .green)
                
                if !changes.architectureChanges.isEmpty {
                    Text("\(changes.architectureChanges.count) arch changes")
                        .font(.caption)
                }
                
                if changes.bitcodeChanged {
                    Text("Bitcode changed")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    ComparisonOverviewView(result: ComparisonResult(
        firstIPA: IPAInfo(
            fileName: "TestApp_v2.ipa",
            filePath: URL(fileURLWithPath: "/test2.ipa"),
            fileSize: 55_000_000,
            uncompressedSize: 80_000_000,
            metadata: AppMetadata(
                appName: "Test App",
                bundleIdentifier: "com.test.app",
                version: "2.0.0",
                buildNumber: "200",
                minimumOSVersion: "15.0",
                supportedDeviceFamilies: [.iPhone],
                platformBuild: nil,
                sdkName: nil
            ),
            sizeBreakdown: SizeBreakdown(
                totalSize: 80_000_000,
                binarySize: 35_000_000,
                frameworksSize: 22_000_000,
                assetsSize: 16_000_000,
                pluginsSize: 4_000_000,
                othersSize: 3_000_000
            ),
            binaryInfo: nil,
            frameworks: [],
            assets: [],
            fileTree: FileNode(name: "Test", path: "/", size: 0, isDirectory: true)
        ),
        secondIPA: IPAInfo(
            fileName: "TestApp_v1.ipa",
            filePath: URL(fileURLWithPath: "/test1.ipa"),
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
            fileTree: FileNode(name: "Test", path: "/", size: 0, isDirectory: true)
        ),
        sizeComparison: SizeComparison(
            firstIPA: IPAInfo(
                fileName: "TestApp_v2.ipa",
                filePath: URL(fileURLWithPath: "/test2.ipa"),
                fileSize: 55_000_000,
                uncompressedSize: 80_000_000,
                metadata: AppMetadata(
                    appName: "Test App",
                    bundleIdentifier: "com.test.app",
                    version: "2.0.0",
                    buildNumber: "200",
                    minimumOSVersion: "15.0",
                    supportedDeviceFamilies: [.iPhone],
                    platformBuild: nil,
                    sdkName: nil
                ),
                sizeBreakdown: SizeBreakdown(
                    totalSize: 80_000_000,
                    binarySize: 35_000_000,
                    frameworksSize: 22_000_000,
                    assetsSize: 16_000_000,
                    pluginsSize: 4_000_000,
                    othersSize: 3_000_000
                ),
                binaryInfo: nil,
                frameworks: [],
                assets: [],
                fileTree: FileNode(name: "Test", path: "/", size: 0, isDirectory: true)
            ),
            secondIPA: IPAInfo(
                fileName: "TestApp_v1.ipa",
                filePath: URL(fileURLWithPath: "/test1.ipa"),
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
                fileTree: FileNode(name: "Test", path: "/", size: 0, isDirectory: true)
            )
        ),
        fileChanges: FileChanges(added: [], removed: [], modified: []),
        frameworkChanges: FrameworkChanges(added: [], removed: [], modified: []),
        binaryChanges: nil
    ))
}