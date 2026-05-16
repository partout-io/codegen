// SPDX-FileCopyrightText: 2026 Davide De Rosa
//
// SPDX-License-Identifier: MIT

import Foundation
import SwiftParser

public protocol CodegenEncoder {}

// Rough way to imply CodegenEncoder from IREncoder conformance
extension OpenAPIEncoder: CodegenEncoder, IREncoder {}

public final class Codegen {
    public enum Output: String, CaseIterable {
        case openapi
    }

    public struct File {
        public let name: String
        public let contents: String
    }

    public init() {}

    public func scan(
        paths: [String],
        entities: [String],
        aliases: [String: String] = [:]
    ) throws -> IRContext {
        var ctx = try Self.scanDirectories(paths: paths)
        // Inject a few hardcoded ones
        let injectedAliases = try Self.injectedAliases(from: aliases)
        let injectedAliasNames = Set(injectedAliases.map(\.fqTypeName))
        ctx.aliases = ctx.aliases.filter {
            entities.contains($0.fqTypeName) && !injectedAliasNames.contains($0.fqTypeName)
        }
        ctx.aliases.append(contentsOf: [
            IRAlias(name: "Int8", kind: .int, parents: []),
            IRAlias(name: "Int16", kind: .int, parents: []),
            IRAlias(name: "Int32", kind: .int, parents: []),
            IRAlias(name: "Int64", kind: .int, parents: []),
            IRAlias(name: "UInt", kind: .int, parents: []),
            IRAlias(name: "UInt8", kind: .int, parents: []),
            IRAlias(name: "UInt16", kind: .int, parents: []),
            IRAlias(name: "UInt32", kind: .int, parents: []),
            IRAlias(name: "UInt64", kind: .int, parents: [])
        ])
        ctx.aliases.append(contentsOf: injectedAliases)
        let aliasesNames = ctx.aliases.map(\.fqTypeName)
        ctx.models = ctx.models.filter {
            entities.contains($0.fqTypeName) && !aliasesNames.contains($0.fqTypeName)
        }
        // Make sure that all entities exist in the output
        var undefinedEntities = Set(entities)
        for model in ctx.models {
            guard !ctx.aliases.contains(where: { $0.name == model.name }) else { continue }
            undefinedEntities.remove(model.fqTypeName)
        }
        for alias in ctx.aliases {
            undefinedEntities.remove(alias.fqTypeName)
        }
        assert(undefinedEntities.isEmpty, "Undefined entities: \(undefinedEntities)")
        return ctx
    }

    public func generate(encoder: CodegenEncoder, from ctx: IRContext) throws -> String {
        guard let encoder = encoder as? IREncoder else {
            fatalError("\(encoder) is not a IREncoder")
        }
        if let document = encoder.encodeDocument(ctx: ctx) {
            return renderedContents(body: document, preamble: encoder.encodePreamble())
        }
        var lines: [String] = []
        if let preamble = encoder.encodePreamble() {
            lines.append(preamble)
            lines.append("")
        }
        for model in ctx.models {
            guard !ctx.aliases.contains(where: { $0.name == model.name }) else { continue }
            lines.append(encoder.encode(model, ctx: ctx))
            lines.append("")
        }
        for alias in ctx.aliases {
            lines.append(encoder.encode(alias, ctx: ctx))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    public func generateFiles(encoder: CodegenEncoder, from ctx: IRContext) throws -> [File] {
        guard let encoder = encoder as? IREncoder else {
            fatalError("\(encoder) is not a IREncoder")
        }
        var files: [File] = []
        for model in ctx.models {
            guard !ctx.aliases.contains(where: { $0.name == model.name }) else { continue }
            files.append(File(
                name: model.fqTypeName,
                contents: renderedContents(
                    body: encoder.encode(model, ctx: ctx),
                    preamble: encoder.encodePreamble()
                )
            ))
        }
        for alias in ctx.aliases {
            files.append(File(
                name: alias.fqTypeName,
                contents: renderedContents(
                    body: encoder.encode(alias, ctx: ctx),
                    preamble: encoder.encodePreamble()
                )
            ))
        }
        return files
    }
}

private extension Codegen {
    func renderedContents(body: String, preamble: String?) -> String {
        guard let preamble else {
            return body
        }
        return "\(preamble)\n\n\(body)"
    }

    static func scanDirectories(paths: [String]) throws -> IRContext {
        let fm: FileManager = .default
        var result = IRContext()
        for path in paths {
            let url = URL(fileURLWithPath: path)
            let files = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil
            )
            for file in files where file.pathExtension == "swift" {
                let partial = try scanFile(path: file.path)
                result.merge(partial)
            }
        }
        return result
    }

    static func scanFile(path: String) throws -> IRContext {
        let url = URL(fileURLWithPath: path)
        let source = try Parser.parse(source: String(contentsOf: url))
        let scanner = ModelScanner(viewMode: .all)
        scanner.walk(source)
        return scanner.results
    }

    static func injectedAliases(from aliases: [String: String]) throws -> [IRAlias] {
        var resolvedAliases: [String: IRType] = [:]
        for alias in aliases {
            resolvedAliases[alias.key] = try parseAliasKind(alias.value)
        }
        var result: [IRAlias] = []
        for aliasName in resolvedAliases.keys.sorted() {
            guard let kind = resolvedAliases[aliasName] else { continue }
            result.append(IRAlias(name: aliasName, kind: kind, parents: []))
        }
        return result
    }

    static func parseAliasKind(_ rawValue: String) throws -> IRType {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "string":
            return .string
        case "int", "integer":
            return .int
        case "double", "number", "timeinterval":
            return .double
        case "bool", "boolean":
            return .bool
        case "uuid":
            return .uuid
        case "url", "uri":
            return .url
        case "data", "bytes":
            return .data
        case "date":
            return .date
        case "json":
            return .json
        default:
            throw AliasError.unsupportedKind(rawValue)
        }
    }
}

private extension Codegen {
    enum AliasError: Error, CustomStringConvertible {
        case unsupportedKind(String)

        var description: String {
            switch self {
            case .unsupportedKind(let kind):
                return "Unsupported alias kind: \(kind)"
            }
        }
    }
}
