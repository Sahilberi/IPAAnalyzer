//
//  FileNode.swift
//  IPA Bundle Analyzer
//
//  Hierarchical file tree structure
//

import Foundation
import Combine

/// Represents a file or directory in the IPA
final class FileNode: Identifiable, ObservableObject {
    let id: UUID
    let name: String
    let path: String
    let size: Int64
    let isDirectory: Bool
    @Published var children: [FileNode]
    @Published var isExpanded: Bool
    weak var parent: FileNode?
    
    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        size: Int64,
        isDirectory: Bool,
        children: [FileNode] = [],
        parent: FileNode? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
        self.isExpanded = false
        self.parent = parent
        
        // Set parent reference for all children
        self.children.forEach { $0.parent = self }
    }
    
    /// Total size including all children
    var totalSize: Int64 {
        if isDirectory {
            return children.reduce(size) { $0 + $1.totalSize }
        }
        return size
    }
    
    /// Recursively flatten all nodes
    var flattenedNodes: [FileNode] {
        var nodes = [self]
        for child in children {
            nodes.append(contentsOf: child.flattenedNodes)
        }
        return nodes
    }
    
    /// Find node by path
    func findNode(path: String) -> FileNode? {
        if self.path == path {
            return self
        }
        for child in children {
            if let found = child.findNode(path: path) {
                return found
            }
        }
        return nil
    }
    
    /// Sort children by size (descending)
    func sortChildrenBySize() {
        children.sort { $0.totalSize > $1.totalSize }
        children.forEach { $0.sortChildrenBySize() }
    }
    
    /// Sort children by name
    func sortChildrenByName() {
        children.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        children.forEach { $0.sortChildrenByName() }
    }
    
    /// Get file extension
    var fileExtension: String {
        if isDirectory { return "" }
        return (name as NSString).pathExtension
    }
    
    /// Get icon name for file type
    var iconName: String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        }
        
        let ext = fileExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "svg":
            return "photo"
        case "pdf":
            return "doc.text"
        case "txt", "rtf":
            return "doc.plaintext"
        case "mp4", "mov", "avi":
            return "video"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "dylib", "framework":
            return "shippingbox"
        case "plist":
            return "list.bullet"
        case "car":
            return "square.stack.3d.up"
        default:
            return "doc"
        }
    }
}

// MARK: - Codable Support

extension FileNode: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, path, size, isDirectory, children
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let path = try container.decode(String.self, forKey: .path)
        let size = try container.decode(Int64.self, forKey: .size)
        let isDirectory = try container.decode(Bool.self, forKey: .isDirectory)
        let children = try container.decode([FileNode].self, forKey: .children)
        
        self.init(
            id: id,
            name: name,
            path: path,
            size: size,
            isDirectory: isDirectory,
            children: children
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encode(size, forKey: .size)
        try container.encode(isDirectory, forKey: .isDirectory)
        try container.encode(children, forKey: .children)
    }
}

// MARK: - Builder

extension FileNode {
    /// Build file tree from directory URL
    static func buildTree(from url: URL, basePath: String = "") throws -> FileNode {
        let fileManager = FileManager.default
        let isDirectory = try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? Int64 ?? 0
        
        let relativePath = basePath.isEmpty ? url.lastPathComponent : basePath + "/" + url.lastPathComponent
        let node = FileNode(
            name: url.lastPathComponent,
            path: relativePath,
            size: size,
            isDirectory: isDirectory
        )
        
        if isDirectory {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            
            node.children = try contents.map { childURL in
                try buildTree(from: childURL, basePath: relativePath)
            }
            
            // Set parent references
            node.children.forEach { $0.parent = node }
        }
        
        return node
    }
}