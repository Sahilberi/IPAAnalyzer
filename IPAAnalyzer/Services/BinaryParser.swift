//
//  BinaryParser.swift
//  IPA Bundle Analyzer
//
//  Service for parsing Mach-O binary files
//

import Foundation

/// Parser for Mach-O binary files
class BinaryParser {
    
    // Mach-O magic numbers
    private let MH_MAGIC_64: UInt32 = 0xfeedfacf
    private let MH_CIGAM_64: UInt32 = 0xcffaedfe
    private let FAT_MAGIC: UInt32 = 0xcafebabe
    private let FAT_CIGAM: UInt32 = 0xbebafeca
    
    // Load commands
    private let LC_SEGMENT_64: UInt32 = 0x19
    private let LC_SYMTAB: UInt32 = 0x2
    
    func parse(binaryURL: URL) throws -> BinaryInfo {
        let data = try Data(contentsOf: binaryURL)
        let size = Int64(data.count)
        
        // Read magic number
        let magic = data.withUnsafeBytes { $0.load(as: UInt32.self) }
        
        let architectures: [BinaryInfo.Architecture]
        let segments: [BinaryInfo.Segment]
        let hasBitcode: Bool
        let symbolsCount: Int?
        
        if magic == FAT_MAGIC || magic == FAT_CIGAM {
            // Fat binary (multiple architectures)
            architectures = try parseFatBinary(data: data)
            segments = [] // Would need to parse each architecture
            hasBitcode = false
            symbolsCount = nil
        } else if magic == MH_MAGIC_64 || magic == MH_CIGAM_64 {
            // Single architecture
            let arch = try parseMachO64(data: data)
            architectures = [arch.architecture]
            segments = arch.segments
            hasBitcode = arch.hasBitcode
            symbolsCount = arch.symbolsCount
        } else {
            // Try to get basic info using otool
            architectures = try parseWithOtool(binaryURL: binaryURL)
            segments = []
            hasBitcode = false
            symbolsCount = nil
        }
        
        return BinaryInfo(
            name: binaryURL.lastPathComponent,
            size: size,
            architectures: architectures,
            segments: segments,
            hasBitcode: hasBitcode,
            symbolsCount: symbolsCount
        )
    }
    
    // MARK: - Fat Binary Parsing
    
    private func parseFatBinary(data: Data) throws -> [BinaryInfo.Architecture] {
        var architectures: [BinaryInfo.Architecture] = []
        
        // Read number of architectures
        let nfatArch = data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: 4, as: UInt32.self).bigEndian
        }
        
        // Read each architecture descriptor
        var offset = 8
        for _ in 0..<nfatArch {
            let cpuType = data.withUnsafeBytes { buffer in
                buffer.load(fromByteOffset: offset, as: Int32.self).bigEndian
            }
            
            let cpuSubtype = data.withUnsafeBytes { buffer in
                buffer.load(fromByteOffset: offset + 4, as: Int32.self).bigEndian
            }
            
            let archName = getArchitectureName(cpuType: cpuType, cpuSubtype: cpuSubtype)
            
            architectures.append(BinaryInfo.Architecture(
                name: archName,
                cpuType: String(cpuType),
                cpuSubtype: String(cpuSubtype)
            ))
            
            offset += 20 // Size of fat_arch struct
        }
        
        return architectures
    }
    
    // MARK: - Mach-O 64-bit Parsing
    
    private func parseMachO64(data: Data) throws -> (
        architecture: BinaryInfo.Architecture,
        segments: [BinaryInfo.Segment],
        hasBitcode: Bool,
        symbolsCount: Int?
    ) {
        var offset = 0
        
        // Read Mach-O header
        let magic = data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4
        
        let cpuType = data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: offset, as: Int32.self)
        }
        offset += 4
        
        let cpuSubtype = data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: offset, as: Int32.self)
        }
        offset += 4
        
        offset += 4 // filetype
        
        let ncmds = data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: offset, as: UInt32.self)
        }
        offset += 4
        
        offset += 4 // sizeofcmds
        offset += 4 // flags
        offset += 4 // reserved (64-bit only)
        
        // Parse load commands
        var segments: [BinaryInfo.Segment] = []
        var hasBitcode = false
        var symbolsCount: Int? = nil
        
        for _ in 0..<ncmds {
            guard offset + 8 <= data.count else { break }
            
            let cmd = data.withUnsafeBytes { buffer in
                buffer.load(fromByteOffset: offset, as: UInt32.self)
            }
            
            let cmdsize = data.withUnsafeBytes { buffer in
                buffer.load(fromByteOffset: offset + 4, as: UInt32.self)
            }
            
            if cmd == LC_SEGMENT_64 {
                let segment = try parseSegment64(data: data, offset: offset + 8)
                segments.append(segment)
                
                // Check for bitcode
                if segment.name == "__LLVM" {
                    hasBitcode = true
                }
            } else if cmd == LC_SYMTAB {
                symbolsCount = try parseSymbolTable(data: data, offset: offset + 8)
            }
            
            offset += Int(cmdsize)
        }
        
        let archName = getArchitectureName(cpuType: cpuType, cpuSubtype: cpuSubtype)
        let architecture = BinaryInfo.Architecture(
            name: archName,
            cpuType: String(cpuType),
            cpuSubtype: String(cpuSubtype)
        )
        
        return (architecture, segments, hasBitcode, symbolsCount)
    }
    
    private func parseSegment64(data: Data, offset: Int) throws -> BinaryInfo.Segment {
        // Read segment name (16 bytes)
        let nameData = data.subdata(in: offset..<(offset + 16))
        let name = String(data: nameData, encoding: .utf8)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces) ?? "Unknown"
        
        var off = offset + 16
        
        // Skip vmaddr (8 bytes)
        let vmSize = data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: off, as: UInt64.self)
        }
        off += 8
        off += 8 // vmsize
        
        let fileOffset = data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: off, as: UInt64.self)
        }
        off += 8
        
        let fileSize = data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: off, as: UInt64.self)
        }
        
        return BinaryInfo.Segment(
            name: name,
            size: Int64(fileSize),
            vmSize: Int64(vmSize),
            fileOffset: Int64(fileOffset)
        )
    }
    
    private func parseSymbolTable(data: Data, offset: Int) throws -> Int {
        var off = offset
        off += 4 // symoff
        
        let nsyms = data.withUnsafeBytes { buffer in
            buffer.load(fromByteOffset: off, as: UInt32.self)
        }
        
        return Int(nsyms)
    }
    
    // MARK: - Helper Methods
    
    private func getArchitectureName(cpuType: Int32, cpuSubtype: Int32) -> String {
        // CPU_TYPE constants
        let CPU_TYPE_ARM: Int32 = 12
        let CPU_TYPE_ARM64: Int32 = 0x0100000C
        let CPU_TYPE_X86_64: Int32 = 0x01000007
        
        switch cpuType {
        case CPU_TYPE_ARM64:
            return "arm64"
        case CPU_TYPE_ARM:
            return cpuSubtype == 9 ? "armv7" : "arm"
        case CPU_TYPE_X86_64:
            return "x86_64"
        default:
            return "unknown"
        }
    }
    
    // MARK: - Fallback: Parse with otool
    
    private func parseWithOtool(binaryURL: URL) throws -> [BinaryInfo.Architecture] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/otool")
        process.arguments = ["-f", binaryURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        var architectures: [BinaryInfo.Architecture] = []
        
        // Parse output for architecture names
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("architecture") {
                let parts = line.components(separatedBy: .whitespaces)
                if let archName = parts.last {
                    architectures.append(BinaryInfo.Architecture(
                        name: archName,
                        cpuType: "unknown",
                        cpuSubtype: "unknown"
                    ))
                }
            }
        }
        
        // Default to arm64 if nothing found
        if architectures.isEmpty {
            architectures.append(BinaryInfo.Architecture(
                name: "arm64",
                cpuType: "unknown",
                cpuSubtype: "unknown"
            ))
        }
        
        return architectures
    }
}