//
//  BinaryView.swift
//  IPA Bundle Analyzer
//
//  Binary (Mach-O) information view
//

import SwiftUI

struct BinaryView: View {
    
    let ipa: IPAInfo
    
    var body: some View {
        ScrollView {
            if let binary = ipa.binaryInfo {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    header(binary: binary)
                    
                    Divider()
                    
                    // Architectures
                    architecturesSection(binary: binary)
                    
                    Divider()
                    
                    // Segments
                    segmentsSection(binary: binary)
                    
                    Divider()
                    
                    // Additional Info
                    additionalInfoSection(binary: binary)
                }
                .padding(24)
            } else {
                emptyState
            }
        }
        .navigationTitle("Binary")
    }
    
    // MARK: - Header
    
    private func header(binary: BinaryInfo) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(binary.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Binary Size: \(binary.size.formattedSize)")
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Architectures
    
    private func architecturesSection(binary: BinaryInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Architectures")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(binary.architectures) { arch in
                    ArchitectureCard(architecture: arch)
                }
            }
        }
    }
    
    // MARK: - Segments
    
    private func segmentsSection(binary: BinaryInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Segments")
                .font(.title2)
                .fontWeight(.semibold)
            
            if binary.segments.isEmpty {
                Text("No segment information available")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(binary.segments) { segment in
                        SegmentRow(segment: segment, totalSize: binary.size)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Additional Info
    
    private func additionalInfoSection(binary: BinaryInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    label: "Bitcode",
                    value: binary.hasBitcode ? "Present" : "Not Present",
                    icon: "bolt.fill",
                    color: binary.hasBitcode ? .blue : .gray
                )
                
                if let symbolsCount = binary.symbolsCount {
                    InfoRow(
                        label: "Symbols Count",
                        value: "\(symbolsCount)",
                        icon: "list.bullet",
                        color: .purple
                    )
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Binary Information Not Available")
                .font(.title2)
            
            Text("Could not parse the binary file")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Architecture Card

struct ArchitectureCard: View {
    let architecture: BinaryInfo.Architecture
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.orange)
                
                Text(architecture.name)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("CPU Type: \(architecture.cpuType)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Subtype: \(architecture.cpuSubtype)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Segment Row

struct SegmentRow: View {
    let segment: BinaryInfo.Segment
    let totalSize: Int64
    
    var percentage: Double {
        guard totalSize > 0 else { return 0 }
        return (Double(segment.size) / Double(totalSize)) * 100
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(segment.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(segment.size.formattedSize)
                    .font(.subheadline)
                    .monospacedDigit()
                
                Text("(\(String(format: "%.1f%%", percentage)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                    
                    Rectangle()
                        .fill(colorForSegment(segment.name))
                        .frame(width: geometry.size.width * (percentage / 100))
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
            
            HStack(spacing: 16) {
                Text("VM Size: \(segment.vmSize.formattedSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("Offset: \(segment.fileOffset)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private func colorForSegment(_ name: String) -> Color {
        switch name {
        case "__TEXT": return .blue
        case "__DATA": return .green
        case "__LINKEDIT": return .orange
        default: return .purple
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    BinaryView(ipa: IPAInfo(
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
        binaryInfo: BinaryInfo(
            name: "TestApp",
            size: 30_000_000,
            architectures: [
                BinaryInfo.Architecture(name: "arm64", cpuType: "16777228", cpuSubtype: "0")
            ],
            segments: [
                BinaryInfo.Segment(name: "__TEXT", size: 10_000_000, vmSize: 10_000_000, fileOffset: 0),
                BinaryInfo.Segment(name: "__DATA", size: 5_000_000, vmSize: 5_000_000, fileOffset: 10_000_000),
                BinaryInfo.Segment(name: "__LINKEDIT", size: 15_000_000, vmSize: 15_000_000, fileOffset: 15_000_000)
            ],
            hasBitcode: false,
            symbolsCount: 5000
        ),
        frameworks: [],
        assets: [],
        fileTree: FileNode(name: "TestApp.app", path: "/", size: 0, isDirectory: true)
    ))
}