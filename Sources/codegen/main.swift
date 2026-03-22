// SPDX-FileCopyrightText: 2026 Davide De Rosa
//
// SPDX-License-Identifier: MIT

import ArgumentParser
import Foundation
import PartoutCodegen

struct CodegenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate IR-based codegen artifacts from Swift models."
    )

    enum Encoder: String, CaseIterable, ExpressibleByArgument {
        case openapi

        var output: Codegen.Output {
            switch self {
            case .openapi:
                .openapi
            }
        }

        func makeEncoder() -> CodegenEncoder {
            switch self {
            case .openapi:
                OpenAPIEncoder()
            }
        }
    }

    @Option(name: .long, help: "Encoder to use. Available values: \(Encoder.allCases.map { $0.rawValue }.joined(separator: ", " )). Defaults to openapi.")
    var encoder: Encoder = .openapi

    @Option(name: [.customShort("r"), .long], help: "Root folder that contains the Sources directory (defaults to current directory).")
    var root: String = "."

    @Option(name: [.customShort("o"), .long], help: "Directory where the generated file is written.")
    var output: String

    @Option(name: .long, help: "YAML file describing the paths & entities to process.")
    var manifest: String

    func run() throws {
        let manifestURL = resolve(path: manifest)
        let outputURL = URL(fileURLWithPath: output, isDirectory: true)
        let manifest = try loadManifest(from: manifestURL.path)
        let paths = manifest.paths.map { "\(root)/Sources/\($0)" }
        let entities = manifest.entities
        let codegen = Codegen()
        let ctx = try codegen.scan(paths: paths, entities: entities)

        let fm: FileManager = .default
        try fm.createDirectory(at: outputURL, withIntermediateDirectories: true)
        let encoderInstance = encoder.makeEncoder()
        let result = try codegen.generate(encoder: encoderInstance, from: ctx)
        let fileURL = outputURL
            .appendingPathComponent(encoder.output.fileName)
            .appendingPathExtension(encoder.output.fileExtension)
        try result.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func resolve(path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: root, isDirectory: true)
            .appendingPathComponent(path)
    }
}

private func loadManifest(from path: String) throws -> PartoutManifest {
    let contents = try String(contentsOfFile: path)
    return try PartoutManifest(yaml: contents)
}

private struct PartoutManifest: Decodable {
    let paths: [String]
    let entities: [String]

    init(paths: [String], entities: [String]) {
        self.paths = paths
        self.entities = entities
    }

    init(yaml: String) throws {
        enum Section {
            case paths
            case entities
        }

        var paths: [String] = []
        var entities: [String] = []
        var section: Section?

        for rawLine in yaml.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }
            if line == "paths:" {
                section = .paths
                continue
            }
            if line == "entities:" {
                section = .entities
                continue
            }
            guard line.hasPrefix("-") else {
                throw ManifestError.invalidLine(String(rawLine))
            }
            let value = line
                .dropFirst()
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            switch section {
            case .paths:
                paths.append(String(value))
            case .entities:
                entities.append(String(value))
            case .none:
                throw ManifestError.missingSection(String(rawLine))
            }
        }

        guard !paths.isEmpty || !entities.isEmpty else {
            throw ManifestError.emptyManifest
        }

        self.init(paths: paths, entities: entities)
    }
}

private enum ManifestError: Error, CustomStringConvertible {
    case emptyManifest
    case invalidLine(String)
    case missingSection(String)

    var description: String {
        switch self {
        case .emptyManifest:
            return "Manifest file does not contain any paths or entities."
        case .invalidLine(let line):
            return "Invalid manifest line: \(line)"
        case .missingSection(let line):
            return "Manifest item is missing a section header before line: \(line)"
        }
    }
}

private extension Codegen.Output {
    var fileName: String { rawValue }

    var fileExtension: String {
        switch self {
        case .openapi:
            "yaml"
        }
    }
}

CodegenCommand.main()
