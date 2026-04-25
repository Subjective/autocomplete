import Foundation

actor LlamaServerManager {
    static let shared = LlamaServerManager()

    private let port = 18080
    private var process: Process?
    private var activeModelPath: String?
    private var outputPipe: Pipe?

    func endpoint(for modelPath: String) async throws -> URL {
        if process?.isRunning == true, activeModelPath == modelPath, await isServerReady() {
            return baseURL
        }

        stop()
        try start(modelPath: modelPath)
        try await waitUntilReady()
        return baseURL
    }

    func stop() {
        if process?.isRunning == true {
            process?.terminate()
        }
        process = nil
        activeModelPath = nil
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
    }

    private var baseURL: URL {
        URL(string: "http://127.0.0.1:\(port)/v1")!
    }

    private var healthURL: URL {
        URL(string: "http://127.0.0.1:\(port)/health")!
    }

    private func start(modelPath: String) throws {
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw LlamaServerError.missingModel(modelPath)
        }

        let executable = try llamaServerExecutableURL()
        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "-m", modelPath,
            "--jinja",
            "--reasoning", "off",
            "--host", "127.0.0.1",
            "--port", "\(port)",
            "-c", "4096",
            "-ngl", "999"
        ]

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

    private func waitUntilReady() async throws {
        let deadline = Date().addingTimeInterval(120)
        while Date() < deadline {
            if await isServerReady() {
                return
            }

            if process?.isRunning != true {
                throw LlamaServerError.serverExited
            }

            try await Task.sleep(nanoseconds: 350_000_000)
        }

        throw LlamaServerError.startupTimedOut
    }

    private func isServerReady() async -> Bool {
        do {
            let (_, response) = try await URLSession.shared.data(from: healthURL)
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            return (200 ..< 300).contains(httpResponse.statusCode)
        } catch {
            return false
        }
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
