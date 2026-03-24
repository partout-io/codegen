// SPDX-FileCopyrightText: 2026 Davide De Rosa
//
// SPDX-License-Identifier: MIT

import ArgumentParser
import Foundation
import CodegenLibrary

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

    @Option(name: [.customShort("r"), .customLong("manifest-root")], help: "Root folder that contains the manifest and Sources directory (defaults to current directory).")
    var manifestRoot: String = "."

    @Option(name: .long, help: "YAML file describing the paths & entities to process.")
    var manifest: String

    @Option(
        name: .long,
        help: "Comma-separated aliases in the form AliasName:type, for example SecureData:string,UniqueID:string."
    )
    var aliases: String?

    func run() throws {
        let manifestURL = resolve(path: manifest)
        let manifest = try loadManifest(from: manifestURL.path)
        let paths = manifest.paths.map { "\(manifestRoot)/Sources/\($0)" }
        let entities = manifest.entities
        let aliases = try parseAliases(self.aliases)
        let codegen = Codegen()
        let ctx = try codegen.scan(paths: paths, entities: entities, aliases: aliases)

        let encoderInstance = encoder.makeEncoder()
        let result = try codegen.generate(encoder: encoderInstance, from: ctx)
        print(result, terminator: "")
    }

    private func resolve(path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: manifestRoot, isDirectory: true)
            .appendingPathComponent(path)
    }

    private func parseAliases(_ rawValue: String?) throws -> [String: String] {
        guard let rawValue else {
            return [:]
        }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return [:]
        }

        var aliases: [String: String] = [:]
        for entry in trimmed.split(separator: ",", omittingEmptySubsequences: false) {
            guard !entry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError("Invalid alias entry: \(entry). Expected AliasName:type.")
            }
            let parts = entry.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw ValidationError("Invalid alias entry: \(entry). Expected AliasName:type.")
            }
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let kind = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !kind.isEmpty else {
                throw ValidationError("Invalid alias entry: \(entry). Expected AliasName:type.")
            }
            aliases[name] = kind
        }
        return aliases
    }
}

private func loadManifest(from path: String) throws -> CodegenManifest {
    let contents = try String(contentsOfFile: path)
    return try CodegenManifest(yaml: contents)
}

private struct CodegenManifest: Decodable {
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

CodegenCommand.main()
