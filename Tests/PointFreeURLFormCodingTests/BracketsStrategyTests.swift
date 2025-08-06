//
//  BracketsStrategyTests.swift
//  URLFormCoding Tests
//
//  Created for testing the .brackets strategy for encoding/decoding arrays
//

import Foundation
import Testing
import PointFreeURLFormCoding

@Suite("Brackets Strategy Tests")
struct BracketsStrategyEncodingTests {
    
    // MARK: - Test Models
    
    struct SimpleArrayModel: Codable, Equatable {
        let tags: [String]
    }
    
    struct MultipleArraysModel: Codable, Equatable {
        let tags: [String]
        let to: [String]
        let cc: [String]?
    }
    
    struct NumberArrayModel: Codable, Equatable {
        let numbers: [Int]
        let scores: [Double]
    }
    
    struct NestedObjectWithArrays: Codable, Equatable {
        let user: User
        
        struct User: Codable, Equatable {
            let name: String
            let emails: [String]
        }
    }
    
    struct ComplexArrayModel: Codable, Equatable {
        let items: [Item]
        
        struct Item: Codable, Equatable {
            let id: Int
            let name: String
        }
    }
    
    // MARK: - Encoding Tests
    
    @Suite("Brackets Encoding")
    struct EncodingTests {
        
        @Test("Encodes simple string array with brackets")
        func testEncodesSimpleStringArray() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            let model = SimpleArrayModel(tags: ["swift", "ios", "server"])
            let data = try encoder.encode(model)
            let queryString = String(data: data, encoding: .utf8)!
            
            // Should produce: tags[]=swift&tags[]=ios&tags[]=server
            #expect(queryString.contains("tags[]=swift"))
            #expect(queryString.contains("tags[]=ios"))
            #expect(queryString.contains("tags[]=server"))
            
            // Verify the exact format
            let components = queryString.split(separator: "&").map(String.init)
            #expect(components.count == 3)
            #expect(components.contains("tags[]=swift"))
            #expect(components.contains("tags[]=ios"))
            #expect(components.contains("tags[]=server"))
        }
        
        @Test("Encodes multiple arrays with brackets")
        func testEncodesMultipleArrays() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            let model = MultipleArraysModel(
                tags: ["swift", "ios"],
                to: ["user1@example.com", "user2@example.com"],
                cc: ["admin@example.com"]
            )
            
            let data = try encoder.encode(model)
            let queryString = String(data: data, encoding: .utf8)!
            
            // Check all arrays are encoded with brackets
            #expect(queryString.contains("tags[]="))
            #expect(queryString.contains("to[]="))
            #expect(queryString.contains("cc[]="))
            
            // Check specific values
            #expect(queryString.contains("tags[]=swift"))
            #expect(queryString.contains("tags[]=ios"))
            #expect(queryString.contains("to[]=user1"))
            #expect(queryString.contains("to[]=user2"))
            #expect(queryString.contains("cc[]=admin"))
        }
        
        @Test("Encodes empty arrays correctly")
        func testEncodesEmptyArrays() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            let model = SimpleArrayModel(tags: [])
            let data = try encoder.encode(model)
            let queryString = String(data: data, encoding: .utf8)!
            
            // Empty arrays should not appear in the query string
            #expect(queryString.isEmpty)
        }
        
        @Test("Encodes single element array with brackets")
        func testEncodesSingleElementArray() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            let model = SimpleArrayModel(tags: ["swift"])
            let data = try encoder.encode(model)
            let queryString = String(data: data, encoding: .utf8)!
            
            // Should still use brackets even for single element
            #expect(queryString == "tags[]=swift")
        }
        
        @Test("Encodes number arrays with brackets")
        func testEncodesNumberArrays() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            let model = NumberArrayModel(
                numbers: [1, 2, 3],
                scores: [95.5, 87.3, 92.0]
            )
            
            let data = try encoder.encode(model)
            let queryString = String(data: data, encoding: .utf8)!
            
            // Check integer array
            #expect(queryString.contains("numbers[]=1"))
            #expect(queryString.contains("numbers[]=2"))
            #expect(queryString.contains("numbers[]=3"))
            
            // Check double array
            #expect(queryString.contains("scores[]=95.5"))
            #expect(queryString.contains("scores[]=87.3"))
            #expect(queryString.contains("scores[]=92"))
        }
        
        @Test("Encodes nested objects with arrays using brackets")
        func testEncodesNestedObjectsWithArrays() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            let model = NestedObjectWithArrays(
                user: NestedObjectWithArrays.User(
                    name: "John",
                    emails: ["john@example.com", "john.doe@example.com"]
                )
            )
            
            let data = try encoder.encode(model)
            let queryString = String(data: data, encoding: .utf8)!
            
            // Should encode nested arrays with brackets
            #expect(queryString.contains("user[emails][]=john"))
            #expect(queryString.contains("user[emails][]=john.doe"))
            #expect(queryString.contains("user[name]=John"))
        }
    }
    
    // MARK: - Decoding Tests
    
    @Suite("Brackets Decoding")
    struct DecodingTests {
        
        @Test("Decodes simple array with brackets")
        func testDecodesSimpleArrayWithBrackets() throws {
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .brackets
            
            let queryString = "tags[]=swift&tags[]=ios&tags[]=server"
            let data = queryString.data(using: .utf8)!
            
            let model = try decoder.decode(SimpleArrayModel.self, from: data)
            
            #expect(model.tags == ["swift", "ios", "server"])
        }
        
        @Test("Decodes multiple arrays with brackets")
        func testDecodesMultipleArraysWithBrackets() throws {
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .brackets
            
            let queryString = "cc[]=admin%40example.com&tags[]=swift&tags[]=ios&to[]=user1%40example.com&to[]=user2%40example.com"
            let data = queryString.data(using: .utf8)!
            
            let model = try decoder.decode(MultipleArraysModel.self, from: data)
            
            #expect(model.tags == ["swift", "ios"])
            #expect(model.to == ["user1@example.com", "user2@example.com"])
            #expect(model.cc == ["admin@example.com"])
        }
        
        @Test("Decodes single element array with brackets")
        func testDecodesSingleElementArrayWithBrackets() throws {
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .brackets
            
            let queryString = "tags[]=swift"
            let data = queryString.data(using: .utf8)!
            
            let model = try decoder.decode(SimpleArrayModel.self, from: data)
            
            #expect(model.tags == ["swift"])
        }
        
        @Test("Decodes number arrays with brackets")
        func testDecodesNumberArraysWithBrackets() throws {
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .brackets
            
            let queryString = "numbers[]=1&numbers[]=2&numbers[]=3&scores[]=95.5&scores[]=87.3&scores[]=92"
            let data = queryString.data(using: .utf8)!
            
            let model = try decoder.decode(NumberArrayModel.self, from: data)
            
            #expect(model.numbers == [1, 2, 3])
            #expect(model.scores == [95.5, 87.3, 92.0])
        }
        
        @Test("Decodes nested objects with arrays using brackets")
        func testDecodesNestedObjectsWithArrays() throws {
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .brackets
            
            let queryString = "user[emails][]=john%40example.com&user[emails][]=john.doe%40example.com&user[name]=John"
            let data = queryString.data(using: .utf8)!
            
            let model = try decoder.decode(NestedObjectWithArrays.self, from: data)
            
            #expect(model.user.name == "John")
            #expect(model.user.emails == ["john@example.com", "john.doe@example.com"])
        }
    }
    
    // MARK: - Round-Trip Tests
    
    @Suite("Brackets Round-Trip")
    struct RoundTripTests {
        
        @Test("Simple array round-trips correctly")
        func testSimpleArrayRoundTrip() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .brackets
            
            let original = SimpleArrayModel(tags: ["swift", "ios", "server"])
            
            let encoded = try encoder.encode(original)
            let decoded = try decoder.decode(SimpleArrayModel.self, from: encoded)
            
            #expect(decoded == original)
        }
        
        @Test("Multiple arrays round-trip correctly")
        func testMultipleArraysRoundTrip() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .brackets
            
            let original = MultipleArraysModel(
                tags: ["swift", "ios", "vapor"],
                to: ["user1@example.com", "user2@example.com", "user3@example.com"],
                cc: ["admin@example.com", "manager@example.com"]
            )
            
            let encoded = try encoder.encode(original)
            let decoded = try decoder.decode(MultipleArraysModel.self, from: encoded)
            
            #expect(decoded == original)
        }
        
        @Test("Number arrays round-trip correctly")
        func testNumberArraysRoundTrip() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .brackets
            
            let original = NumberArrayModel(
                numbers: [42, 13, 7, 99],
                scores: [100.0, 98.5, 87.3, 92.1]
            )
            
            let encoded = try encoder.encode(original)
            let decoded = try decoder.decode(NumberArrayModel.self, from: encoded)
            
            #expect(decoded == original)
        }
        
        @Test("Nested objects with arrays round-trip correctly")
        func testNestedObjectsWithArraysRoundTrip() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .brackets
            
            let original = NestedObjectWithArrays(
                user: NestedObjectWithArrays.User(
                    name: "Alice",
                    emails: ["alice@example.com", "alice.wonderland@example.com", "a.wonder@example.com"]
                )
            )
            
            let encoded = try encoder.encode(original)
            let decoded = try decoder.decode(NestedObjectWithArrays.self, from: encoded)
            
            #expect(decoded == original)
        }
    }
    
    // MARK: - Compatibility Tests
    
    @Suite("Brackets Compatibility")
    struct CompatibilityTests {
        
        @Test("Decodes PHP/Rails style form data")
        func testDecodesPHPRailsStyleFormData() throws {
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .brackets
            
            // This is the format commonly used by PHP and Rails
            let queryString = "user[name]=John%20Doe&user[emails][]=john%40example.com&user[emails][]=doe%40example.com&tags[]=php&tags[]=rails&tags[]=web"
            let data = queryString.data(using: .utf8)!
            
            struct PHPStyleModel: Codable, Equatable {
                let user: User
                let tags: [String]
                
                struct User: Codable, Equatable {
                    let name: String
                    let emails: [String]
                }
            }
            
            let model = try decoder.decode(PHPStyleModel.self, from: data)
            
            #expect(model.user.name == "John Doe")
            #expect(model.user.emails == ["john@example.com", "doe@example.com"])
            #expect(model.tags == ["php", "rails", "web"])
        }
        
        @Test("Encodes in Mailgun-compatible format")
        func testEncodesMailgunCompatibleFormat() throws {
            let encoder = PointFreeFormEncoder(encodingStrategy: .brackets)
            
            struct MailgunMessage: Codable {
                let from: String
                let to: [String]
                let subject: String
                let text: String
            }
            
            let message = MailgunMessage(
                from: "sender@example.com",
                to: ["recipient1@example.com", "recipient2@example.com"],
                subject: "Test Subject",
                text: "Test message body"
            )
            
            let data = try encoder.encode(message)
            let queryString = String(data: data, encoding: .utf8)!
            
            // Verify it produces Mailgun-compatible format
            #expect(queryString.contains("to[]=recipient1"))
            #expect(queryString.contains("to[]=recipient2"))
            #expect(queryString.contains("from=sender"))
            #expect(queryString.contains("subject=Test"))
            #expect(queryString.contains("text=Test"))
        }
    }
}