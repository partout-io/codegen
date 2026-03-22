# partout-codegen

A Swift tool that scans Swift source code and generates [OpenAPI 3.1.0](https://spec.openapis.org/oas/v3.1.0) specification files from your data models.

It is available both as a **CLI executable** and a **Swift library** you can embed in your own tooling.

## Features

- Parses Swift structs and enums directly from source files using [swift-syntax](https://github.com/swiftlang/swift-syntax) (no compilation required)
- Supports a rich type system: primitives, collections, optionals, `UUID`, `URL`, `Date`, `Data`, custom types, and more
- Respects `CodingKeys` for custom serialization names
- Handles nested types (e.g., `User.Address`) and discriminated-union enums
- Generates a single OpenAPI YAML document or one file per schema
- Manifest-driven: a small YAML file specifies which paths and entity names to process

## Requirements

- macOS 10.15 or later
- Swift 6.2 or later

## Installation

### As a CLI tool (Swift Package Manager)

```bash
git clone https://github.com/partout-io/codegen.git
cd codegen
swift build -c release
# The binary is at .build/release/codegen
```

### As a library dependency

Add the package to your `Package.swift`:

```swift
dependencies: [
    // Check https://github.com/partout-io/codegen/releases for the latest version tag.
    .package(url: "https://github.com/partout-io/codegen.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyTool",
        dependencies: [
            .product(name: "PartoutCodegen", package: "codegen")
        ]
    )
]
```

## Usage

### CLI

```
USAGE: codegen --output <output> --manifest <manifest> [--encoder <encoder>] [--manifest-root <manifest-root>]

OPTIONS:
  --encoder <encoder>             Encoder to use. Available values: openapi. Defaults to openapi.
  -r, --manifest-root <manifest-root>
                                  Root folder that contains the manifest and Sources directory
                                  (defaults to current directory).
  -o, --output <output>           Directory where the generated file is written.
  --manifest <manifest>           YAML file describing the paths & entities to process.
  -h, --help                      Show help information.
```

Example:

```bash
codegen \
  --encoder openapi \
  --manifest-root /path/to/project \
  --manifest codegen.yaml \
  --output /path/to/output
```

The tool writes a single file to the output directory. For the `openapi` encoder that file is `openapi.yaml`.

### Manifest file

The manifest is a YAML file with two sections:

| Key | Description |
|-----|-------------|
| `paths` | Subdirectories (relative to `<manifest-root>/Sources/`) that are scanned for `.swift` files |
| `entities` | Swift type names (fully-qualified where needed) that should appear in the output |

```yaml
paths:
  - Models
  - Networking/Responses

entities:
  - User
  - Post
  - Comment
  - Post.Attachment
```

### Library API

```swift
import PartoutCodegen

let codegen = Codegen()

// 1. Scan Swift source directories and filter to the desired entities
let context = try codegen.scan(
    paths: ["Sources/Models", "Sources/Networking/Responses"],
    entities: ["User", "Post", "Comment"]
)

// 2a. Generate a single combined document
let yaml = try codegen.generate(encoder: OpenAPIEncoder(), from: context)

// 2b. Or generate one file per schema
let files = try codegen.generateFiles(encoder: OpenAPIEncoder(), from: context)
for file in files {
    print(file.name)    // e.g. "User"
    print(file.contents)
}
```

## How it works

```
Swift source files
       │
       ▼
  ModelScanner          (swift-syntax AST visitor)
       │  extracts structs, enums, properties, CodingKeys
       ▼
  IRContext             (language-agnostic intermediate representation)
       │  IRModel, IRAlias, IRProperty, IRType, …
       ▼
  OpenAPIEncoder        (IREncoder implementation)
       │  converts IR → JSON Schema objects
       ▼
  YAML renderer         (custom human-readable output)
       │
       ▼
  openapi.yaml
```

To add a new output format implement the `IREncoder` protocol from `PartoutCodegen` and pass an instance to `Codegen.generate(encoder:from:)`.

## License

MIT – see [LICENSE](LICENSE).
