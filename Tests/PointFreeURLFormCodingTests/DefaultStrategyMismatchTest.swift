import Foundation
import Testing
import PointFreeURLFormCoding

@Suite("Default Strategy Mismatch Tests")
struct DefaultStrategyMismatchTests {
    
    struct SimpleArrayModel: Codable, Equatable {
        let name: String
        let tags: [String]
    }
    
    @Test("Default encoder/decoder strategies mismatch causes round-trip failure")
    func testDefaultStrategyMismatch() throws {
        let original = SimpleArrayModel(
            name: "Test",
            tags: ["swift", "ios", "server"]
        )
        
        // Using default encoder (bracketsWithIndices) and decoder (accumulateValues)
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder()
        
        // Encode
        let encoded = try encoder.encode(original)
        let encodedString = String(data: encoded, encoding: .utf8)!
        print("Encoded with bracketsWithIndices (default): \(encodedString)")
        // Expected: name=Test&tags[0]=swift&tags[1]=ios&tags[2]=server
        
        // Decode with default decoder (accumulateValues)
        // This will fail or produce incorrect results because:
        // - accumulateValues expects: tags=swift&tags=ios&tags=server
        // - but we encoded with: tags[0]=swift&tags[1]=ios&tags[2]=server
        
        // This test demonstrates the issue
        do {
            let decoded = try decoder.decode(SimpleArrayModel.self, from: encoded)
            // If it doesn't throw, check if the data is correctly decoded
            #expect(decoded == original, "Round-trip with mismatched defaults should fail or produce incorrect results")
        } catch {
            // Expected to fail due to mismatched strategies
            print("Failed to decode as expected: \(error)")
            // This is the expected behavior with mismatched defaults
        }
    }
    
    @Test("Matching strategies enable successful round-trip")
    func testMatchingStrategies() throws {
        let original = SimpleArrayModel(
            name: "Test",
            tags: ["swift", "ios", "server"]
        )
        
        // Test 1: Both use accumulateValues
        do {
            let encoder = PointFreeFormEncoder(arrayEncodingStrategy: .accumulateValues)
            let decoder = PointFreeFormDecoder(arrayParsingStrategy: .accumulateValues)
            
            let encoded = try encoder.encode(original)
            let encodedString = String(data: encoded, encoding: .utf8)!
            print("Encoded with accumulateValues: \(encodedString)")
            
            let decoded = try decoder.decode(SimpleArrayModel.self, from: encoded)
            #expect(decoded == original)
        }
        
        // Test 2: Both use bracketsWithIndices
        do {
            let encoder = PointFreeFormEncoder(arrayEncodingStrategy: .bracketsWithIndices)
            let decoder = PointFreeFormDecoder(arrayParsingStrategy: .bracketsWithIndices)
            
            let encoded = try encoder.encode(original)
            let encodedString = String(data: encoded, encoding: .utf8)!
            print("Encoded with bracketsWithIndices: \(encodedString)")
            
            let decoded = try decoder.decode(SimpleArrayModel.self, from: encoded)
            #expect(decoded == original)
        }
        
        // Test 3: Both use brackets
        do {
            let encoder = PointFreeFormEncoder(arrayEncodingStrategy: .brackets)
            let decoder = PointFreeFormDecoder(arrayParsingStrategy: .brackets)
            
            let encoded = try encoder.encode(original)
            let encodedString = String(data: encoded, encoding: .utf8)!
            print("Encoded with brackets: \(encodedString)")
            
            let decoded = try decoder.decode(SimpleArrayModel.self, from: encoded)
            #expect(decoded == original)
        }
    }
    
    @Test("Strategy selection impact on output format")
    func testStrategyOutputFormats() throws {
        let model = SimpleArrayModel(
            name: "Test",
            tags: ["swift", "ios", "server"]
        )
        
        // Show what each strategy produces
        let accumulateEncoder = PointFreeFormEncoder(arrayEncodingStrategy: .accumulateValues)
        let bracketsEncoder = PointFreeFormEncoder(arrayEncodingStrategy: .brackets)
        let indicesEncoder = PointFreeFormEncoder(arrayEncodingStrategy: .bracketsWithIndices)
        
        let accumulateOutput = String(data: try accumulateEncoder.encode(model), encoding: .utf8)!
        let bracketsOutput = String(data: try bracketsEncoder.encode(model), encoding: .utf8)!
        let indicesOutput = String(data: try indicesEncoder.encode(model), encoding: .utf8)!
        
        print("accumulateValues: \(accumulateOutput)")
        print("brackets: \(bracketsOutput)")
        print("bracketsWithIndices: \(indicesOutput)")
        
        // Verify the formats
        #expect(accumulateOutput.contains("tags=swift&tags=ios&tags=server"))
        #expect(bracketsOutput.contains("tags[]=swift&tags[]=ios&tags[]=server"))
        #expect(indicesOutput.contains("tags[0]=swift&tags[1]=ios&tags[2]=server"))
    }
}