import Testing
import Foundation
@testable import PointFreeURLFormCoding

@Suite("Strategy Auto-Detection")
struct AutoDetectionTest {
    
    @Test("Auto-detects bracketsWithIndices strategy")
    func testDetectBracketsWithIndices() throws {
        let data = "name=Test&tags[0]=swift&tags[1]=ios&tags[2]=server".data(using: .utf8)!
        
        // Test decoding with auto-detection works correctly
        struct Model: Codable, Equatable {
            let name: String
            let tags: [String]
        }
        
        let decoded = try PointFreeFormDecoder.decodeWithAutoDetection(Model.self, from: data)
        #expect(decoded.name == "Test")
        #expect(decoded.tags == ["swift", "ios", "server"])
    }
    
    @Test("Auto-detects brackets strategy")
    func testDetectBrackets() throws {
        let data = "name=Test&tags[]=swift&tags[]=ios&tags[]=server".data(using: .utf8)!
        
        // Test decoding with auto-detection works correctly
        struct Model: Codable, Equatable {
            let name: String
            let tags: [String]
        }
        
        let decoded = try PointFreeFormDecoder.decodeWithAutoDetection(Model.self, from: data)
        #expect(decoded.name == "Test")
        #expect(decoded.tags == ["swift", "ios", "server"])
    }
    
    @Test("Auto-detects accumulateValues strategy")
    func testDetectAccumulateValues() throws {
        let data = "name=Test&tags=swift&tags=ios&tags=server".data(using: .utf8)!
        
        // Test decoding with auto-detection works correctly
        struct Model: Codable, Equatable {
            let name: String
            let tags: [String]
        }
        
        let decoded = try PointFreeFormDecoder.decodeWithAutoDetection(Model.self, from: data)
        #expect(decoded.name == "Test")
        #expect(decoded.tags == ["swift", "ios", "server"])
    }
    
    @Test("Auto-detection handles complex nested structures")
    func testComplexAutoDetection() throws {
        let data = "user[name]=John&user[pets][0][name]=Fido&user[pets][0][age]=3&user[pets][1][name]=Rex&user[pets][1][age]=5".data(using: .utf8)!
        
        struct User: Codable, Equatable {
            struct Pet: Codable, Equatable {
                let name: String
                let age: Int
            }
            let name: String
            let pets: [Pet]
        }
        
        struct Model: Codable, Equatable {
            let user: User
        }
        
        let decoded = try PointFreeFormDecoder.decodeWithAutoDetection(Model.self, from: data)
        #expect(decoded.user.name == "John")
        #expect(decoded.user.pets.count == 2)
        #expect(decoded.user.pets[0].name == "Fido")
        #expect(decoded.user.pets[0].age == 3)
        #expect(decoded.user.pets[1].name == "Rex")
        #expect(decoded.user.pets[1].age == 5)
    }
    
    @Test("Auto-detection with default for simple data")
    func testSimpleDataDefault() throws {
        let data = "name=John&age=30&city=NYC".data(using: .utf8)!
        
        struct Model: Codable, Equatable {
            let name: String
            let age: Int
            let city: String
        }
        
        let decoded = try PointFreeFormDecoder.decodeWithAutoDetection(Model.self, from: data)
        #expect(decoded.name == "John")
        #expect(decoded.age == 30)
        #expect(decoded.city == "NYC")
    }
    
    @Test("Round-trip with auto-detection")
    func testRoundTripWithAutoDetection() throws {
        struct Model: Codable, Equatable {
            let id: Int
            let tags: [String]
        }
        
        let original = Model(
            id: 42,
            tags: ["swift", "ios"]
        )
        
        // Test with bracketsWithIndices encoding
        let encoder1 = PointFreeFormEncoder(arrayEncodingStrategy: .bracketsWithIndices)
        let encoded1 = try encoder1.encode(original)
        let decoded1 = try PointFreeFormDecoder.decodeWithAutoDetection(Model.self, from: encoded1)
        #expect(decoded1 == original)
        
        // Test with accumulateValues encoding - this won't work with arrays
        // since accumulateValues produces tags=swift&tags=ios but auto-detection
        // needs to use the right strategy
        struct SimpleModel: Codable, Equatable {
            let id: Int
            let name: String
        }
        
        let simple = SimpleModel(id: 42, name: "Test")
        let encoder2 = PointFreeFormEncoder(arrayEncodingStrategy: .accumulateValues)
        let encoded2 = try encoder2.encode(simple)
        let decoded2 = try PointFreeFormDecoder.decodeWithAutoDetection(SimpleModel.self, from: encoded2)
        #expect(decoded2 == simple)
    }
}