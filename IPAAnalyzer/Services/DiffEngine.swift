//
//  DiffEngine.swift
//  IPA Bundle Analyzer
//
//  Service for comparing two IPA files
//

import Foundation

/// Engine for comparing two IPA files
class DiffEngine {
    
    /// Compare two IPA files
    func compare(firstIPA: IPAInfo, secondIPA: IPAInfo) -> ComparisonResult {
        let sizeComparison = SizeComparison(firstIPA: firstIPA, secondIPA: secondIPA)
        let fileChanges = compareFiles(firstIPA: firstIPA, secondIPA: secondIPA)
        let frameworkChanges = compareFrameworks(firstIPA: firstIPA, secondIPA: secondIPA)
        let binaryChanges = compareBinaries(firstIPA: firstIPA, secondIPA: secondIPA)
        
        return ComparisonResult(
            firstIPA: firstIPA,
            secondIPA: secondIPA,
            sizeComparison: sizeComparison,
            fileChanges: fileChanges,
            frameworkChanges: frameworkChanges,
            binaryChanges: binaryChanges
        )
    }
    
    // MARK: - File Comparison
    
    private func compareFiles(firstIPA: IPAInfo, secondIPA: IPAInfo) -> FileChanges {
        let firstFiles = collectFiles(from: firstIPA.fileTree)
        let secondFiles = collectFiles(from: secondIPA.fileTree)
        
        var added: [FileChange] = []
        var removed: [FileChange] = []
        var modified: [FileChange] = []
        
        // Find added files
        for (path, node) in firstFiles {
            if secondFiles[path] == nil {
                added.append(FileChange(
                    path: path,
                    name: node.name,
                    changeType: .added,
                    oldSize: nil,
                    newSize: node.size
                ))
            }
        }
        
        // Find removed and modified files
        for (path, node) in secondFiles {
            if let firstNode = firstFiles[path] {
                // File exists in both
                if firstNode.size != node.size {
                    modified.append(FileChange(
                        path: path,
                        name: node.name,
                        changeType: .modified,
                        oldSize: node.size,
                        newSize: firstNode.size
                    ))
                }
            } else {
                // File removed
                removed.append(FileChange(
                    path: path,
                    name: node.name,
                    changeType: .removed,
                    oldSize: node.size,
                    newSize: nil
                ))
            }
        }
        
        // Sort by size impact
        added.sort { ($0.newSize ?? 0) > ($1.newSize ?? 0) }
        removed.sort { ($0.oldSize ?? 0) > ($1.oldSize ?? 0) }
        modified.sort { lhs, rhs in
            let lhsDiff: Int64 = abs((lhs.newSize ?? 0) - (lhs.oldSize ?? 0))
            let rhsDiff: Int64 = abs((rhs.newSize ?? 0) - (rhs.oldSize ?? 0))
            return lhsDiff > rhsDiff
        }
        
        return FileChanges(added: added, removed: removed, modified: modified)
    }
    
    private func collectFiles(from node: FileNode) -> [String: FileNode] {
        var files: [String: FileNode] = [:]
        
        func traverse(_ n: FileNode) {
            if !n.isDirectory {
                files[n.path] = n
            }
            for child in n.children {
                traverse(child)
            }
        }
        
        traverse(node)
        return files
    }
    
    // MARK: - Framework Comparison
    
    private func compareFrameworks(firstIPA: IPAInfo, secondIPA: IPAInfo) -> FrameworkChanges {
        let firstFrameworks = Dictionary(uniqueKeysWithValues: firstIPA.frameworks.map { ($0.name, $0) })
        let secondFrameworks = Dictionary(uniqueKeysWithValues: secondIPA.frameworks.map { ($0.name, $0) })
        
        var added: [FrameworkChange] = []
        var removed: [FrameworkChange] = []
        var modified: [FrameworkChange] = []
        
        // Find added frameworks
        for (name, framework) in firstFrameworks {
            if secondFrameworks[name] == nil {
                added.append(FrameworkChange(
                    name: name,
                    changeType: .added,
                    oldVersion: nil,
                    newVersion: framework.version,
                    oldSize: nil,
                    newSize: framework.size
                ))
            }
        }
        
        // Find removed and modified frameworks
        for (name, oldFramework) in secondFrameworks {
            if let newFramework = firstFrameworks[name] {
                // Framework exists in both
                let versionChanged = oldFramework.version != newFramework.version
                let sizeChanged = oldFramework.size != newFramework.size
                
                if versionChanged || sizeChanged {
                    modified.append(FrameworkChange(
                        name: name,
                        changeType: .modified,
                        oldVersion: oldFramework.version,
                        newVersion: newFramework.version,
                        oldSize: oldFramework.size,
                        newSize: newFramework.size
                    ))
                }
            } else {
                // Framework removed
                removed.append(FrameworkChange(
                    name: name,
                    changeType: .removed,
                    oldVersion: oldFramework.version,
                    newVersion: nil,
                    oldSize: oldFramework.size,
                    newSize: nil
                ))
            }
        }
        
        // Sort by size impact
        added.sort { ($0.newSize ?? 0) > ($1.newSize ?? 0) }
        removed.sort { ($0.oldSize ?? 0) > ($1.oldSize ?? 0) }
        modified.sort { lhs, rhs in
            let lhsDiff: Int64 = abs((lhs.newSize ?? 0) - (lhs.oldSize ?? 0))
            let rhsDiff: Int64 = abs((rhs.newSize ?? 0) - (rhs.oldSize ?? 0))
            return lhsDiff > rhsDiff
        }
        
        return FrameworkChanges(added: added, removed: removed, modified: modified)
    }
    
    // MARK: - Binary Comparison
    
    private func compareBinaries(firstIPA: IPAInfo, secondIPA: IPAInfo) -> BinaryChanges? {
        guard let firstBinary = firstIPA.binaryInfo,
              let secondBinary = secondIPA.binaryInfo else {
            return nil
        }
        
        let sizeDiff = firstBinary.size - secondBinary.size
        
        // Compare architectures
        let firstArchs = Set(firstBinary.architectures.map { $0.name })
        let secondArchs = Set(secondBinary.architectures.map { $0.name })
        
        var archChanges: [ArchitectureChange] = []
        
        for arch in firstArchs.subtracting(secondArchs) {
            archChanges.append(ArchitectureChange(name: arch, changeType: .added))
        }
        
        for arch in secondArchs.subtracting(firstArchs) {
            archChanges.append(ArchitectureChange(name: arch, changeType: .removed))
        }
        
        // Compare segments
        let firstSegments = Dictionary(uniqueKeysWithValues: firstBinary.segments.map { ($0.name, $0) })
        let secondSegments = Dictionary(uniqueKeysWithValues: secondBinary.segments.map { ($0.name, $0) })
        
        var segmentChanges: [SegmentChange] = []
        
        for (name, newSegment) in firstSegments {
            if let oldSegment = secondSegments[name] {
                if newSegment.size != oldSegment.size {
                    segmentChanges.append(SegmentChange(
                        name: name,
                        sizeDiff: newSegment.size - oldSegment.size,
                        oldSize: oldSegment.size,
                        newSize: newSegment.size
                    ))
                }
            }
        }
        
        let bitcodeChanged = firstBinary.hasBitcode != secondBinary.hasBitcode
        
        return BinaryChanges(
            sizeDiff: sizeDiff,
            architectureChanges: archChanges,
            segmentChanges: segmentChanges,
            bitcodeChanged: bitcodeChanged
        )
    }
}