//
//  IPAInfo.swift
//  IPA Bundle Analyzer
//
//  Core model for IPA metadata and analysis results
//

import Foundation

/// Represents complete IPA file information and analysis results
struct IPAInfo: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let filePath: URL
    let fileSize: Int64 // Compressed size
    let uncompressedSize: Int64
    let metadata: AppMetadata
    let sizeBreakdown: SizeBreakdown
    let binaryInfo: BinaryInfo?
    let frameworks: [FrameworkInfo]
    let assets: [AssetInfo]
    let fileTree: FileNode
    let analysisDate: Date
    
    init(
        id: UUID = UUID(),
        fileName: String,
        filePath: URL,
        fileSize: Int64,
        uncompressedSize: Int64,
        metadata: AppMetadata,
        sizeBreakdown: SizeBreakdown,
        binaryInfo: BinaryInfo?,
        frameworks: [FrameworkInfo],
        assets: [AssetInfo],
        fileTree: FileNode,
        analysisDate: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.fileSize = fileSize
        self.uncompressedSize = uncompressedSize
        self.metadata = metadata
        self.sizeBreakdown = sizeBreakdown
        self.binaryInfo = binaryInfo
        self.frameworks = frameworks
        self.assets = assets
        self.fileTree = fileTree
        self.analysisDate = analysisDate
    }
}

/// App metadata parsed from Info.plist
struct AppMetadata: Codable {
    let appName: String
    let bundleIdentifier: String
    let version: String // CFBundleShortVersionString
    let buildNumber: String // CFBundleVersion
    let minimumOSVersion: String
    let supportedDeviceFamilies: [DeviceFamily]
    let platformBuild: String?
    let sdkName: String?
    
    enum DeviceFamily: String, Codable, CaseIterable {
        case iPhone = "1"
        case iPad = "2"
        case appleTV = "3"
        case appleWatch = "4"
        
        var displayName: String {
            switch self {
            case .iPhone: return "iPhone"
            case .iPad: return "iPad"
            case .appleTV: return "Apple TV"
            case .appleWatch: return "Apple Watch"
            }
        }
    }
}

/// Hierarchical size breakdown
struct SizeBreakdown: Codable {
    let totalSize: Int64
    let binarySize: Int64
    let frameworksSize: Int64
    let assetsSize: Int64
    let pluginsSize: Int64
    let othersSize: Int64
    
    var items: [SizeItem] {
        [
            SizeItem(name: "Binary", size: binarySize, category: .binary),
            SizeItem(name: "Frameworks", size: frameworksSize, category: .frameworks),
            SizeItem(name: "Assets", size: assetsSize, category: .assets),
            SizeItem(name: "Plugins", size: pluginsSize, category: .plugins),
            SizeItem(name: "Others", size: othersSize, category: .others)
        ]
    }
}

/// Individual size item for visualization
struct SizeItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let size: Int64
    let category: Category
    
    init(id: UUID = UUID(), name: String, size: Int64, category: Category) {
        self.id = id
        self.name = name
        self.size = size
        self.category = category
    }
    
    enum Category: String, Codable {
        case binary
        case frameworks
        case assets
        case plugins
        case others
    }
}

/// Binary (Mach-O) information
struct BinaryInfo: Codable {
    let name: String
    let size: Int64
    let architectures: [Architecture]
    let segments: [Segment]
    let hasBitcode: Bool
    let symbolsCount: Int?
    
    struct Architecture: Codable, Identifiable {
        let id: UUID
        let name: String // arm64, armv7, etc.
        let cpuType: String
        let cpuSubtype: String
        
        init(id: UUID = UUID(), name: String, cpuType: String, cpuSubtype: String) {
            self.id = id
            self.name = name
            self.cpuType = cpuType
            self.cpuSubtype = cpuSubtype
        }
    }
    
    struct Segment: Codable, Identifiable {
        let id: UUID
        let name: String // __TEXT, __DATA, __LINKEDIT
        let size: Int64
        let vmSize: Int64
        let fileOffset: Int64
        
        init(id: UUID = UUID(), name: String, size: Int64, vmSize: Int64, fileOffset: Int64) {
            self.id = id
            self.name = name
            self.size = size
            self.vmSize = vmSize
            self.fileOffset = fileOffset
        }
    }
}

/// Framework information
struct FrameworkInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let size: Int64
    let version: String?
    let path: String
    let isDuplicate: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        size: Int64,
        version: String?,
        path: String,
        isDuplicate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.version = version
        self.path = path
        self.isDuplicate = isDuplicate
    }
}

/// Asset information
struct AssetInfo: Identifiable, Codable {
    let id: UUID
    let name: String
    let size: Int64
    let type: AssetType
    let path: String
    
    init(id: UUID = UUID(), name: String, size: Int64, type: AssetType, path: String) {
        self.id = id
        self.name = name
        self.size = size
        self.type = type
        self.path = path
    }
    
    enum AssetType: String, Codable {
        case image
        case assetsCatalog
        case video
        case audio
        case font
        case other
    }
}

// MARK: - Formatting Helpers

extension Int64 {
    /// Format bytes to human-readable string
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: self)
    }
}