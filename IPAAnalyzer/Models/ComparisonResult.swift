//
//  ComparisonResult.swift
//  IPA Bundle Analyzer
//
//  Model for IPA comparison results
//

import Foundation

/// Complete comparison between two IPA files
struct ComparisonResult: Identifiable {
    let id: UUID
    let firstIPA: IPAInfo
    let secondIPA: IPAInfo
    let sizeComparison: SizeComparison
    let fileChanges: FileChanges
    let frameworkChanges: FrameworkChanges
    let binaryChanges: BinaryChanges?
    let comparisonDate: Date
    
    init(
        id: UUID = UUID(),
        firstIPA: IPAInfo,
        secondIPA: IPAInfo,
        sizeComparison: SizeComparison,
        fileChanges: FileChanges,
        frameworkChanges: FrameworkChanges,
        binaryChanges: BinaryChanges?,
        comparisonDate: Date = Date()
    ) {
        self.id = id
        self.firstIPA = firstIPA
        self.secondIPA = secondIPA
        self.sizeComparison = sizeComparison
        self.fileChanges = fileChanges
        self.frameworkChanges = frameworkChanges
        self.binaryChanges = binaryChanges
        self.comparisonDate = comparisonDate
    }
}

/// Size comparison between two IPAs
struct SizeComparison {
    let totalSizeDiff: Int64
    let binarySizeDiff: Int64
    let frameworksSizeDiff: Int64
    let assetsSizeDiff: Int64
    let pluginsSizeDiff: Int64
    let othersSizeDiff: Int64
    
    var totalSizeChangePercentage: Double {
        guard secondIPA.fileSize > 0 else { return 0 }
        return (Double(totalSizeDiff) / Double(secondIPA.fileSize)) * 100
    }
    
    let firstIPA: IPAInfo
    let secondIPA: IPAInfo
    
    init(firstIPA: IPAInfo, secondIPA: IPAInfo) {
        self.firstIPA = firstIPA
        self.secondIPA = secondIPA
        
        self.totalSizeDiff = firstIPA.fileSize - secondIPA.fileSize
        self.binarySizeDiff = firstIPA.sizeBreakdown.binarySize - secondIPA.sizeBreakdown.binarySize
        self.frameworksSizeDiff = firstIPA.sizeBreakdown.frameworksSize - secondIPA.sizeBreakdown.frameworksSize
        self.assetsSizeDiff = firstIPA.sizeBreakdown.assetsSize - secondIPA.sizeBreakdown.assetsSize
        self.pluginsSizeDiff = firstIPA.sizeBreakdown.pluginsSize - secondIPA.sizeBreakdown.pluginsSize
        self.othersSizeDiff = firstIPA.sizeBreakdown.othersSize - secondIPA.sizeBreakdown.othersSize
    }
}

/// File-level changes
struct FileChanges {
    let added: [FileChange]
    let removed: [FileChange]
    let modified: [FileChange]
    
    var totalChanges: Int {
        added.count + removed.count + modified.count
    }
    
    var hasChanges: Bool {
        totalChanges > 0
    }
}

/// Individual file change
struct FileChange: Identifiable {
    let id: UUID
    let path: String
    let name: String
    let changeType: ChangeType
    let oldSize: Int64?
    let newSize: Int64?
    
    init(
        id: UUID = UUID(),
        path: String,
        name: String,
        changeType: ChangeType,
        oldSize: Int64?,
        newSize: Int64?
    ) {
        self.id = id
        self.path = path
        self.name = name
        self.changeType = changeType
        self.oldSize = oldSize
        self.newSize = newSize
    }
    
    var sizeDiff: Int64? {
        guard let old = oldSize, let new = newSize else { return nil }
        return new - old
    }
    
    enum ChangeType: String {
        case added = "Added"
        case removed = "Removed"
        case modified = "Modified"
        
        var color: String {
            switch self {
            case .added: return "green"
            case .removed: return "red"
            case .modified: return "orange"
            }
        }
    }
}

/// Framework changes
struct FrameworkChanges {
    let added: [FrameworkChange]
    let removed: [FrameworkChange]
    let modified: [FrameworkChange]
    
    var totalChanges: Int {
        added.count + removed.count + modified.count
    }
    
    var hasChanges: Bool {
        totalChanges > 0
    }
}

/// Individual framework change
struct FrameworkChange: Identifiable {
    let id: UUID
    let name: String
    let changeType: FileChange.ChangeType
    let oldVersion: String?
    let newVersion: String?
    let oldSize: Int64?
    let newSize: Int64?
    
    init(
        id: UUID = UUID(),
        name: String,
        changeType: FileChange.ChangeType,
        oldVersion: String?,
        newVersion: String?,
        oldSize: Int64?,
        newSize: Int64?
    ) {
        self.id = id
        self.name = name
        self.changeType = changeType
        self.oldVersion = oldVersion
        self.newVersion = newVersion
        self.oldSize = oldSize
        self.newSize = newSize
    }
    
    var versionChanged: Bool {
        oldVersion != newVersion
    }
    
    var sizeDiff: Int64? {
        guard let old = oldSize, let new = newSize else { return nil }
        return new - old
    }
}

/// Binary changes
struct BinaryChanges {
    let sizeDiff: Int64
    let architectureChanges: [ArchitectureChange]
    let segmentChanges: [SegmentChange]
    let bitcodeChanged: Bool
    
    var hasSignificantChanges: Bool {
        abs(sizeDiff) > 1_000_000 || !architectureChanges.isEmpty || bitcodeChanged
    }
}

/// Architecture change
struct ArchitectureChange: Identifiable {
    let id: UUID
    let name: String
    let changeType: FileChange.ChangeType
    
    init(id: UUID = UUID(), name: String, changeType: FileChange.ChangeType) {
        self.id = id
        self.name = name
        self.changeType = changeType
    }
}

/// Segment change
struct SegmentChange: Identifiable {
    let id: UUID
    let name: String
    let sizeDiff: Int64
    let oldSize: Int64
    let newSize: Int64
    
    init(id: UUID = UUID(), name: String, sizeDiff: Int64, oldSize: Int64, newSize: Int64) {
        self.id = id
        self.name = name
        self.sizeDiff = sizeDiff
        self.oldSize = oldSize
        self.newSize = newSize
    }
}

// MARK: - Filter Enums

enum ComparisonFilter: Hashable {
    case all
    case onlyChanges
    case largeChangesOnly(threshold: Int64)
    
    func shouldInclude(change: FileChange) -> Bool {
        switch self {
        case .all:
            return true
        case .onlyChanges:
            return change.changeType == .added || change.changeType == .removed || change.sizeDiff != 0
        case .largeChangesOnly(let threshold):
            guard let diff = change.sizeDiff else { return false }
            return abs(diff) >= threshold
        }
    }
}