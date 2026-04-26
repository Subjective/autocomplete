import Foundation

actor LlamaServerManager {
    static let shared = LlamaServerManager()

    private let port = 18080
    private var process: Process?
    private var activeModelPath: String?
    private var activeMMProjPath: String?
    private var outputPipe: Pipe?

    func endpoint(for modelPath: String) async throws -> URL {
        let mmprojPath = Self.multimodalProjectorPath(for: modelPath)
        if process?.isRunning == true,
           activeModelPath == modelPath,
           activeMMProjPath == mmprojPath,
           await isServerReady(modelPath: modelPath, mmprojPath: mmprojPath) {
            return baseURL
        }

        stop()
        try start(modelPath: modelPath, mmprojPath: mmprojPath)
        try await waitUntilReady(modelPath: modelPath, mmprojPath: mmprojPath)
        return baseURL
    }

    nonisolated static func multimodalProjectorPath(for modelPath: String) -> String? {
        guard !modelPath.isEmpty else {
            return nil
        }

        let modelURL = URL(fileURLWithPath: modelPath)
        let directory = modelURL.deletingLastPathComponent()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        return contents.first { url in
            let name = url.lastPathComponent.lowercased()
            return name.contains("mmproj") && name.hasSuffix(".gguf")
        }?.path
    }

    func stop() {
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        activeModelPath = nil
        activeMMProjPath = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
    }

    private var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)/v1")!
    }

    private var healthURL: URL {
        URL(string: "http://127.0.0.1:\(port)/health")!
    }

    private var propsURL: URL {
        URL(string: "http://127.0.0.1:\(port)/props")!
    }

    private func start(modelPath: String, mmprojPath: String?) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LlamaServerError.missingModel(modelPath)
        }

        let executable = try llamaServerExecutableURL()
        let process = Process()
        process.executableURL = executable
        var arguments = [
            "-m", modelPath,
            "--jinja",
            "--reasoning", "off",
            "--host", "127.0.0.1",
            "--port", "\(port)",
            "-c", "4096",
            "-ngl", "999"
        ]

        if let mmprojPath {
            arguments += ["--mmproj", mmprojPath]
        }

        process.arguments = arguments

        let pipe = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        self.process = process
        self.outputPipe = pipe
        activeModelPath = modelPath
        activeMMProjPath = mmprojPath
    }

    private func llamaServerExecutableURL() throws -> URL {
        let candidates = [
            "/opt/homebrew/bin/llama-server",
            "/usr/local/bin/llama-server"
        ]

        if let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }

        throw LlamaServerError.missingExecutable
    }

    private func waitUntilReady(modelPath: String, mmprojPath: String?) async throws {
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline {
            if process?.isRunning != true {
                throw LlamaServerError.serverExited
            }

            if await isServerReady(modelPath: modelPath, mmprojPath: mmprojPath) {
                return
            }

            try await Task.sleep(nanoseconds: 350_000_000)
        }

        throw LlamaServerError.startupTimedOut
    }

    private func isServerReady(modelPath: String, mmprojPath: String?) async -> Bool {
        do {
            let (_, response) = try await URLSession.shared.data(from: healthURL)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                return false
            }

            return await serverPropertiesMatch(modelPath: modelPath, mmprojPath: mmprojPath)
        } catch {
            return false
        }
    }

    private func serverPropertiesMatch(modelPath: String, mmprojPath: String?) async -> Bool {
        do {
            let (data, response) = try await URLSession.shared.data(from: propsURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200 ..< 300).contains(httpResponse.statusCode)
            else {
                return false
            }

            let props = try JSONDecoder().decode(LlamaServerProperties.self, from: data)
            let expectedPath = URL(fileURLWithPath: modelPath).standardizedFileURL.path
            let loadedPath = URL(fileURLWithPath: props.modelPath).standardizedFileURL.path
            guard loadedPath == expectedPath else {
                return false
            }

            if mmprojPath != nil {
                return props.modalities?.vision == true
            }

            return true
        } catch {
            return false
        }
    }
}

private struct LlamaServerProperties: Decodable {
    let modelPath: String
    let modalities: Modalities?

    enum CodingKeys: String, CodingKey {
        case modelPath = "model_path"
        case modalities
    }

    struct Modalities: Decodable {
        let vision: Bool?
    }
}

enum LlamaServerError: LocalizedError {
    case missingExecutable
    case missingModel(String)
    case startupTimedOut
    case serverExited

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            "llama-server was not found. Install llama.cpp with Homebrew or add llama-server to /opt/homebrew/bin."
        case .missingModel(let path):
            "The selected GGUF model does not exist at \(path)."
        case .startupTimedOut:
            "llama-server did not become ready before the startup timeout."
        case .serverExited:
            "llama-server exited while loading the selected model."
        }
    }
}
