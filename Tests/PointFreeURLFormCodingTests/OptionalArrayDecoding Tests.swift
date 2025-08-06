import Testing
import Foundation
@testable import PointFreeURLFormCoding

@Suite("Optional Array Decoding with bracketsWithIndices")
struct OptionalArrayDecodingTests {
    
    // MARK: - Test Models
    
    struct ModelWithOptionalArray: Codable, Equatable {
        let name: String
        let tags: [String]?
    }
    
    struct ModelWithOptionalDict: Codable, Equatable {
        let name: String
        let metadata: [String: String]?
    }
    
    struct MessageRequest: Codable, Equatable {
        let from: String
        let to: String
        let subject: String
        let text: String
        let cc: [String]?
        let bcc: [String]?
        let tags: [String]?
    }
    
    struct NestedModel: Codable, Equatable {
        struct Inner: Codable, Equatable {
            let id: Int
            let tags: [String]?
        }
        let items: [Inner]?
    }
    
    // MARK: - Test Helpers
    
    let encoder = PointFreeFormEncoder()
    let decoder = PointFreeFormDecoder(arrayParsingStrategy: .bracketsWithIndices)
    
    // MARK: - Tests
    
    @Test("Optional array with values round-trips correctly")
    func optionalArrayWithValues() throws {
        let original = ModelWithOptionalArray(
            name: "Test",
            tags: ["swift", "ios", "server"]
        )
        
        let encoded = try encoder.encode(original)
        let encodedString = String(data: encoded, encoding: .utf8)!
        
        #expect(encodedString.contains("tags[0]=swift"))
        #expect(encodedString.contains("tags[1]=ios"))
        #expect(encodedString.contains("tags[2]=server"))
        
        let decoded = try decoder.decode(ModelWithOptionalArray.self, from: encoded)
        
        #expect(decoded.tags != nil)
        #expect(decoded.tags == ["swift", "ios", "server"])
        #expect(decoded == original)
    }
    
    @Test("Optional array with nil encodes and decodes as nil")
    func optionalArrayWithNil() throws {
        let original = ModelWithOptionalArray(
            name: "Test",
            tags: nil
        )
        
        let encoded = try encoder.encode(original)
        let encodedString = String(data: encoded, encoding: .utf8)!
        
        #expect(!encodedString.contains("tags"))
        #expect(encodedString == "name=Test")
        
        let decoded = try decoder.decode(ModelWithOptionalArray.self, from: encoded)
        
        #expect(decoded.tags == nil)
        #expect(decoded == original)
    }
    
    @Test("Empty optional array becomes nil due to encoding behavior")
    func emptyOptionalArray() throws {
        let original = ModelWithOptionalArray(
            name: "Test",
            tags: []
        )
        
        let encoded = try encoder.encode(original)
        let encodedString = String(data: encoded, encoding: .utf8)!
        
        // Empty array is not encoded (same as nil)
        #expect(!encodedString.contains("tags"))
        
        let decoded = try decoder.decode(ModelWithOptionalArray.self, from: encoded)
        
        // Empty array becomes nil (limitation of form encoding)
        #expect(decoded.tags == nil)
    }
    
    @Test("Mailgun-style message request with optional arrays")
    func mailgunMessageRequest() throws {
        let original = MessageRequest(
            from: "sender@example.com",
            to: "recipient@example.com",
            subject: "Test Subject",
            text: "Test message body",
            cc: ["cc@test.com"],
            bcc: ["bcc@test.com"],
            tags: ["test-tag", "important", "newsletter"]
        )
        
        let encoded = try encoder.encode(original)
        let encodedString = String(data: encoded, encoding: .utf8)!
        
        #expect(encodedString.contains("cc[0]=cc%40test.com"))
        #expect(encodedString.contains("bcc[0]=bcc%40test.com"))
        #expect(encodedString.contains("tags[0]=test-tag"))
        #expect(encodedString.contains("tags[1]=important"))
        #expect(encodedString.contains("tags[2]=newsletter"))
        
        let decoded = try decoder.decode(MessageRequest.self, from: encoded)
        
        #expect(decoded.cc == ["cc@test.com"])
        #expect(decoded.bcc == ["bcc@test.com"])
        #expect(decoded.tags == ["test-tag", "important", "newsletter"])
        #expect(decoded == original)
    }
    
    @Test("Optional dictionary with values round-trips correctly")
    func optionalDictionaryWithValues() throws {
        let original = ModelWithOptionalDict(
            name: "Test",
            metadata: ["key1": "value1", "key2": "value2"]
        )
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(ModelWithOptionalDict.self, from: encoded)
        
        #expect(decoded.metadata != nil)
        #expect(decoded.metadata == ["key1": "value1", "key2": "value2"])
        #expect(decoded == original)
    }
    
    @Test("Nested optional arrays decode correctly")
    func nestedOptionalArrays() throws {
        let original = NestedModel(
            items: [
                NestedModel.Inner(id: 1, tags: ["swift", "ios"]),
                NestedModel.Inner(id: 2, tags: ["web", "react"]),
                NestedModel.Inner(id: 3, tags: nil)
            ]
        )
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(NestedModel.self, from: encoded)
        
        #expect(decoded.items != nil)
        #expect(decoded.items?.count == 3)
        #expect(decoded.items?[0].tags == ["swift", "ios"])
        #expect(decoded.items?[1].tags == ["web", "react"])
        #expect(decoded.items?[2].tags == nil)
        #expect(decoded == original)
    }
    
    @Test("Decoding manually crafted form data with bracket indices")
    func manuallyCreatedFormData() throws {
        // Test decoding data that wasn't created by our encoder
        let formData = "name=Manual&tags[0]=first&tags[1]=second&tags[2]=third"
        let data = formData.data(using: .utf8)!
        
        let decoded = try decoder.decode(ModelWithOptionalArray.self, from: data)
        
        #expect(decoded.name == "Manual")
        #expect(decoded.tags == ["first", "second", "third"])
    }
    
    @Test("Decoding out-of-order bracket indices")
    func outOfOrderIndices() throws {
        // bracketsWithIndices should handle out-of-order indices
        let formData = "name=Unordered&tags[2]=third&tags[0]=first&tags[1]=second"
        let data = formData.data(using: .utf8)!
        
        let decoded = try decoder.decode(ModelWithOptionalArray.self, from: data)
        
        #expect(decoded.name == "Unordered")
        // Should be ordered by index, not by appearance
        #expect(decoded.tags == ["first", "second", "third"])
    }
    
    @Test("Mixed optional and non-optional fields")
    func mixedOptionalFields() throws {
        struct MixedModel: Codable, Equatable {
            let required: [String]  // Non-optional array
            let optional: [String]? // Optional array
        }
        
        // Test with both present
        let original1 = MixedModel(
            required: ["r1", "r2"],
            optional: ["o1", "o2"]
        )
        
        let encoded1 = try encoder.encode(original1)
        let decoded1 = try decoder.decode(MixedModel.self, from: encoded1)
        
        #expect(decoded1.required == ["r1", "r2"])
        #expect(decoded1.optional == ["o1", "o2"])
        #expect(decoded1 == original1)
        
        // Test with optional as nil
        let original2 = MixedModel(
            required: ["r1", "r2"],
            optional: nil
        )
        
        let encoded2 = try encoder.encode(original2)
        let decoded2 = try decoder.decode(MixedModel.self, from: encoded2)
        
        #expect(decoded2.required == ["r1", "r2"])
        #expect(decoded2.optional == nil)
        #expect(decoded2 == original2)
    }
    
    @Test("Optional array of integers")
    func optionalIntArray() throws {
        struct IntArrayModel: Codable, Equatable {
            let numbers: [Int]?
        }
        
        let original = IntArrayModel(numbers: [1, 2, 3, 42])
        
        let encoded = try encoder.encode(original)
        let encodedString = String(data: encoded, encoding: .utf8)!
        
        #expect(encodedString.contains("numbers[0]=1"))
        #expect(encodedString.contains("numbers[3]=42"))
        
        let decoded = try decoder.decode(IntArrayModel.self, from: encoded)
        
        #expect(decoded.numbers == [1, 2, 3, 42])
        #expect(decoded == original)
    }
}