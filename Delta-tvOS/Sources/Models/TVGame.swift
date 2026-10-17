import Foundation
import DeltaCore

struct TVGame: Identifiable, Hashable {
    let id: UUID
    let name: String
    let internalTitle: String?
    let fileURL: URL
    let system: TVSystem
    let fileSize: Int64
    
    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var deltaGame: Game {
        Game(fileURL: fileURL, type: system.gameType)
    }
    
    init(fileURL: URL, system: TVSystem) {
        self.id = UUID()
        self.fileURL = fileURL
        self.system = system
        
        // Calculate file size
        let resources = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        self.fileSize = Int64(resources?.fileSize ?? 0)
        
        let filename = fileURL.lastPathComponent
        let cleaned = TVGame.cleanTitle(from: filename)
        
        let internalName = TVGame.extractInternalROMName(fileURL: fileURL, system: system)
        self.internalTitle = internalName
        
        // Priority: Cleaned filename is usually the most readable for human releases,
        // but internal title is great confirmation.
        if !cleaned.isEmpty {
            self.name = cleaned
        } else if let internalName = internalName, !internalName.isEmpty {
            self.name = internalName
        } else {
            self.name = fileURL.deletingPathExtension().lastPathComponent
        }
    }
    
    static func cleanTitle(from filename: String) -> String {
        var name = (filename as NSString).deletingPathExtension
        let patterns = [
            "\\s*\\([^\\)]*\\)",
            "\\s*\\[[^\\]]*\\]"
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                name = regex.stringByReplacingMatches(in: name, options: [], range: NSRange(location: 0, length: name.utf16.count), withTemplate: "")
            }
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    static func extractInternalROMName(fileURL: URL, system: TVSystem) -> String? {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else { return nil }
        defer { try? fileHandle.close() }
        
        switch system {
        case .n64:
            // N64 header: title is at offset 0x20 (32 bytes), 20 bytes long
            fileHandle.seek(toFileOffset: 0x20)
            let data = fileHandle.readData(ofLength: 20)
            if data.count == 20,
               let title = String(data: data, encoding: .ascii)?
                .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0"))),
               !title.isEmpty,
               title.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0.isWhitespace || $0.isPunctuation) }) {
                return title
            }
        case .snes:
            let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let smcOffset = (fileSize % 1024 == 512) ? 512 : 0
            let possibleOffsets: [UInt64] = [UInt64(smcOffset + 0x7FC0), UInt64(smcOffset + 0xFFC0)]
            for offset in possibleOffsets {
                if fileSize > Int(offset) + 21 {
                    fileHandle.seek(toFileOffset: offset)
                    let data = fileHandle.readData(ofLength: 21)
                    if let title = String(data: data, encoding: .ascii)?
                        .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\0"))),
                       title.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0.isWhitespace || $0.isPunctuation) }),
                       !title.isEmpty {
                        return title
                    }
                }
            }
        case .nes:
            break
        }
        return nil
    }
}
