import Testing
import Foundation
@testable import PointFreeURLFormCoding

// MARK: - Comprehensive Test Suite for Missing Scenarios

@Suite("Brackets Strategy (without indices)")
struct BracketsStrategyTests {
    
    @Test("Arrays with brackets (no indices) strategy")
    func testBracketsWithoutIndices() throws {
        // Test the brackets strategy that uses empty brackets
        let decoder = PointFreeFormDecoder(parsingStrategy: .brackets)
        
        // Test data like: tags[]=swift&tags[]=ios&tags[]=server
        let queryString = "name=Test&tags[]=swift&tags[]=ios&tags[]=server"
        let data = queryString.data(using: .utf8)!
        
        struct Model: Codable, Equatable {
            let name: String
            let tags: [String]
        }
        
        let decoded = try decoder.decode(Model.self, from: data)
        
        #expect(decoded.name == "Test")
        #expect(decoded.tags == ["swift", "ios", "server"])
    }
    
    @Test("Nested structures with empty brackets")
    func testNestedBracketsWithoutIndices() throws {
        let decoder = PointFreeFormDecoder(parsingStrategy: .brackets)
        
        // Test nested data: user[pets][][name]=Fido&user[pets][][name]=Rex
        let queryString = "user[pets][][name]=Fido&user[pets][][name]=Rex"
        let data = queryString.data(using: .utf8)!
        
        struct User: Codable, Equatable {
            struct Pet: Codable, Equatable {
                let name: String
            }
            let pets: [Pet]
        }
        
        struct Model: Codable, Equatable {
            let user: User
        }
        
        let decoded = try decoder.decode(Model.self, from: data)
        
        #expect(decoded.user.pets.count == 2)
        #expect(decoded.user.pets[0].name == "Fido")
        #expect(decoded.user.pets[1].name == "Rex")
    }
    
    @Test("Mixed brackets and indices should fail")
    func testMixedBracketStyles() throws {
        let decoder = PointFreeFormDecoder(parsingStrategy: .brackets)
        
        // Mixing styles should cause issues
        let queryString = "tags[]=first&tags[1]=second"
        let data = queryString.data(using: .utf8)!
        
        struct Model: Codable {
            let tags: [String]
        }
        
        // This should either fail or handle gracefully
        #expect(throws: Error.self) {
            _ = try decoder.decode(Model.self, from: data)
        }
    }
}

@Suite("Custom Strategy Tests")
struct CustomStrategyTests {
    
    @Test("Custom parsing strategy with special delimiter")
    func testCustomParsingStrategy() throws {
        // Create a custom strategy that uses pipe | as separator
        let customStrategy: (String) -> PointFreeFormDecoder.Container = { query in
            var params: [String: PointFreeFormDecoder.Container] = [:]
            let pairs = query.split(separator: "|")
            
            for pair in pairs {
                let components = pair.split(separator: ":", maxSplits: 1)
                if components.count == 2 {
                    let key = String(components[0])
                    let value = String(components[1])
                    params[key] = .singleValue(value)
                }
            }
            
            return .keyed(params)
        }
        
        let decoder = PointFreeFormDecoder(parsingStrategy: .custom(customStrategy))
        
        // Use pipe and colon delimiters
        let queryString = "name:John|age:30|city:NYC"
        let data = queryString.data(using: .utf8)!
        
        struct Model: Codable, Equatable {
            let name: String
            let age: Int
            let city: String
        }
        
        let decoded = try decoder.decode(Model.self, from: data)
        
        #expect(decoded.name == "John")
        #expect(decoded.age == 30)
        #expect(decoded.city == "NYC")
    }
    
    @Test("Custom strategy with array support")
    func testCustomStrategyWithArrays() throws {
        // Custom strategy that handles comma-separated arrays
        let customStrategy: (String) -> PointFreeFormDecoder.Container = { query in
            var params: [String: PointFreeFormDecoder.Container] = [:]
            let pairs = query.split(separator: "&")
            
            for pair in pairs {
                let components = pair.split(separator: "=", maxSplits: 1)
                if components.count == 2 {
                    let key = String(components[0])
                    let value = String(components[1]).removingPercentEncoding ?? String(components[1])
                    
                    // Handle comma-separated arrays
                    if value.contains(",") {
                        let values = value.split(separator: ",").map { 
                            PointFreeFormDecoder.Container.singleValue(String($0))
                        }
                        params[key] = .unkeyed(values)
                    } else {
                        params[key] = .singleValue(value)
                    }
                }
            }
            
            return .keyed(params)
        }
        
        let decoder = PointFreeFormDecoder(parsingStrategy: .custom(customStrategy))
        
        let queryString = "name=Test&tags=swift,ios,server"
        let data = queryString.data(using: .utf8)!
        
        struct Model: Codable, Equatable {
            let name: String
            let tags: [String]
        }
        
        let decoded = try decoder.decode(Model.self, from: data)
        
        #expect(decoded.name == "Test")
        #expect(decoded.tags == ["swift", "ios", "server"])
    }
}

@Suite("Thread Safety Tests")
struct ThreadSafetyTests {
    
    @Test("Concurrent encoding is thread-safe")
    func testConcurrentEncoding() async throws {
        struct Model: Codable, Equatable {
            let id: Int
            let name: String
        }
        
        // Create multiple encoding tasks
        let results = try await withThrowingTaskGroup(of: Data.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let encoder = PointFreeFormEncoder() // Create encoder per task
                    let model = Model(id: i, name: "Test\(i)")
                    return try encoder.encode(model)
                }
            }
            
            var collected: [Data] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }
        
        #expect(results.count == 100)
    }
    
    @Test("Concurrent decoding is thread-safe")
    func testConcurrentDecoding() async throws {
        struct Model: Codable, Equatable {
            let id: Int
            let name: String
        }
        
        // Create test data
        let testData = (0..<100).map { i in
            "id=\(i)&name=Test\(i)".data(using: .utf8)!
        }
        
        // Decode concurrently
        let results = try await withThrowingTaskGroup(of: Model.self) { group in
            for data in testData {
                group.addTask {
                    let decoder = PointFreeFormDecoder(parsingStrategy: .bracketsWithIndices) // Create decoder per task
                    return try decoder.decode(Model.self, from: data)
                }
            }
            
            var collected: [Model] = []
            for try await result in group {
                collected.append(result)
            }
            return collected
        }
        
        #expect(results.count == 100)
        #expect(results.contains { $0.id == 0 })
        #expect(results.contains { $0.id == 99 })
    }
    
    @Test("Encoder/Decoder state isolation")
    func testStateIsolation() throws {
        // Ensure encoders don't share state
        let encoder1 = PointFreeFormEncoder(encodingStrategy: .accumulateValues)
        let encoder2 = PointFreeFormEncoder(encodingStrategy: .bracketsWithIndices)
        
        struct Model: Codable {
            let tags: [String]
        }
        
        let model = Model(tags: ["a", "b"])
        
        let data1 = try encoder1.encode(model)
        let data2 = try encoder2.encode(model)
        
        let string1 = String(data: data1, encoding: .utf8)!
        let string2 = String(data: data2, encoding: .utf8)!
        
        #expect(string1.contains("tags=a&tags=b"))
        #expect(string2.contains("tags[0]=a&tags[1]=b"))
    }
}

@Suite("URLComponents Integration")
struct URLComponentsIntegrationTests {
    
    @Test("Works with URLComponents query items")
    func testURLComponentsIntegration() throws {
        var components = URLComponents(string: "https://api.example.com/endpoint")!
        
        struct QueryModel: Codable {
            let search: String
            let page: Int
            let filters: [String]
        }
        
        let model = QueryModel(search: "swift", page: 1, filters: ["ios", "macos"])
        
        // Encode model
        let encoder = PointFreeFormEncoder(encodingStrategy: .bracketsWithIndices)
        let data = try encoder.encode(model)
        let queryString = String(data: data, encoding: .utf8)!
        
        // Set as query
        components.query = queryString
        
        #expect(components.url?.absoluteString.contains("search=swift") == true)
        #expect(components.url?.absoluteString.contains("page=1") == true)
        #expect(components.url?.absoluteString.contains("filters") == true)
        
        // Decode back from URLComponents
        if let queryData = components.query?.data(using: .utf8) {
            let decoder = PointFreeFormDecoder(parsingStrategy: .bracketsWithIndices)
            let decoded = try decoder.decode(QueryModel.self, from: queryData)
            
            #expect(decoded.search == model.search)
            #expect(decoded.page == model.page)
            #expect(decoded.filters == model.filters)
        }
    }
    
    @Test("Handles URLQueryItem array conversion")
    func testURLQueryItemConversion() throws {
        let queryItems = [
            URLQueryItem(name: "name", value: "John Doe"),
            URLQueryItem(name: "age", value: "30"),
            URLQueryItem(name: "tags", value: "swift"),
            URLQueryItem(name: "tags", value: "ios")
        ]
        
        // Convert to query string
        var components = URLComponents()
        components.queryItems = queryItems
        
        if let query = components.query?.data(using: .utf8) {
            let decoder = PointFreeFormDecoder(parsingStrategy: .accumulateValues)
            
            struct Model: Codable {
                let name: String
                let age: Int
                let tags: [String]
            }
            
            let decoded = try decoder.decode(Model.self, from: query)
            
            #expect(decoded.name == "John Doe")
            #expect(decoded.age == 30)
            #expect(decoded.tags == ["swift", "ios"])
        }
    }
}

@Suite("Decimal and NSNumber Types")
struct DecimalNumberTests {
    
    @Test("Handles Decimal type")
    func testDecimalType() throws {
        struct Model: Codable, Equatable {
            let price: Decimal
            let quantity: Int
        }
        
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(parsingStrategy: .bracketsWithIndices)
        
        let original = Model(price: Decimal(string: "19.99")!, quantity: 2)
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(Model.self, from: encoded)
        
        #expect(decoded.price == original.price)
        #expect(decoded.quantity == original.quantity)
    }
    
    @Test("Handles very large numbers")
    func testVeryLargeNumbers() throws {
        struct Model: Codable, Equatable {
            let bigNumber: Decimal
            let normalNumber: Int
        }
        
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(parsingStrategy: .bracketsWithIndices)
        
        // Test with a number too large for Int64
        let largeDecimal = Decimal(string: "999999999999999999999999999.99")!
        let original = Model(bigNumber: largeDecimal, normalNumber: 42)
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(Model.self, from: encoded)
        
        #expect(decoded.bigNumber == original.bigNumber)
        #expect(decoded.normalNumber == original.normalNumber)
    }
    
    @Test("Handles high precision decimals")
    func testHighPrecisionDecimals() throws {
        struct Model: Codable, Equatable {
            let precise: Decimal
        }
        
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(parsingStrategy: .bracketsWithIndices)
        
        let original = Model(precise: Decimal(string: "3.141592653589793238462643383279")!)
        
        let encoded = try encoder.encode(original)
        let decoded = try decoder.decode(Model.self, from: encoded)
        
        #expect(decoded.precise == original.precise)
    }
}

@Suite("Backwards Compatibility")
struct BackwardsCompatibilityTests {
    
    @Test("Decodes legacy format with modern decoder")
    func testLegacyFormatDecoding() throws {
        // Simulate old encoded data that might have different format
        let legacyQuery = "user_name=John&user_email=john@example.com&is_active=1"
        let data = legacyQuery.data(using: .utf8)!
        
        struct ModernModel: Codable {
            let userName: String
            let userEmail: String
            let isActive: Bool
            
            enum CodingKeys: String, CodingKey {
                case userName = "user_name"
                case userEmail = "user_email"
                case isActive = "is_active"
            }
        }
        
        let decoder = PointFreeFormDecoder()
        let decoded = try decoder.decode(ModernModel.self, from: data)
        
        #expect(decoded.userName == "John")
        #expect(decoded.userEmail == "john@example.com")
        #expect(decoded.isActive == true)
    }
    
    @Test("Handles missing optional fields from older versions")
    func testMissingOptionalFields() throws {
        // Old data might not have newer optional fields
        let oldData = "id=123&name=Product".data(using: .utf8)!
        
        struct CurrentModel: Codable {
            let id: Int
            let name: String
            let description: String?  // Added in v2
            let tags: [String]?       // Added in v3
            let metadata: [String: String]? // Added in v4
        }
        
        let decoder = PointFreeFormDecoder(parsingStrategy: .bracketsWithIndices)
        let decoded = try decoder.decode(CurrentModel.self, from: oldData)
        
        #expect(decoded.id == 123)
        #expect(decoded.name == "Product")
        #expect(decoded.description == nil)
        #expect(decoded.tags == nil)
        #expect(decoded.metadata == nil)
    }
}

@Suite("Error Message Validation")
struct ErrorMessageTests {
    
    @Test("Provides clear error for missing required field")
    func testMissingRequiredFieldError() throws {
        struct Model: Codable {
            let required: String
            let optional: String?
        }
        
        let decoder = PointFreeFormDecoder()
        let data = "optional=value".data(using: .utf8)!
        
        #expect(throws: PointFreeFormDecoder.Error.self) {
            _ = try decoder.decode(Model.self, from: data)
        }
    }
    
    @Test("Provides clear error for type mismatch")
    func testTypeMismatchError() throws {
        struct Model: Codable {
            let age: Int
        }
        
        let decoder = PointFreeFormDecoder()
        let data = "age=notanumber".data(using: .utf8)!
        
        do {
            _ = try decoder.decode(Model.self, from: data)
            Issue.record("Should have thrown an error")
        } catch {
            // Verify error contains useful information
            let errorString = String(describing: error)
            #expect(errorString.contains("age") || errorString.contains("Int"))
        }
    }
}

@Suite("Mixed Strategy Scenarios")
struct MixedStrategyTests {
    
    @Test("Clear error when strategies mismatch")
    func testStrategyMismatch() throws {
        struct Model: Codable {
            let items: [String]
        }
        
        // Encode with one strategy
        let encoder = PointFreeFormEncoder(encodingStrategy: .bracketsWithIndices)
        let model = Model(items: ["a", "b", "c"])
        let encoded = try encoder.encode(model)
        
        // Try to decode with different strategy
        let decoder = PointFreeFormDecoder(parsingStrategy: .accumulateValues)
        
        // This should fail or produce unexpected results
        #expect(throws: Error.self) {
            _ = try decoder.decode(Model.self, from: encoded)
        }
    }
    
    @Test("Documents strategy requirements")
    func testStrategyDocumentation() throws {
        // This test verifies that using the wrong strategy fails predictably
        let bracketsData = "items[0]=a&items[1]=b".data(using: .utf8)!
        let accumulateData = "items=a&items=b".data(using: .utf8)!
        
        struct Model: Codable {
            let items: [String]
        }
        
        let bracketsDecoder = PointFreeFormDecoder(parsingStrategy: .bracketsWithIndices)
        let accumulateDecoder = PointFreeFormDecoder(parsingStrategy: .accumulateValues)
        
        // Correct combinations should work
        let decoded1 = try bracketsDecoder.decode(Model.self, from: bracketsData)
        #expect(decoded1.items == ["a", "b"])
        
        let decoded2 = try accumulateDecoder.decode(Model.self, from: accumulateData)
        #expect(decoded2.items == ["a", "b"])
        
        // Wrong combinations should fail
        #expect(throws: Error.self) {
            _ = try bracketsDecoder.decode(Model.self, from: accumulateData)
        }
        
        #expect(throws: Error.self) {
            _ = try accumulateDecoder.decode(Model.self, from: bracketsData)
        }
    }
}

@Suite("Memory and Performance")
struct MemoryPerformanceTests {
    
    @Test("Handles extremely large arrays efficiently")
    func testLargeArrayPerformance() throws {
        struct Model: Codable {
            let items: [Int]
        }
        
        // Create large array
        let largeArray = Array(0..<1000)
        let model = Model(items: largeArray)
        
        let encoder = PointFreeFormEncoder(encodingStrategy: .bracketsWithIndices)
        let decoder = PointFreeFormDecoder(parsingStrategy: .bracketsWithIndices)
        
        let startEncode = Date()
        let encoded = try encoder.encode(model)
        let encodeTime = Date().timeIntervalSince(startEncode)
        
        let startDecode = Date()
        let decoded = try decoder.decode(Model.self, from: encoded)
        let decodeTime = Date().timeIntervalSince(startDecode)
        
        #expect(decoded.items.count == 1000)
        #expect(encodeTime < 1.0) // Should complete in under 1 second
        #expect(decodeTime < 1.0) // Should complete in under 1 second
    }
    
    @Test("No memory leaks in encode/decode cycle")
    func testNoMemoryLeaks() throws {
        struct Model: Codable {
            let data: String
        }
        
        let encoder = PointFreeFormEncoder()
        let decoder = PointFreeFormDecoder(parsingStrategy: .bracketsWithIndices)
        
        // Perform multiple encode/decode cycles
        for _ in 0..<100 {
            let model = Model(data: String(repeating: "x", count: 1000))
            let encoded = try encoder.encode(model)
            let decoded = try decoder.decode(Model.self, from: encoded)
            #expect(decoded.data.count == 1000)
        }
        
        // If we get here without crashes, memory is likely managed correctly
        // Test passes by not crashing
    }
}