import Foundation
import HuggingFace

struct ModelCatalogService {
    private let client = HubClient.default

    func searchGGUFModels(query: String) async throws -> [ModelSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let search = trimmed.isEmpty ? "gemma 4 gguf" : trimmed
        let page = try await client.listModels(
            search: search,
            sort: "downloads",
            direction: .descending,
            limit: 20,
            full: true
        )

        return page.items
            .map(makeSearchResult)
            .filter { !$0.ggufFiles.isEmpty || $0.id.localizedCaseInsensitiveContains("gguf") }
    }

    func details(for modelID: String) async throws -> ModelSearchResult {
        guard let repo = Repo.ID(rawValue: modelID) else {
            throw ModelCatalogError.invalidModelID(modelID)
        }

        let model = try await client.getModel(repo, full: true, filesMetadata: true)
        return makeSearchResult(model)
    }

    func downloadGGUF(
        modelID: String,
        filePath: String,
        progressHandler: @escaping @MainActor @Sendable (Progress) -> Void
    ) async throws -> URL {
        try await downloadGGUFFiles(
            modelID: modelID,
            filePaths: [filePath],
            progressHandler: progressHandler
        )
        return try localFileURL(modelID: modelID, filePath: filePath)
    }

    func downloadGGUFFiles(
        modelID: String,
        filePaths: [String],
        progressHandler: @escaping @MainActor @Sendable (Progress) -> Void
    ) async throws {
        guard let repo = Repo.ID(rawValue: modelID) else {
            throw ModelCatalogError.invalidModelID(modelID)
        }

        let destination = try modelDirectory(for: modelID)
        _ = try await client.downloadSnapshot(
            of: repo,
            kind: .model,
            to: destination,
            revision: "main",
            matching: filePaths,
            maxConcurrentDownloads: 2,
            progressHandler: progressHandler
        )
    }

    func localFileURL(modelID: String, filePath: String) throws -> URL {
        try modelDirectory(for: modelID).appendingPathComponent(filePath)
    }

    private func makeSearchResult(_ model: HuggingFace.Model) -> ModelSearchResult {
        let files = (model.siblings ?? [])
            .filter { $0.relativeFilename.localizedCaseInsensitiveContains(".gguf") }
            .map { GGUFFile(path: $0.relativeFilename, size: $0.size) }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

        return ModelSearchResult(
            id: model.id.rawValue,
            author: model.author,
            downloads: model.downloads,
            likes: model.likes,
            tags: model.tags ?? [],
            ggufFiles: files
        )
    }

    private func modelDirectory(for modelID: String) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let sanitized = modelID.replacingOccurrences(of: "/", with: "__")
        let directory = base
            .appendingPathComponent("TabAnywhere", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(sanitized, isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

enum ModelCatalogError: LocalizedError {
    case invalidModelID(String)

    var errorDescription: String? {
        switch self {
        case .invalidModelID(let id):
            "Invalid Hugging Face model id: \(id)"
        }
    }
}
