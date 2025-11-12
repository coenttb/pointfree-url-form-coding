# Swift URL Form Coding

A fork of Point-Free's swift-web/UrlFormEncoding with enhanced strategy matching and auto-detection capabilities.

[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%2014%20|%20iOS%2017-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)](LICENSE)

## Overview

PointFreeURLFormCoding provides type-safe encoding and decoding of Swift types to/from `application/x-www-form-urlencoded` format, commonly used in HTML forms and web APIs.

## Quick Start

```swift
import PointFreeURLFormCoding

struct User: Codable {
    let name: String
    let age: Int
    let tags: [String]
}

// Encoding
let encoder = PointFreeFormEncoder()
let user = User(name: "John", age: 30, tags: ["swift", "ios"])
let formData = try encoder.encode(user)
// Result: "age=30&name=John&tags[0]=swift&tags[1]=ios"

// Decoding - Recommended: Use auto-detection
let decoded = try PointFreeFormDecoder.decodeWithAutoDetection(User.self, from: formData)
```

## Critical: Strategy Matching

**⚠️ IMPORTANT:** Encoder and decoder strategies must match for arrays to round-trip correctly.

### The Default Strategy Mismatch Problem

By default:
- `PointFreeFormEncoder` uses `.accumulateValues` for arrays
- `PointFreeFormDecoder` uses `.accumulateValues` for arrays

However, when working with arrays, strategy mismatches cause decoding failures:

```swift
// INCORRECT: This will fail or produce wrong results
let encoder = PointFreeFormEncoder(arrayEncodingStrategy: .bracketsWithIndices)
let decoder = PointFreeFormDecoder(arrayParsingStrategy: .accumulateValues) // Mismatch!

let data = try encoder.encode(model)
let decoded = try decoder.decode(Model.self, from: data) // Fails or wrong data
```

```swift
// CORRECT: Strategies match
let encoder = PointFreeFormEncoder(arrayEncodingStrategy: .bracketsWithIndices)
let decoder = PointFreeFormDecoder(arrayParsingStrategy: .bracketsWithIndices) // Match!

let data = try encoder.encode(model)
let decoded = try decoder.decode(Model.self, from: data) // Success!
```

### Solution: Auto-Detection (Recommended)

The safest approach is to use auto-detection when decoding:

```swift
// Automatically detects the correct strategy from the encoded data
let decoded = try PointFreeFormDecoder.decodeWithAutoDetection(User.self, from: formData)
```

This works regardless of which encoding strategy was used:

```swift
// All of these work with auto-detection
let encoder1 = PointFreeFormEncoder(arrayEncodingStrategy: .accumulateValues)
let encoder2 = PointFreeFormEncoder(arrayEncodingStrategy: .brackets)
let encoder3 = PointFreeFormEncoder(arrayEncodingStrategy: .bracketsWithIndices)

let data1 = try encoder1.encode(user)
let data2 = try encoder2.encode(user)
let data3 = try encoder3.encode(user)

// All decode correctly with auto-detection
let user1 = try PointFreeFormDecoder.decodeWithAutoDetection(User.self, from: data1)
let user2 = try PointFreeFormDecoder.decodeWithAutoDetection(User.self, from: data2)
let user3 = try PointFreeFormDecoder.decodeWithAutoDetection(User.self, from: data3)
```

## Array Encoding Strategies

### Strategy Comparison Table

| Strategy | Encoder Format | Decoder Expectation | Use Case |
|----------|---------------|---------------------|----------|
| `.accumulateValues` | `tags=swift&tags=ios` | Same key repeated | Simple forms, query strings |
| `.brackets` | `tags[]=swift&tags[]=ios` | Empty bracket notation | PHP/Rails-style arrays |
| `.bracketsWithIndices` | `tags[0]=swift&tags[1]=ios` | Indexed brackets | Ordered arrays, complex nested data |

### Format Examples

```swift
let model = Model(name: "Test", tags: ["swift", "ios", "server"])

// accumulateValues
let enc1 = PointFreeFormEncoder(arrayEncodingStrategy: .accumulateValues)
try enc1.encode(model)
// Output: "name=Test&tags=swift&tags=ios&tags=server"

// brackets
let enc2 = PointFreeFormEncoder(arrayEncodingStrategy: .brackets)
try enc2.encode(model)
// Output: "name=Test&tags[]=swift&tags[]=ios&tags[]=server"

// bracketsWithIndices
let enc3 = PointFreeFormEncoder(arrayEncodingStrategy: .bracketsWithIndices)
try enc3.encode(model)
// Output: "name=Test&tags[0]=swift&tags[1]=ios&tags[2]=server"
```

## Common Use Cases

### API Request with Form Data

```swift
struct LoginRequest: Codable {
    let username: String
    let password: String
    let rememberMe: Bool
}

let request = LoginRequest(username: "user@example.com", password: "secret", rememberMe: true)
let encoder = PointFreeFormEncoder()
let formData = try encoder.encode(request)

var urlRequest = URLRequest(url: URL(string: "https://api.example.com/login")!)
urlRequest.httpMethod = "POST"
urlRequest.httpBody = formData
urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
```

### Decoding Server Response

```swift
// Response from server: "id=123&username=john&tags[0]=admin&tags[1]=user"
let responseData = responseBody.data(using: .utf8)!

struct UserResponse: Codable {
    let id: Int
    let username: String
    let tags: [String]
}

// Auto-detection handles any encoding strategy the server used
let user = try PointFreeFormDecoder.decodeWithAutoDetection(UserResponse.self, from: responseData)
print("User: \(user.username), Tags: \(user.tags)")
```

### Working with Query Parameters

```swift
struct SearchQuery: Codable {
    let query: String
    let filters: [String]
    let page: Int
}

let search = SearchQuery(query: "swift", filters: ["tutorial", "beginner"], page: 1)
let encoder = PointFreeFormEncoder(arrayEncodingStrategy: .accumulateValues)
let queryData = try encoder.encode(search)
let queryString = String(data: queryData, encoding: .utf8)!
// Result: "filters=tutorial&filters=beginner&page=1&query=swift"

let url = URL(string: "https://example.com/search?\(queryString)")!
```

## Advanced Configuration

### Date Encoding/Decoding

```swift
let encoder = PointFreeFormEncoder()
encoder.dateEncodingStrategy = .iso8601 // or .secondsSince1970, .millisecondsSince1970

let decoder = PointFreeFormDecoder()
decoder.dateDecodingStrategy = .iso8601
```

### Data Encoding/Decoding

```swift
let encoder = PointFreeFormEncoder()
encoder.dataEncodingStrategy = .base64

let decoder = PointFreeFormDecoder()
decoder.dataDecodingStrategy = .base64
```

### Manual Strategy Configuration

When you control both encoding and decoding (e.g., in tests):

```swift
// Configure both with matching strategies
let encoder = PointFreeFormEncoder(
    dataEncodingStrategy: .base64,
    dateEncodingStrategy: .iso8601,
    arrayEncodingStrategy: .bracketsWithIndices
)

let decoder = PointFreeFormDecoder(
    dataDecodingStrategy: .base64,
    dateDecodingStrategy: .iso8601,
    arrayParsingStrategy: .bracketsWithIndices // Must match encoder!
)
```

## Troubleshooting

### Empty Arrays Not Encoding

**Known Limitation:** Empty arrays are not included in the encoded output for any strategy. This is because the URL form encoding format has no standard way to represent an empty array.

```swift
struct Model: Codable {
    let tags: [String]
}

let model = Model(tags: []) // Empty array
let encoded = try encoder.encode(model)
// Result: "" (no output for tags)

// When decoded, the field will be absent or default to empty array depending on your Codable implementation
```

**Workaround:** If you need to distinguish between "no tags" and "empty tags array", consider using an Optional:

```swift
struct Model: Codable {
    let tags: [String]? // nil = not specified, [] = explicitly empty
}
```

### Decoder Failing with Strategy Mismatch

**Symptom:** Decoding throws errors or produces incorrect data, especially with arrays.

**Solution:** Use auto-detection or ensure strategies match:

```swift
// Option 1: Auto-detection (recommended)
let decoded = try PointFreeFormDecoder.decodeWithAutoDetection(Model.self, from: data)

// Option 2: Manual matching
let decoder = PointFreeFormDecoder(arrayParsingStrategy: .bracketsWithIndices)
// Make sure encoder also used .bracketsWithIndices
```

### Debugging Strategy Issues

Check what strategy was used during encoding:

```swift
let data = try encoder.encode(model)
let str = String(data: data, encoding: .utf8)!
print("Encoded form: \(str)")

// Inspect the output format:
// - Contains [0], [1], [2]? → bracketsWithIndices
// - Contains []? → brackets
// - Repeated keys (tags=a&tags=b)? → accumulateValues
```

## Requirements

- **Swift**: 5.9+ (Full Swift 6 support)
- **Dependencies**: None (pure Swift implementation)

## Related Packages

### Used By

- [swift-url-form-coding](https://github.com/coenttb/swift-url-form-coding): A Swift package for type-safe web form encoding and decoding.

## Related Projects

### Fork

* [pointfreeco/swift-web](https://github.com/pointfreeco/swift-web): Original source for PointFreeFormDecoder and PointFreeFormEncoder

## Acknowledgements

This project is a fork of the foundational work by Point-Free (Brandon Williams and Stephen Celis). This package's PointFreeFormEncoder and PointFreeFormDecoder are copied from their [swift-web](https://github.com/pointfreeco/swift-web) library.

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.
