//
//  IPAAnalyzer.swift
//  IPA Bundle Analyzer
//
//  Service for analyzing IPA contents
//

import Foundation
import Combine

/// Service for analyzing IPA files
@MainActor
class IPAAnalyzer: ObservableObject {
    
    private let extractor = IPAExtractor()
    private let binaryParser = BinaryParser()
    
    /// Analyze IPA, App Bundle, or App Extension file completely
    func analyzeIPA(at ipaURL: URL) async throws -> IPAInfo {
        let ext = ipaURL.pathExtension.lowercased()
        let isBundle = (ext == "app" || ext == "appex")
        
        // For .ipa: extract to temp dir and return .app bundle URL
        // For .app/.appex: the URL IS the bundle directory — returned as-is
        let appBundleURL = try await extractor.extractIPA(from: ipaURL)
        
        defer {
            // Only clean up temp extraction for .ipa files
            if !isBundle {
                extractor.cleanupTemp(at: appBundleURL)
            }
        }
        
        // Parse Info.plist
        let metadata = try parseMetadata(from: appBundleURL)
        
        // Build file tree
        let fileTree = try FileNode.buildTree(from: appBundleURL, basePath: "")
        
        // Analyze sizes
        let sizeBreakdown = try analyzeSizes(in: appBundleURL, fileTree: fileTree)
        
        // Parse binary
        let binaryInfo = try? parseBinary(in: appBundleURL, appName: metadata.appName)
        
        // Analyze frameworks
        let frameworks = try analyzeFrameworks(in: appBundleURL)
        
        // Analyze assets
        let assets = try analyzeAssets(in: appBundleURL, fileTree: fileTree)
        
        // For .app/.appex the "file size" is the total uncompressed bundle size (it's not a zip)
        let uncompressedSize = try extractor.calculateUncompressedSize(at: appBundleURL)
        let fileSize: Int64 = isBundle
            ? uncompressedSize
            : (try extractor.getFileSize(at: ipaURL))
        
        return IPAInfo(
            fileName: ipaURL.lastPathComponent,
            filePath: ipaURL,
            fileSize: fileSize,
            uncompressedSize: uncompressedSize,
            metadata: metadata,
            sizeBreakdown: sizeBreakdown,
            binaryInfo: binaryInfo,
            frameworks: frameworks,
            assets: assets,
            fileTree: fileTree
        )
    }
    
    // MARK: - Metadata Parsing
    
    private func parseMetadata(from appBundleURL: URL) throws -> AppMetadata {
        let infoPlistURL = appBundleURL.appendingPathComponent("Info.plist")
        
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            throw NSError(domain: "IPAAnalyzer", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Info.plist not found"
            ])
        }
        
        let data = try Data(contentsOf: infoPlistURL)
        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw NSError(domain: "IPAAnalyzer", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse Info.plist"
            ])
        }
        
        let appName = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? "Unknown"
        
        let bundleIdentifier = plist["CFBundleIdentifier"] as? String ?? "Unknown"
        let version = plist["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = plist["CFBundleVersion"] as? String ?? "Unknown"
        let minimumOSVersion = plist["MinimumOSVersion"] as? String ?? "Unknown"
        
        let deviceFamilies: [AppMetadata.DeviceFamily]
        if let familyNumbers = plist["UIDeviceFamily"] as? [Int] {
            deviceFamilies = familyNumbers.compactMap { num in
                AppMetadata.DeviceFamily(rawValue: String(num))
            }
        } else {
            deviceFamilies = [.iPhone]
        }
        
        let platformBuild = plist["DTPlatformBuild"] as? String
        let sdkName = plist["DTSDKName"] as? String
        
        return AppMetadata(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            version: version,
            buildNumber: buildNumber,
            minimumOSVersion: minimumOSVersion,
            supportedDeviceFamilies: deviceFamilies,
            platformBuild: platformBuild,
            sdkName: sdkName
        )
    }
    
    // MARK: - Size Analysis
    
    private func analyzeSizes(in appBundleURL: URL, fileTree: FileNode) throws -> SizeBreakdown {
        let fileManager = FileManager.default
        
        var binarySize: Int64 = 0
        var frameworksSize: Int64 = 0
        var assetsSize: Int64 = 0
        var pluginsSize: Int64 = 0
        var othersSize: Int64 = 0
        
        // Find binary
        if let binaryNode = findMainBinary(in: fileTree) {
            binarySize = binaryNode.totalSize
        }
        
        // Calculate frameworks size
        let frameworksURL = appBundleURL.appendingPathComponent("Frameworks")
        if fileManager.fileExists(atPath: frameworksURL.path) {
            frameworksSize = try calculateDirectorySize(frameworksURL)
        }
        
        // Calculate assets size
        assetsSize = calculateAssetsSize(in: fileTree)
        
        // Calculate plugins size
        let pluginsURL = appBundleURL.appendingPathComponent("PlugIns")
        if fileManager.fileExists(atPath: pluginsURL.path) {
            pluginsSize = try calculateDirectorySize(pluginsURL)
        }
        
        let totalSize = fileTree.totalSize
        othersSize = max(0, totalSize - binarySize - frameworksSize - assetsSize - pluginsSize)
        
        return SizeBreakdown(
            totalSize: totalSize,
            binarySize: binarySize,
            frameworksSize: frameworksSize,
            assetsSize: assetsSize,
            pluginsSize: pluginsSize,
            othersSize: othersSize
        )
    }
    
    private func findMainBinary(in fileTree: FileNode) -> FileNode? {
        // The main binary is typically at the root with no extension
        return fileTree.children.first { node in
            !node.isDirectory && node.fileExtension.isEmpty && node.size > 0
        }
    }
    
    private func calculateAssetsSize(in fileTree: FileNode) -> Int64 {
        var totalSize: Int64 = 0
        
        func traverse(_ node: FileNode) {
            if !node.isDirectory {
                let ext = node.fileExtension.lowercased()
                if ["png", "jpg", "jpeg", "gif", "car", "pdf", "svg"].contains(ext) {
                    totalSize += node.size
                }
            }
            
            for child in node.children {
                traverse(child)
            }
        }
        
        traverse(fileTree)
        return totalSize
    }
    
    private func calculateDirectorySize(_ url: URL) throws -> Int64 {
        var totalSize: Int64 = 0
        let fileManager = FileManager.default
        
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            
            if resourceValues.isDirectory == false {
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }
        }
        
        return totalSize
    }
    
    // MARK: - Binary Analysis
    
    private func parseBinary(in appBundleURL: URL, appName: String) throws -> BinaryInfo {
        // Find the main executable
        let binaryURL = appBundleURL.appendingPathComponent(appName)
        
        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            throw NSError(domain: "IPAAnalyzer", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Main binary not found"
            ])
        }
        
        return try binaryParser.parse(binaryURL: binaryURL)
    }
    
    // MARK: - Framework Analysis
    
    private func analyzeFrameworks(in appBundleURL: URL) throws -> [FrameworkInfo] {
        let frameworksURL = appBundleURL.appendingPathComponent("Frameworks")
        
        guard FileManager.default.fileExists(atPath: frameworksURL.path) else {
            return []
        }
        
        let contents = try FileManager.default.contentsOfDirectory(
            at: frameworksURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        
        var frameworks: [FrameworkInfo] = []
        var frameworkNames: [String: Int] = [:]
        
        for frameworkURL in contents where frameworkURL.pathExtension == "framework" {
            let name = frameworkURL.deletingPathExtension().lastPathComponent
            let size = try calculateDirectorySize(frameworkURL)
            let version = try? extractFrameworkVersion(from: frameworkURL)
            
            // Check for duplicates
            frameworkNames[name, default: 0] += 1
            let isDuplicate = frameworkNames[name]! > 1
            
            frameworks.append(FrameworkInfo(
                name: name,
                size: size,
                version: version,
                path: frameworkURL.path,
                isDuplicate: isDuplicate
            ))
        }
        
        return frameworks.sorted { $0.size > $1.size }
    }
    
    private func extractFrameworkVersion(from frameworkURL: URL) throws -> String? {
        let infoPlistURL = frameworkURL.appendingPathComponent("Info.plist")
        
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: infoPlistURL)
        guard let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            return nil
        }
        
        return plist["CFBundleShortVersionString"] as? String
    }
    
    // MARK: - Assets Analysis
    
    private func analyzeAssets(in appBundleURL: URL, fileTree: FileNode) throws -> [AssetInfo] {
        var assets: [AssetInfo] = []
        
        func traverse(_ node: FileNode) {
            if !node.isDirectory && node.size > 0 {
                if let assetType = getAssetType(for: node) {
                    assets.append(AssetInfo(
                        name: node.name,
                        size: node.size,
                        type: assetType,
                        path: node.path
                    ))
                }
            }
            
            for child in node.children {
                traverse(child)
            }
        }
        
        traverse(fileTree)
        
        return assets.sorted { $0.size > $1.size }
    }
    
    private func getAssetType(for node: FileNode) -> AssetInfo.AssetType? {
        let ext = node.fileExtension.lowercased()
        
        switch ext {
        case "png", "jpg", "jpeg", "gif", "svg", "pdf":
            return .image
        case "car":
            return .assetsCatalog
        case "mp4", "mov", "m4v", "avi":
            return .video
        case "mp3", "m4a", "wav", "aac":
            return .audio
        case "ttf", "otf":
            return .font
        default:
            // Only include significant files
            if node.size > 100_000 { // > 100KB
                return .other
            }
            return nil
        }
    }
}