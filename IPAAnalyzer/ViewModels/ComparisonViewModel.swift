//
//  ComparisonViewModel.swift
//  IPA Bundle Analyzer
//
//  ViewModel for IPA comparison
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ComparisonViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var firstIPA: IPAInfo?
    @Published var secondIPA: IPAInfo?
    @Published var comparisonResult: ComparisonResult?
    
    @Published var isAnalyzingFirst = false
    @Published var isAnalyzingSecond = false
    @Published var isComparing = false
    
    @Published var error: Error?
    @Published var showError = false
    
    @Published var selectedFilter: ComparisonFilter = .all
    @Published var searchText = ""
    
    // MARK: - Services
    
    private let analyzer = IPAAnalyzer()
    private let diffEngine = DiffEngine()
    
    // MARK: - IPA Loading
    
    func loadFirstIPA(url: URL) async {
        isAnalyzingFirst = true
        error = nil
        
        do {
            let ipaInfo = try await analyzer.analyzeIPA(at: url)
            firstIPA = ipaInfo
            
            // Auto-compare if both IPAs are loaded
            if secondIPA != nil {
                await compareIPAs()
            }
        } catch {
            self.error = error
            self.showError = true
            print("First IPA analysis failed: \(error.localizedDescription)")
        }
        
        isAnalyzingFirst = false
    }
    
    func loadSecondIPA(url: URL) async {
        isAnalyzingSecond = true
        error = nil
        
        do {
            let ipaInfo = try await analyzer.analyzeIPA(at: url)
            secondIPA = ipaInfo
            
            // Auto-compare if both IPAs are loaded
            if firstIPA != nil {
                await compareIPAs()
            }
        } catch {
            self.error = error
            self.showError = true
            print("Second IPA analysis failed: \(error.localizedDescription)")
        }
        
        isAnalyzingSecond = false
    }
    
    func clearFirstIPA() {
        firstIPA = nil
        comparisonResult = nil
    }
    
    func clearSecondIPA() {
        secondIPA = nil
        comparisonResult = nil
    }
    
    func clearAll() {
        firstIPA = nil
        secondIPA = nil
        comparisonResult = nil
        error = nil
    }
    
    // MARK: - Comparison
    
    func compareIPAs() async {
        guard let first = firstIPA, let second = secondIPA else {
            return
        }
        
        isComparing = true
        
        // Run comparison on background thread
        let result = await Task.detached {
            return self.diffEngine.compare(firstIPA: first, secondIPA: second)
        }.value
        
        comparisonResult = result
        isComparing = false
    }
    
    // MARK: - Filtering
    
    var filteredFileChanges: FileChanges {
        guard let changes = comparisonResult?.fileChanges else {
            return FileChanges(added: [], removed: [], modified: [])
        }
        
        let added = filterChanges(changes.added)
        let removed = filterChanges(changes.removed)
        let modified = filterChanges(changes.modified)
        
        return FileChanges(added: added, removed: removed, modified: modified)
    }
    
    private func filterChanges(_ changes: [FileChange]) -> [FileChange] {
        var filtered = changes
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { change in
                change.name.localizedCaseInsensitiveContains(searchText) ||
                change.path.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply comparison filter
        switch selectedFilter {
        case .all:
            break
        case .onlyChanges:
            filtered = filtered.filter { $0.changeType != .modified || $0.sizeDiff != 0 }
        case .largeChangesOnly(let threshold):
            filtered = filtered.filter { change in
                if let diff = change.sizeDiff {
                    return abs(diff) >= threshold
                }
                return (change.newSize ?? 0) >= threshold || (change.oldSize ?? 0) >= threshold
            }
        }
        
        return filtered
    }
    
    // MARK: - Export
    
    func exportComparisonJSON() -> String? {
        guard let result = comparisonResult else { return nil }
        
        // Create simplified comparison report
        let report: [String: Any] = [
            "first_ipa": [
                "name": result.firstIPA.fileName,
                "version": result.firstIPA.metadata.version,
                "build": result.firstIPA.metadata.buildNumber,
                "size": result.firstIPA.fileSize
            ],
            "second_ipa": [
                "name": result.secondIPA.fileName,
                "version": result.secondIPA.metadata.version,
                "build": result.secondIPA.metadata.buildNumber,
                "size": result.secondIPA.fileSize
            ],
            "size_changes": [
                "total_diff": result.sizeComparison.totalSizeDiff,
                "binary_diff": result.sizeComparison.binarySizeDiff,
                "frameworks_diff": result.sizeComparison.frameworksSizeDiff,
                "assets_diff": result.sizeComparison.assetsSizeDiff
            ],
            "file_changes": [
                "added_count": result.fileChanges.added.count,
                "removed_count": result.fileChanges.removed.count,
                "modified_count": result.fileChanges.modified.count
            ],
            "framework_changes": [
                "added_count": result.frameworkChanges.added.count,
                "removed_count": result.frameworkChanges.removed.count,
                "modified_count": result.frameworkChanges.modified.count
            ]
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: report, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    func exportComparisonCSV() -> String? {
        guard let result = comparisonResult else { return nil }
        
        var csv = "IPA Comparison Report\n\n"
        
        // Summary
        csv += "Category,Metric,Old Value,New Value,Difference\n"
        csv += "Size,Total,\(result.secondIPA.fileSize),\(result.firstIPA.fileSize),\(result.sizeComparison.totalSizeDiff)\n"
        csv += "Size,Binary,\(result.secondIPA.sizeBreakdown.binarySize),\(result.firstIPA.sizeBreakdown.binarySize),\(result.sizeComparison.binarySizeDiff)\n"
        csv += "Size,Frameworks,\(result.secondIPA.sizeBreakdown.frameworksSize),\(result.firstIPA.sizeBreakdown.frameworksSize),\(result.sizeComparison.frameworksSizeDiff)\n"
        csv += "Size,Assets,\(result.secondIPA.sizeBreakdown.assetsSize),\(result.firstIPA.sizeBreakdown.assetsSize),\(result.sizeComparison.assetsSizeDiff)\n"
        csv += "\n"
        
        // File changes
        csv += "File Changes\n"
        csv += "Type,Name,Old Size,New Size,Difference\n"
        
        for change in result.fileChanges.added {
            csv += "Added,\(change.name),,\(change.newSize ?? 0),\n"
        }
        
        for change in result.fileChanges.removed {
            csv += "Removed,\(change.name),\(change.oldSize ?? 0),,\n"
        }
        
        for change in result.fileChanges.modified {
            let diff = (change.newSize ?? 0) - (change.oldSize ?? 0)
            csv += "Modified,\(change.name),\(change.oldSize ?? 0),\(change.newSize ?? 0),\(diff)\n"
        }
        
        csv += "\n"
        
        // Framework changes
        csv += "Framework Changes\n"
        csv += "Type,Name,Old Version,New Version,Old Size,New Size,Difference\n"
        
        for change in result.frameworkChanges.added {
            csv += "Added,\(change.name),,\(change.newVersion ?? ""),,\(change.newSize ?? 0),\n"
        }
        
        for change in result.frameworkChanges.removed {
            csv += "Removed,\(change.name),\(change.oldVersion ?? ""),,\(change.oldSize ?? 0),,\n"
        }
        
        for change in result.frameworkChanges.modified {
            let diff = (change.newSize ?? 0) - (change.oldSize ?? 0)
            csv += "Modified,\(change.name),\(change.oldVersion ?? ""),\(change.newVersion ?? ""),\(change.oldSize ?? 0),\(change.newSize ?? 0),\(diff)\n"
        }
        
        return csv
    }
    
    func saveReport(content: String, fileName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.canCreateDirectories = true
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}