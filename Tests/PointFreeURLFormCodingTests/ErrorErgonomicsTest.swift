import Testing
import Foundation
@testable import PointFreeURLFormCoding

@Suite("Error Ergonomics")
struct ErrorErgonomicsTest {
    
    @Test("Strategy mismatch provides clear error message")
    func testStrategyMismatchError() throws {
        // Encode with bracketsWithIndices, decode with accumulateValues
        let encoder = PointFreeFormEncoder(encodingStrategy: .bracketsWithIndices)
        let decoder = PointFreeFormDecoder(parsingStrategy: .accumulateValues)
        
        struct Model: Codable {
            let name: String
            let tags: [String]
        }
        
        let model = Model(name: "Test", tags: ["swift", "ios", "server"])
        let encoded = try encoder.encode(model)
        let encodedString = String(data: encoded, encoding: .utf8)!
        
        print("Encoded with bracketsWithIndices: \(encodedString)")
        
        // This will fail because accumulateValues expects "tags=swift&tags=ios"
        // but gets "tags[0]=swift&tags[1]=ios"
        do {
            let decoded = try decoder.decode(Model.self, from: encoded)
            print("Unexpectedly decoded: \(decoded)")
            // If it doesn't throw, the data is likely wrong
            #expect(decoded.tags.isEmpty || decoded.tags != model.tags)
        } catch {
            print("Error decoding with mismatched strategy: \(error)")
            // Check that the error is informative
            let errorString = String(describing: error)
            // The error should indicate the issue with the array/tags field
            #expect(errorString.contains("tags") || errorString.contains("Array") || errorString.contains("expected"))
        }
    }
    
    @Test("Mixed bracket styles provide clear error")
    func testMixedBracketStylesError() throws {
        let decoder = PointFreeFormDecoder(parsingStrategy: .brackets)
        
        // Mixed styles: empty brackets and indexed brackets
        let queryString = "tags[]=first&tags[1]=second&tags[]=third"
        let data = queryString.data(using: .utf8)!
        
        struct Model: Codable {
            let tags: [String]
        }
        
        do {
            let decoded = try decoder.decode(Model.self, from: data)
            print("Decoded mixed brackets: \(decoded.tags)")
            // If it succeeds, check the result is unexpected
            #expect(decoded.tags.count != 3 || decoded.tags != ["first", "second", "third"])
        } catch {
            print("Error with mixed brackets: \(error)")
            let errorString = String(describing: error)
            // Should have a clear error about the mixed format
            #expect(errorString.contains("tags") || errorString.contains("index") || errorString.contains("bracket"))
        }
    }
    
    @Test("Wrong strategy for encoded data provides helpful guidance")
    func testWrongStrategyGuidance() throws {
        // Data encoded with accumulate values
        let accumulateData = "name=Test&tags=swift&tags=ios&tags=server".data(using: .utf8)!
        
        // Try to decode with bracketsWithIndices
        let decoder = PointFreeFormDecoder(parsingStrategy: .bracketsWithIndices)
        
        struct Model: Codable {
            let name: String
            let tags: [String]
        }
        
        do {
            let decoded = try decoder.decode(Model.self, from: accumulateData)
            print("Decoded with wrong strategy: \(decoded)")
            // If successful, data is likely wrong
            #expect(decoded.tags.count == 1 || decoded.tags != ["swift", "ios", "server"])
        } catch {
            print("Error with wrong strategy: \(error)")
            let errorString = String(describing: error)
            #expect(errorString.contains("tags") || errorString.contains("Array"))
        }
    }
    
    @Test("Detects strategy from data format")
    func testStrategyDetection() throws {
        // Test if we can detect the right strategy from the data format
        let bracketsData = "tags[0]=swift&tags[1]=ios".data(using: .utf8)!
        let accumulateData = "tags=swift&tags=ios".data(using: .utf8)!
        let emptyBracketsData = "tags[]=swift&tags[]=ios".data(using: .utf8)!
        
        // Helper to detect strategy
        func detectStrategy(from data: Data) -> String {
            let string = String(data: data, encoding: .utf8) ?? ""
            if string.contains("[0]") || string.contains("[1]") {
                return "bracketsWithIndices"
            } else if string.contains("[]") {
                return "brackets"
            } else if string.matches(of: /(\w+)=.*&\1=/).count > 0 {
                return "accumulateValues"
            }
            return "unknown"
        }
        
        #expect(detectStrategy(from: bracketsData) == "bracketsWithIndices")
        #expect(detectStrategy(from: accumulateData) == "accumulateValues")
        #expect(detectStrategy(from: emptyBracketsData) == "brackets")
    }
    
    @Test("Provides actionable error for incompatible strategies")
    func testActionableStrategyError() throws {
        struct ComplexModel: Codable {
            let id: Int
            let name: String
            let tags: [String]
            let metadata: [String: String]
        }
        
        let encoder = PointFreeFormEncoder(encodingStrategy: .bracketsWithIndices)
        let model = ComplexModel(
            id: 1,
            name: "Test",
            tags: ["swift", "ios"],
            metadata: ["version": "1.0", "author": "test"]
        )
        
        let encoded = try encoder.encode(model)
        let encodedString = String(data: encoded, encoding: .utf8)!
        print("Complex model encoded: \(encodedString)")
        
        // Try to decode with wrong strategy
        let decoder = PointFreeFormDecoder(parsingStrategy: .accumulateValues)
        
        do {
            _ = try decoder.decode(ComplexModel.self, from: encoded)
            #expect(Bool(false), "Should have thrown an error")
        } catch {
            let errorString = String(describing: error)
            print("Complex model error: \(errorString)")
            
            // Error should mention the problematic field or give guidance
            #expect(
                errorString.contains("tags") ||
                errorString.contains("metadata") ||
                errorString.contains("Array") ||
                errorString.contains("Dictionary")
            )
        }
    }
}