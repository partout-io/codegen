// SPDX-FileCopyrightText: 2026 Davide De Rosa
//
// SPDX-License-Identifier: MIT

@testable import CodegenLibrary
import SwiftParser
import SwiftSyntax
import Testing

@Suite("OpenAPI Encoder")
struct OpenAPIEncoderTests {
    @Test("Nested struct and discriminated enum with associated values")
    func nestedStructAndDiscriminatedEnumWithAssociatedValues() throws {
        let source = """
        struct Payment {
            let id: String
            let method: Method

            struct Receipt {
                let number: String
                let total: Double
            }

            enum Method: String {
                case card(last4: String, brand: String, receipt: Receipt)
                case cash
            }
        }
        """

        let yaml = try encodeOpenAPI(from: source)

        #expect(yaml == """
        components:
          schemas:
            Payment:
              additionalProperties: false
              properties:
                id:
                  type: string
                method:
                  "$ref": "#/components/schemas/Payment.Method"
              required:
                - id
                - method
              type: object
            Payment.Method:
              discriminator:
                mapping:
                  card: "#/components/schemas/Payment.Method.card"
                  cash: "#/components/schemas/Payment.Method.cash"
                propertyName: type
              properties:
                type:
                  type: string
              required:
                - type
              type: object
            Payment.Method.card:
              additionalProperties: false
              allOf:
                - "$ref": "#/components/schemas/Payment.Method"
              properties:
                brand:
                  type: string
                last4:
                  type: string
                receipt:
                  "$ref": "#/components/schemas/Payment.Receipt"
                type:
                  const: card
                  type: string
              required:
                - type
                - last4
                - brand
                - receipt
              type: object
            Payment.Method.cash:
              additionalProperties: false
              allOf:
                - "$ref": "#/components/schemas/Payment.Method"
              properties:
                type:
                  const: cash
                  type: string
              required:
                - type
              type: object
            Payment.Receipt:
              additionalProperties: false
              properties:
                number:
                  type: string
                total:
                  type: number
              required:
                - number
                - total
              type: object
        info:
          title: codegen
          version: 1.0.0
        openapi: 3.1.0
        paths: {}
        """)
    }

    @Test("Top-level enum with struct and optional associated values")
    func topLevelEnumWithStructAndOptionalAssociatedValues() throws {
        let source = """
        struct Envelope {
            let payload: Payload

            struct Payload {
                let message: String
            }
        }

        enum Response: String {
            case success(envelope: Envelope, retryAfter: Int?)
            case failure(code: Int, reason: String)
        }
        """

        let yaml = try encodeOpenAPI(from: source)

        #expect(yaml == """
        components:
          schemas:
            Envelope:
              additionalProperties: false
              properties:
                payload:
                  "$ref": "#/components/schemas/Envelope.Payload"
              required:
                - payload
              type: object
            Envelope.Payload:
              additionalProperties: false
              properties:
                message:
                  type: string
              required:
                - message
              type: object
            Response:
              discriminator:
                mapping:
                  failure: "#/components/schemas/Response.failure"
                  success: "#/components/schemas/Response.success"
                propertyName: type
              properties:
                type:
                  type: string
              required:
                - type
              type: object
            Response.failure:
              additionalProperties: false
              allOf:
                - "$ref": "#/components/schemas/Response"
              properties:
                code:
                  type: integer
                reason:
                  type: string
                type:
                  const: failure
                  type: string
              required:
                - type
                - code
                - reason
              type: object
            Response.success:
              additionalProperties: false
              allOf:
                - "$ref": "#/components/schemas/Response"
              properties:
                envelope:
                  "$ref": "#/components/schemas/Envelope"
                retryAfter:
                  type: integer
                type:
                  const: success
                  type: string
              required:
                - type
                - envelope
              type: object
        info:
          title: codegen
          version: 1.0.0
        openapi: 3.1.0
        paths: {}
        """)
    }

    @Test("Plain string enum inside a struct")
    func plainStringEnumInsideStruct() throws {
        let source = """
        struct Catalog {
            let kind: Kind

            enum Kind: String {
                case basic
                case premium
            }
        }
        """

        let yaml = try encodeOpenAPI(from: source)

        #expect(yaml == """
        components:
          schemas:
            Catalog:
              additionalProperties: false
              properties:
                kind:
                  "$ref": "#/components/schemas/Catalog.Kind"
              required:
                - kind
              type: object
            Catalog.Kind:
              enum:
                - basic
                - premium
              type: string
        info:
          title: codegen
          version: 1.0.0
        openapi: 3.1.0
        paths: {}
        """)
    }
}

private extension OpenAPIEncoderTests {
    func encodeOpenAPI(from source: String) throws -> String {
        let syntax = Parser.parse(source: source)
        let scanner = ModelScanner(viewMode: .all)
        scanner.walk(syntax)

        return try Codegen().generate(
            encoder: OpenAPIEncoder(),
            from: scanner.results
        )
    }
}
