//
//  IPAExtractor.swift
//  IPA Bundle Analyzer
//
//  Service for extracting and handling IPA files
//

import Foundation
import UniformTypeIdentifiers
import Combine

/// Errors that can occur during IPA extraction
enum IPAExtractionError: LocalizedError {
    case invalidFileType
    case fileNotFound
    case extractionFailed(reason: String)
    case payloadNotFound
    case appBundleNotFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidFileType:
            return "The selected file is not a valid IPA, App Bundle (.app), or App Extension (.appex) file."
        case .fileNotFound:
            return "The IPA file could not be found."
        case .extractionFailed(let reason):
            return "Failed to extract IPA: \(reason)"
        case .payloadNotFound:
            return "The IPA file does not contain a Payload folder."
        case .appBundleNotFound:
            return "No .app bundle found in the Payload folder."
        case .permissionDenied:
            return "Permission denied to access the file."
        }
    }
}

/// Progress information for extraction
struct ExtractionProgress {
    let currentFile: String
    let processedFiles: Int
    let totalFiles: Int
    
    var percentage: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles) * 100
    }
}

/// Service for extracting IPA files
@MainActor
class IPAExtractor: ObservableObject {
    
    @Published var isExtracting = false
    @Published var progress: ExtractionProgress?
    
    private let fileManager = FileManager.default
    
    /// Validate if file is a valid IPA, App Bundle, or App Extension
    func validateIPA(at url: URL) throws {
        // Check if file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw IPAExtractionError.fileNotFound
        }
        
        // Check file extension
        let ext = url.pathExtension.lowercased()
        guard ext == "ipa" || ext == "app" || ext == "appex" else {
            throw IPAExtractionError.invalidFileType
        }
        
        // Check if file is readable
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw IPAExtractionError.permissionDenied
        }
    }
    
    /// Extract IPA to temporary directory, or return .app/.appex bundle URL directly
    func extractIPA(from ipaURL: URL) async throws -> URL {
        try validateIPA(at: ipaURL)
        
        let ext = ipaURL.pathExtension.lowercased()
        // .app and .appex are already extracted bundle directories — return as-is
        if ext == "app" || ext == "appex" {
            return ipaURL
        }
        
        await MainActor.run {
            isExtracting = true
        }
        
        defer {
            Task { @MainActor in
                isExtracting = false
                progress = nil
            }
        }
        
        // Create temp directory
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Extract using unzip command
        let extractionURL = tempDir.appendingPathComponent("extracted")
        try fileManager.createDirectory(at: extractionURL, withIntermediateDirectories: true)
        
        try await extractZip(ipaURL, to: extractionURL)
        
        // Verify Payload folder exists
        let payloadURL = extractionURL.appendingPathComponent("Payload")
        guard fileManager.fileExists(atPath: payloadURL.path) else {
            throw IPAExtractionError.payloadNotFound
        }
        
        // Find .app bundle
        let contents = try fileManager.contentsOfDirectory(
            at: payloadURL,
            includingPropertiesForKeys: nil
        )
        
        guard let appBundle = contents.first(where: { $0.pathExtension == "app" }) else {
            throw IPAExtractionError.appBundleNotFound
        }
        
        return appBundle
    }
    
    /// Extract ZIP using unzip command
    private func extractZip(_ zipURL: URL, to destination: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = [
            "-q", // Quiet mode
            "-o", // Overwrite
            zipURL.path,
            "-d", destination.path
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw IPAExtractionError.extractionFailed(reason: output)
        }
    }
    
    /// Clean up temporary directory
    func cleanupTemp(at url: URL) {
        // Go up to the temp root (UUID directory)
        var tempRoot = url
        while tempRoot.lastPathComponent != "extracted" && tempRoot.pathComponents.count > 1 {
            tempRoot = tempRoot.deletingLastPathComponent()
        }
        tempRoot = tempRoot.deletingLastPathComponent()
        
        try? fileManager.removeItem(at: tempRoot)
    }
    
    /// Get file size
    func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    /// Calculate total uncompressed size recursively
    func calculateUncompressedSize(at url: URL) throws -> Int64 {
        var totalSize: Int64 = 0
        
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
}

// MARK: - File Type Detection

extension IPAExtractor {
    
    /// Check if URL is a valid IPA, App Bundle, or App Extension file
    static func isValidIPA(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        guard ext == "ipa" || ext == "app" || ext == "appex" else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }
}