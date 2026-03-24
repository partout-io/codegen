// SPDX-FileCopyrightText: 2026 Davide De Rosa
//
// SPDX-License-Identifier: MIT

@testable import CodegenLibrary
import Foundation
import Testing

@Suite("Codegen Scan")
struct CodegenScanTests {
    @Test("Accepts explicit aliases")
    func acceptsExplicitAliases() throws {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }

        let source = """
        struct Payload {
            let external: ExternalID
        }
        """
        try source.write(
            to: tempDirectory.appendingPathComponent("Payload.swift"),
            atomically: true,
            encoding: .utf8
        )

        let ctx = try Codegen().scan(
            paths: [tempDirectory.path],
            entities: ["Payload"],
            aliases: ["ExternalID": "data"]
        )

        #expect(ctx.models.contains(where: { $0.fqTypeName == "Payload" }))
        #expect(ctx.aliases.contains(where: { $0.name == "ExternalID" && isDataKind($0.kind) }))
    }
}

private func isDataKind(_ type: IRType) -> Bool {
    if case .data = type {
        return true
    }
    return false
}
