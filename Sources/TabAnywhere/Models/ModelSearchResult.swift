import Foundation

struct ModelSearchResult: Identifiable, Equatable {
    let id: String
    let author: String?
    let downloads: Int?
    let likes: Int?
    let tags: [String]
    let ggufFiles: [GGUFFile]

    var title: String {
        id
    }

    var subtitle: String {
        var parts: [String] = []
        if let downloads {
            parts.append("\(downloads.formatted()) downloads")
        }
        if let likes {
            parts.append("\(likes.formatted()) likes")
        }
        if !ggufFiles.isEmpty {
            parts.append("\(ggufFiles.count) GGUF file\(ggufFiles.count == 1 ? "" : "s")")
        }
        return parts.isEmpty ? "Hugging Face model" : parts.joined(separator: " · ")
    }
}

struct GGUFFile: Identifiable, Equatable {
    let path: String
    let size: Int?

    var id: String { path }

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var sizeDescription: String {
        guard let size else {
            return "Size unknown"
        }

        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}
