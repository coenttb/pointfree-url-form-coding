//
//  URLFormCoding Tests.swift
//  swift-url-form-coding
//
//  Created by Coen ten Thije Boonkkamp on 05/08/2025.
//

import Foundation
import Testing
import PointFreeURLFormCoding

@Suite("URLFormCoding Round-Trip Tests")
struct URLFormCodingRoundTripTests {
    
    // MARK: - Test Models
    
    struct MessageRequest: Codable, Equatable {
        let from: String
        let to: [String]
        let subject: String
        let text: String
        let html: String?
        let cc: [String]?
        let bcc: [String]?
        let tags: [String]?
        let testMode: Bool?
    }
    
    struct SimpleArrayModel: Codable, Equatable {
        let name: String
        let tags: [String]
    }
    
    struct OptionalArrayModel: Codable, Equatable {
        let name: String
        let tags: [String]?
    }
    
    struct MixedTypesModel: Codable, Equatable {
        let name: String
        let age: Int
        let tags: [String]?
        let scores: [Int]?
        let isActive: Bool?
        let metadata: [String: String]?
    }
    
    // MARK: - Basic Round-Trip Tests
    
    @Test("Basic array round-trip with accumulate values (default)")
    func testBasicArrayRoundTripWithAccumulateValues() throws {
        let encoder = PointFreeFormEncoder(
            encodingStrategy: .accumulateValues
        )
        let decoder = PointFreeFormDecoder(
            parsingStrategy: .accumulateValues
        )
        
        let original = SimpleArrayModel(
            name: "Test",
            tags: ["swift", "ios", "server"]
        )
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(SimpleArrayModel.self, from: encoded)
        
        #expect(decoded == original)
    }
    
    @Test("Optional array round-trip with bracketsWithIndices")
    func testOptionalArrayRoundTripWithBracketsWithIndices() throws {
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(
            parsingStrategy: .bracketsWithIndices
        )
        
        let original = OptionalArrayModel(
            name: "Test",
            tags: ["swift", "ios", "server"]
        )
        
        let encoded = try encoder.encode(original)
        let encodedString = String(data: encoded, encoding: .utf8)!
        print("Encoded: \(encodedString)")
        
        let decoded = try decoder.decode(OptionalArrayModel.self, from: encoded)
        
        #expect(decoded == original)
    }
    
    @Test("Message request round-trip with bracketsWithIndices (Mailgun scenario)")
    func testMessageRequestRoundTripWithBracketsWithIndices() throws {
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(
            parsingStrategy: .bracketsWithIndices
        )
        
        let original = MessageRequest(
            from: "sender@test.com",
            to: ["recipient@test.com"],
            subject: "Test Subject",
            text: "Test content",
            html: "<p>Test content</p>",
            cc: ["cc@test.com"],
            bcc: ["bcc@test.com"],
            tags: ["test-tag"],
            testMode: true
        )
        
        let encoded = try encoder.encode(original)
        let encodedString = String(data: encoded, encoding: .utf8)!
        print("Encoded message request: \(encodedString)")
        
        let decoded = try decoder.decode(MessageRequest.self, from: encoded)
        
        #expect(decoded.from == original.from)
        #expect(decoded.to == original.to)
        #expect(decoded.subject == original.subject)
        #expect(decoded.text == original.text)
        #expect(decoded.html == original.html)
        #expect(decoded.cc == original.cc)
        #expect(decoded.bcc == original.bcc)
        #expect(decoded.tags == original.tags)
        #expect(decoded.testMode == original.testMode)
        #expect(decoded == original)
    }
    
    @Test("Empty arrays round-trip")
    func testEmptyArraysRoundTrip() throws {
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(
            parsingStrategy: .bracketsWithIndices
        )
        
        let original = OptionalArrayModel(
            name: "Test",
            tags: []
        )
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(OptionalArrayModel.self, from: encoded)
        
        // Empty arrays become nil in form encoding (this is a known limitation)
        // There's no way to distinguish between empty array and nil in URL form data
        #expect(decoded.name == original.name)
        #expect(decoded.tags == nil)  // Empty array becomes nil
    }
    
    @Test("Nil arrays round-trip")
    func testNilArraysRoundTrip() throws {
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(
            parsingStrategy: .bracketsWithIndices
        )
        
        let original = OptionalArrayModel(
            name: "Test",
            tags: nil
        )
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(OptionalArrayModel.self, from: encoded)
        
        #expect(decoded == original)
    }
    
    @Test("Mixed types with optional arrays round-trip")
    func testMixedTypesRoundTrip() throws {
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(
            parsingStrategy: .bracketsWithIndices
        )
        
        let original = MixedTypesModel(
            name: "Test User",
            age: 30,
            tags: ["swift", "ios"],
            scores: [100, 95, 88],
            isActive: true,
            metadata: ["key1": "value1", "key2": "value2"]
        )
        
        let encoded = try encoder.encode(original)
        let encodedString = String(data: encoded, encoding: .utf8)!
        print("Encoded mixed types: \(encodedString)")
        
        let decoded = try decoder.decode(MixedTypesModel.self, from: encoded)
        
        #expect(decoded == original)
    }
    
    @Test("Mixed types with nil optionals round-trip")
    func testMixedTypesWithNilsRoundTrip() throws {
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(
            parsingStrategy: .bracketsWithIndices
        )
        
        let original = MixedTypesModel(
            name: "Test User",
            age: 30,
            tags: nil,
            scores: nil,
            isActive: nil,
            metadata: nil
        )
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(MixedTypesModel.self, from: encoded)
        
        #expect(decoded == original)
    }
    
    // MARK: - Strategy Mismatch Tests
    
    @Test("Arrays fail with mismatched strategies")
    func testArraysFailWithMismatchedStrategies() throws {
        let encoder = PointFreeFormEncoder()
        // Using default decoder (accumulateValues) when encoder produces bracketed indices
        let decoder = PointFreeFormDecoder()
        
        let original = OptionalArrayModel(
            name: "Test",
            tags: ["swift", "ios", "server"]
        )
        
        let encoded = try encoder.encode(original)
        
        // This should fail or produce incorrect results
        // because the default decoder expects repeated keys, not bracketed indices
        do {
            let decoded = try decoder.decode(OptionalArrayModel.self, from: encoded)
            // If it doesn't throw, check if the data is incorrect
            #expect(decoded != original || decoded.tags == nil || decoded.tags?.isEmpty == true)
        } catch {
            // Expected to fail
            #expect(error != nil)
        }
    }
    
    // MARK: - Date Strategy Tests
    
    @Test("Round-trip with custom date strategies")
    func testRoundTripWithDateStrategies() throws {
        struct ModelWithDate: Codable, Equatable {
            let name: String
            let createdAt: Date
            let tags: [String]?
        }
        
        let encoder = PointFreeFormEncoder(
            dateEncodingStrategy: .secondsSince1970
        )
        let decoder = PointFreeFormDecoder(
            dateDecodingStrategy: .secondsSince1970,
            parsingStrategy: .bracketsWithIndices
        )
        
        let date = Date(timeIntervalSince1970: 1234567890)
        let original = ModelWithDate(
            name: "Test",
            createdAt: date,
            tags: ["tag1", "tag2"]
        )
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(ModelWithDate.self, from: encoded)
        
        #expect(decoded == original)
    }
    
    // MARK: - Complex Nested Structure Tests
    
    @Test("Complex nested structure round-trip")
    func testComplexNestedStructureRoundTrip() throws {
        struct NestedModel: Codable, Equatable {
            struct Inner: Codable, Equatable {
                let id: Int
                let tags: [String]?
            }
            let name: String
            let items: [Inner]?
        }
        
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(
            parsingStrategy: .bracketsWithIndices
        )
        
        let original = NestedModel(
            name: "Parent",
            items: [
                NestedModel.Inner(id: 1, tags: ["a", "b"]),
                NestedModel.Inner(id: 2, tags: ["c", "d"]),
                NestedModel.Inner(id: 3, tags: nil)
            ]
        )
        
        let encoded = try encoder.encode(original)
        let encodedString = String(data: encoded, encoding: .utf8)!
        print("Encoded nested structure: \(encodedString)")
        
        let decoded = try decoder.decode(NestedModel.self, from: encoded)
        
        #expect(decoded == original)
    }
}
