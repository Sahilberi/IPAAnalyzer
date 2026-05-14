//
//  AssetsView.swift
//  IPA Bundle Analyzer
//
//  Assets listing and analysis
//

import SwiftUI

struct AssetsView: View {
    
    let ipa: IPAInfo
    @State private var searchText = ""
    @State private var selectedType: AssetInfo.AssetType?
    @State private var selectedAsset: AssetInfo?
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar
            
            Divider()
            
            // Content
            if ipa.assets.isEmpty {
                emptyState
            } else {
                assetsList
            }
        }
        .navigationTitle("Assets")
        .sheet(item: $selectedAsset) { asset in
            AssetDetailView(asset: asset, ipa: ipa)
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search assets...", text: $searchText)
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
            
            // Type filter
            Menu {
                Button("All Types") {
                    selectedType = nil
                }
                
                Divider()
                
                ForEach([AssetInfo.AssetType.image, .assetsCatalog, .video, .audio, .font, .other], id: \.self) { type in
                    Button(type.displayName) {
                        selectedType = type
                    }
                }
            } label: {
                Label(selectedType?.displayName ?? "All Types", systemImage: "line.3.horizontal.decrease.circle")
            }
            
            Spacer()
            
            // Stats
            Text("\(filteredAssets.count) assets • \(totalSize.formattedSize)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Assets List
    
    private var assetsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredAssets) { asset in
                    Button {
                        selectedAsset = asset
                    } label: {
                        AssetCard(asset: asset)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Large Assets Found")
                .font(.title2)
            
            Text("This IPA doesn't contain significant asset files")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Filtering
    
    private var filteredAssets: [AssetInfo] {
        var assets = ipa.assets
        
        // Apply search filter
        if !searchText.isEmpty {
            assets = assets.filter { asset in
                asset.name.localizedCaseInsensitiveContains(searchText) ||
                asset.path.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply type filter
        if let selectedType = selectedType {
            assets = assets.filter { $0.type == selectedType }
        }
        
        return assets
    }
    
    private var totalSize: Int64 {
        filteredAssets.reduce(0) { $0 + $1.size }
    }
}

// MARK: - Asset Card

struct AssetCard: View {
    let asset: AssetInfo
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: asset.type.icon)
                .font(.title2)
                .foregroundStyle(asset.type.color)
                .frame(width: 40)
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(asset.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label(asset.type.displayName, systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Label(asset.size.formattedSize, systemImage: "archivebox")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                
                Text(asset.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Size + disclosure chevron
            HStack(spacing: 12) {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(asset.size.formattedSize)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                    
                    if asset.size > 1_000_000 {
                        Text("Large")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isHovered ? 1.003 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

// MARK: - Asset Detail View

struct AssetDetailView: View {
    let asset: AssetInfo
    let ipa: IPAInfo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            detailHeader
            
            Divider()
            
            // Scrollable content
            ScrollView {
                VStack(spacing: 16) {
                    fileInfoSection
                    sizeAnalysisSection
                    optimizationSection
                }
                .padding(24)
            }
        }
        .frame(width: 520, height: 570)
    }
    
    // MARK: - Header
    
    private var detailHeader: some View {
        HStack(spacing: 16) {
            // Circular icon
            ZStack {
                Circle()
                    .fill(asset.type.color.opacity(0.15))
                    .frame(width: 52, height: 52)
                
                Image(systemName: asset.type.icon)
                    .font(.title2)
                    .foregroundStyle(asset.type.color)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(asset.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    // Type badge
                    Text(asset.type.displayName)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(asset.type.color)
                        .cornerRadius(4)
                    
                    // Large file warning badge
                    if asset.size > 1_000_000 {
                        Text("Large File")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
    }
    
    // MARK: - File Information Section
    
    private var fileInfoSection: some View {
        AssetSectionCard(title: "File Information", icon: "doc.fill") {
            VStack(spacing: 10) {
                AssetDetailRow(label: "File Name", value: asset.name)
                AssetDetailRow(label: "Type", value: asset.type.displayName)
                AssetDetailRow(label: "Extension", value: fileExtension.isEmpty ? "—" : fileExtension)
                AssetPathRow(label: "Path", path: asset.path)
            }
        }
    }
    
    // MARK: - Size Analysis Section
    
    private var sizeAnalysisSection: some View {
        AssetSectionCard(title: "Size Analysis", icon: "chart.bar.fill") {
            VStack(spacing: 10) {
                AssetDetailRow(label: "File Size", value: asset.size.formattedSize)
                AssetDetailRow(label: "Raw Bytes", value: "\(formattedRawBytes) bytes")
                AssetDetailRow(label: "% of Assets", value: String(format: "%.1f%%", assetPercentage))
                AssetDetailRow(label: "% of Total IPA", value: String(format: "%.1f%%", ipaPercentage))
                
                Divider()
                    .padding(.vertical, 2)
                
                AssetSizeBar(percentage: assetPercentage / 100, color: asset.type.color)
            }
        }
    }
    
    // MARK: - Optimization Tips Section
    
    private var optimizationSection: some View {
        AssetSectionCard(title: "Optimization Tips", icon: "lightbulb.fill") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(optimizationTips.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout)
                            .padding(.top, 1)
                        
                        Text(tip)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Computed Properties
    
    private var fileExtension: String {
        URL(fileURLWithPath: asset.path).pathExtension.uppercased()
    }
    
    private var formattedRawBytes: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: asset.size)) ?? "\(asset.size)"
    }
    
    private var totalAssetsSize: Int64 {
        ipa.assets.reduce(0) { $0 + $1.size }
    }
    
    private var assetPercentage: Double {
        guard totalAssetsSize > 0 else { return 0 }
        return Double(asset.size) / Double(totalAssetsSize) * 100
    }
    
    private var ipaPercentage: Double {
        guard ipa.uncompressedSize > 0 else { return 0 }
        return Double(asset.size) / Double(ipa.uncompressedSize) * 100
    }
    
    private var optimizationTips: [String] {
        var tips: [String] = []
        switch asset.type {
        case .image:
            tips.append("Use Asset Catalogs (.xcassets) to leverage on-demand slicing and Xcode compression.")
            tips.append("Convert PNG or JPG to HEIC or WebP for significant size savings (30–70%).")
            if asset.size > 500_000 {
                tips.append("This image is large — consider resizing or compressing before bundling.")
            }
        case .assetsCatalog:
            tips.append("Asset catalogs are already optimized — Xcode applies compression at build time.")
            tips.append("Include only the scale variants (1x, 2x, 3x) your supported devices need.")
            tips.append("Remove unused image sets to reduce the catalog footprint.")
        case .video:
            tips.append("Use H.265 (HEVC) encoding to reduce file size by up to 40% compared to H.264.")
            tips.append("Consider streaming video from a CDN to eliminate it from the IPA entirely.")
            if asset.size > 5_000_000 {
                tips.append("This video is very large — bundling it significantly increases download size.")
            }
        case .audio:
            tips.append("Use AAC or Opus codec for a good balance of audio quality and file size.")
            tips.append("Reduce sample rate (44.1 kHz or 22 kHz) if high fidelity is not required.")
            tips.append("Trim silence and unused segments to reduce overall audio duration.")
        case .font:
            tips.append("Subset fonts to include only the Unicode ranges your app actually renders.")
            tips.append("Use system fonts (SF Pro, SF Mono, NY) wherever possible to avoid bundling.")
            tips.append("Variable fonts replace multiple weight/style files with a single compact file.")
        case .other:
            tips.append("Verify this file is intentional and not a leftover build artifact.")
            tips.append("Check if this resource can be fetched on demand to avoid inflating the IPA.")
        }
        return tips
    }
}

// MARK: - Helper Views

/// A titled card container used in AssetDetailView sections
struct AssetSectionCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(.headline)
            
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
    }
}

/// A two-column label/value row for the detail sheet
struct AssetDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A path row with an inline "Copy" button
struct AssetPathRow: View {
    let label: String
    let path: String
    @State private var copied = false
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            
            Text(path)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button(copied ? "Copied!" : "Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(copied ? .green : Color.accentColor)
            .animation(.easeInOut(duration: 0.2), value: copied)
        }
    }
}

/// A horizontal progress bar showing a file's share of total assets
struct AssetSizeBar: View {
    let percentage: Double  // 0.0 – 1.0
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Share of Total Assets")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(percentage > 0.5 ? Color.orange : color)
                        .frame(width: max(4, geo.size.width * min(percentage, 1.0)), height: 8)
                        .animation(.spring(response: 0.45), value: percentage)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Asset Type Extension

extension AssetInfo.AssetType {
    var displayName: String {
        switch self {
        case .image: return "Image"
        case .assetsCatalog: return "Assets Catalog"
        case .video: return "Video"
        case .audio: return "Audio"
        case .font: return "Font"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .image: return "photo.fill"
        case .assetsCatalog: return "square.stack.3d.up.fill"
        case .video: return "video.fill"
        case .audio: return "music.note"
        case .font: return "textformat"
        case .other: return "doc.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .image: return .pink
        case .assetsCatalog: return .blue
        case .video: return .purple
        case .audio: return .green
        case .font: return .orange
        case .other: return .gray
        }
    }
}

#Preview {
    AssetsView(ipa: IPAInfo(
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
        assets: [
            AssetInfo(name: "Assets.car", size: 10_000_000, type: .assetsCatalog, path: "/Assets.car"),
            AssetInfo(name: "splash.png", size: 2_000_000, type: .image, path: "/splash.png"),
            AssetInfo(name: "background.jpg", size: 1_500_000, type: .image, path: "/background.jpg"),
            AssetInfo(name: "intro.mp4", size: 5_000_000, type: .video, path: "/intro.mp4")
        ],
        fileTree: FileNode(name: "TestApp.app", path: "/", size: 0, isDirectory: true)
    ))
}