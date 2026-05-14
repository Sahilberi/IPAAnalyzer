//
//  IPAViewModel.swift
//  IPA Bundle Analyzer
//
//  ViewModel for IPA analysis
//

import Foundation
import SwiftUI
import Combine

@MainActor
class IPAViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentIPA: IPAInfo?
    @Published var isAnalyzing = false
    @Published var progress: Double = 0
    @Published var error: Error?
    @Published var showError = false
    
    // File tree state
    @Published var searchText = ""
    @Published var sortOption: FileSortOption = .name
    
    // MARK: - Services
    
    private let analyzer = IPAAnalyzer()
    
    // MARK: - Analysis
    
    func analyzeIPA(url: URL) async {
        isAnalyzing = true
        progress = 0
        error = nil
        
        do {
            let ipaInfo = try await analyzer.analyzeIPA(at: url)
            currentIPA = ipaInfo
            progress = 1.0
        } catch {
            self.error = error
            self.showError = true
            print("Analysis failed: \(error.localizedDescription)")
        }
        
        isAnalyzing = false
    }
    
    func clearAnalysis() {
        currentIPA = nil
        error = nil
        progress = 0
    }
    
    // MARK: - File Tree Operations
    
    var filteredFiles: [FileNode] {
        guard let root = currentIPA?.fileTree else { return [] }
        
        if searchText.isEmpty {
            return [root]
        }
        
        let allFiles = root.flattenedNodes
        return allFiles.filter { node in
            node.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    func sortedChildren(of node: FileNode) -> [FileNode] {
        switch sortOption {
        case .name:
            return node.children.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            return node.children.sorted { $0.totalSize > $1.totalSize }
        case .type:
            return node.children.sorted { n1, n2 in
                if n1.isDirectory && !n2.isDirectory {
                    return true
                } else if !n1.isDirectory && n2.isDirectory {
                    return false
                } else {
                    return n1.name.localizedCaseInsensitiveCompare(n2.name) == .orderedAscending
                }
            }
        }
    }
    
    // MARK: - Export
    
    func exportJSON() -> String? {
        guard let ipa = currentIPA else { return nil }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        guard let data = try? encoder.encode(ipa),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return jsonString
    }
    
    func exportCSV() -> String? {
        guard let ipa = currentIPA else { return nil }
        
        var csv = "Category,Name,Size,Path\n"
        
        // Add metadata
        csv += "Metadata,App Name,\(ipa.metadata.appName),\n"
        csv += "Metadata,Bundle ID,\(ipa.metadata.bundleIdentifier),\n"
        csv += "Metadata,Version,\(ipa.metadata.version),\n"
        csv += "Metadata,Build,\(ipa.metadata.buildNumber),\n"
        csv += "\n"
        
        // Add size breakdown
        csv += "Size,Total,\(ipa.fileSize),\n"
        csv += "Size,Binary,\(ipa.sizeBreakdown.binarySize),\n"
        csv += "Size,Frameworks,\(ipa.sizeBreakdown.frameworksSize),\n"
        csv += "Size,Assets,\(ipa.sizeBreakdown.assetsSize),\n"
        csv += "Size,Plugins,\(ipa.sizeBreakdown.pluginsSize),\n"
        csv += "\n"
        
        // Add frameworks
        for framework in ipa.frameworks {
            csv += "Framework,\(framework.name),\(framework.size),\(framework.path)\n"
        }
        
        csv += "\n"
        
        // Add top assets
        for asset in ipa.assets.prefix(50) {
            csv += "Asset,\(asset.name),\(asset.size),\(asset.path)\n"
        }
        
        return csv
    }
    
  @MainActor
  func saveReport(content: String, fileName: String) {
      let panel = NSSavePanel()
      panel.nameFieldStringValue = fileName
      panel.canCreateDirectories = true

      if panel.runModal() == .OK,
         let url = panel.url {
          do {
              try content.write(to: url, atomically: true, encoding: .utf8)
              print("Saved successfully")
          } catch {
              print("Save failed:", error)
          }
      }
  }
}

// MARK: - Supporting Types

enum FileSortOption: String, CaseIterable {
    case name = "Name"
    case size = "Size"
    case type = "Type"
}
