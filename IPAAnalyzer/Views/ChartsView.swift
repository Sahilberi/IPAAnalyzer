//
//  ChartsView.swift
//  IPA Bundle Analyzer
//
//  Size visualization with Swift Charts
//

import SwiftUI
import Charts

struct ChartsView: View {
    
    let ipa: IPAInfo
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Size distribution pie chart
                sizeDistributionChart
                
                // Top large files bar chart
                topFilesChart
                
                // Framework sizes bar chart
                frameworksChart
            }
            .padding(24)
        }
        .navigationTitle("Charts")
    }
    
    // MARK: - Size Distribution
    
    private var sizeDistributionChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Size Distribution")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: 40) {
                // Pie chart
                Chart(ipa.sizeBreakdown.items.filter { $0.size > 0 }) { item in
                    SectorMark(
                        angle: .value("Size", item.size),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(by: .value("Category", item.name))
                    .cornerRadius(4)
                }
                .frame(height: 300)
                .chartLegend(position: .trailing)
                
                // Legend with values
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(ipa.sizeBreakdown.items.filter { $0.size > 0 }) { item in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(colorForCategory(item.category))
                                .frame(width: 12, height: 12)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.subheadline)
                                
                                Text(item.size.formattedSize)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            
                            Spacer()
                            
                            Text(percentageString(for: item.size))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 200)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Top Files
    
    private var topFilesChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top 10 Largest Files")
                .font(.title2)
                .fontWeight(.semibold)
            
            let topFiles = topLargestFiles(limit: 10)
            
            Chart(topFiles, id: \.name) { file in
                BarMark(
                    x: .value("Size", file.size),
                    y: .value("File", file.name)
                )
                .foregroundStyle(.blue.gradient)
                .annotation(position: .trailing) {
                    Text(file.size.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: CGFloat(topFiles.count * 40 + 50))
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Frameworks
    
    private var frameworksChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top 10 Largest Frameworks")
                .font(.title2)
                .fontWeight(.semibold)
            
            let topFrameworks = Array(ipa.frameworks.prefix(10))
            
            if topFrameworks.isEmpty {
                Text("No frameworks found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Chart(topFrameworks) { framework in
                    BarMark(
                        x: .value("Size", framework.size),
                        y: .value("Framework", framework.name)
                    )
                    .foregroundStyle((framework.isDuplicate ? Color.red : Color.green).gradient)
                    .annotation(position: .trailing) {
                        HStack(spacing: 4) {
                            Text(framework.size.formattedSize)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            if framework.isDuplicate {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                .frame(height: CGFloat(topFrameworks.count * 40 + 50))
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func topLargestFiles(limit: Int) -> [(name: String, size: Int64)] {
        let allFiles = collectAllFiles(from: ipa.fileTree)
        return Array(allFiles
            .sorted { $0.size > $1.size }
            .prefix(limit)
            .map { (name: $0.name, size: $0.size) })
    }
    
    private func collectAllFiles(from node: FileNode) -> [FileNode] {
        var files: [FileNode] = []
        
        if !node.isDirectory {
            files.append(node)
        }
        
        for child in node.children {
            files.append(contentsOf: collectAllFiles(from: child))
        }
        
        return files
    }
    
    private func percentageString(for size: Int64) -> String {
        let total = ipa.sizeBreakdown.totalSize
        guard total > 0 else { return "0%" }
        let percentage = (Double(size) / Double(total)) * 100
        return String(format: "%.1f%%", percentage)
    }
    
    private func colorForCategory(_ category: SizeItem.Category) -> Color {
        switch category {
        case .binary: return .orange
        case .frameworks: return .green
        case .assets: return .pink
        case .plugins: return .cyan
        case .others: return .gray
        }
    }
}

#Preview {
    ChartsView(ipa: IPAInfo(
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
            FrameworkInfo(name: "Framework1", size: 5_000_000, version: "1.0", path: "/", isDuplicate: false),
            FrameworkInfo(name: "Framework2", size: 3_000_000, version: "1.0", path: "/", isDuplicate: false)
        ],
        assets: [],
        fileTree: FileNode(name: "TestApp.app", path: "/", size: 0, isDirectory: true, children: [
            FileNode(name: "TestApp", path: "/TestApp", size: 30_000_000, isDirectory: false),
            FileNode(name: "Assets.car", path: "/Assets.car", size: 10_000_000, isDirectory: false),
            FileNode(name: "Info.plist", path: "/Info.plist", size: 5_000, isDirectory: false)
        ])
    ))
}