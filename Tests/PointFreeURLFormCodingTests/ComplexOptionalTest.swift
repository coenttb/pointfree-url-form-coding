//
//  ComplexOptionalTest.swift
//  URLFormCoding Tests
//
//  Testing complex types in optionals
//

import Foundation
import Testing
import PointFreeURLFormCoding

@Suite("Complex Optional Tests")
struct ComplexOptionalTests {
    
    // A complex type that uses keyed encoding
    struct ComplexType: Codable {
        let id: Int
        let name: String
    }
    
    struct WithOptionalComplex: Codable {
        let complex: ComplexType?
        let simple: String
    }
    
    @Test("Encode optional complex type")
    func testOptionalComplexType() throws {
        let encoder = PointFreeFormEncoder()
        
        // With nil
        let withNil = WithOptionalComplex(complex: nil, simple: "test")
        let data1 = try encoder.encode(withNil)
        let result1 = String(data: data1, encoding: .utf8)!
        print("Nil complex: \(result1)")
        
        // With value
        let withValue = WithOptionalComplex(
            complex: ComplexType(id: 1, name: "test"),
            simple: "test"
        )
        let data2 = try encoder.encode(withValue)
        let result2 = String(data: data2, encoding: .utf8)!
        print("With complex: \(result2)")
    }
    
    // Test with a type that might encode weirdly
    struct WeirdType: Codable {
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            // This tries to encode something complex as a single value
            try container.encode("weird")
        }
        
        init() {}
        
        init(from decoder: Decoder) throws {
            _ = try decoder.singleValueContainer()
        }
    }
    
    struct WithWeirdOptional: Codable {
        let weird: WeirdType?
        let normal: String
    }
    
    @Test("Encode weird optional type")
    func testWeirdOptionalType() throws {
        let encoder = PointFreeFormEncoder()
        
        let withWeird = WithWeirdOptional(
            weird: WeirdType(),
            normal: "test"
        )
        
        let data = try encoder.encode(withWeird)
        let result = String(data: data, encoding: .utf8)!
        print("With weird: \(result)")
    }
}