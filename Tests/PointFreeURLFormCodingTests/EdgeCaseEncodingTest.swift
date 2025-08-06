//
//  EdgeCaseEncodingTest.swift
//  URLFormCoding Tests
//
//  Test edge cases for the optional encoding fix
//

import Foundation
import Testing
import PointFreeURLFormCoding

@Suite("Edge Case Encoding Tests")
struct EdgeCaseEncodingTests {
    
    // Test various types that might trigger the issue
    struct ComplexOptionalTypes: Codable {
        let optionalString: String?
        let optionalInt: Int?
        let optionalBool: Bool?
        let optionalDouble: Double?
        let optionalDate: Date?
        let optionalData: Data?
        let requiredString: String
    }
    
    @Test("Handles all optional types correctly")
    func testAllOptionalTypes() throws {
        let encoder = PointFreeFormEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.dataEncodingStrategy = .base64
        
        // Test with all nils
        let allNils = ComplexOptionalTypes(
            optionalString: nil,
            optionalInt: nil,
            optionalBool: nil,
            optionalDouble: nil,
            optionalDate: nil,
            optionalData: nil,
            requiredString: "required"
        )
        
        let data1 = try encoder.encode(allNils)
        let result1 = String(data: data1, encoding: .utf8)!
        print("All nils: \(result1)")
        #expect(result1.contains("requiredString=required"))
        
        // Test with all values
        let allValues = ComplexOptionalTypes(
            optionalString: "test",
            optionalInt: 42,
            optionalBool: true,
            optionalDouble: 3.14,
            optionalDate: Date(timeIntervalSince1970: 1000),
            optionalData: Data([1, 2, 3]),
            requiredString: "required"
        )
        
        let data2 = try encoder.encode(allValues)
        let result2 = String(data: data2, encoding: .utf8)!
        print("All values: \(result2)")
        #expect(result2.contains("requiredString=required"))
        #expect(result2.contains("optionalString=test"))
        #expect(result2.contains("optionalInt=42"))
        #expect(result2.contains("optionalBool=true"))
        #expect(result2.contains("optionalDouble=3.14"))
        #expect(result2.contains("optionalDate=1000"))
        #expect(result2.contains("optionalData="))  // Base64 encoded
    }
    
    // Test nested optionals
    struct NestedOptionals: Codable {
        struct Inner: Codable {
            let value: String?
        }
        let inner: Inner?
        let name: String
    }
    
    @Test("Handles nested optionals correctly")
    func testNestedOptionals() throws {
        let encoder = PointFreeFormEncoder()
        
        // Nil inner
        let nilInner = NestedOptionals(inner: nil, name: "test")
        let data1 = try encoder.encode(nilInner)
        let result1 = String(data: data1, encoding: .utf8)!
        print("Nil inner: \(result1)")
        #expect(result1.contains("name=test"))
        
        // Inner with nil value
        let innerNilValue = NestedOptionals(
            inner: NestedOptionals.Inner(value: nil),
            name: "test"
        )
        let data2 = try encoder.encode(innerNilValue)
        let result2 = String(data: data2, encoding: .utf8)!
        print("Inner with nil value: \(result2)")
        #expect(result2.contains("name=test"))
        
        // Inner with value
        let innerWithValue = NestedOptionals(
            inner: NestedOptionals.Inner(value: "inner value"),
            name: "test"
        )
        let data3 = try encoder.encode(innerWithValue)
        let result3 = String(data: data3, encoding: .utf8)!
        print("Inner with value: \(result3)")
        #expect(result3.contains("name=test"))
        #expect(result3.contains("inner"))
        #expect(result3.contains("value"))
    }
    
    // Test arrays of optionals
    struct ArrayOfOptionals: Codable {
        let values: [String?]
        let name: String
    }
    
    @Test("Handles arrays of optionals correctly")
    func testArrayOfOptionals() throws {
        let encoder = PointFreeFormEncoder()
        encoder.arrayEncodingStrategy = .bracketsWithIndices
        
        let model = ArrayOfOptionals(
            values: ["first", nil, "third", nil],
            name: "test"
        )
        
        let data = try encoder.encode(model)
        let result = String(data: data, encoding: .utf8)!
        print("Array of optionals: \(result)")
        #expect(result.contains("name=test"))
        #expect(result.contains("values[0]=first"))
        #expect(result.contains("values[2]=third"))
    }
    
    // Test edge case with enum
    enum TestEnum: String, Codable {
        case one
        case two
    }
    
    struct OptionalEnum: Codable {
        let enumValue: TestEnum?
        let name: String
    }
    
    @Test("Handles optional enums correctly")
    func testOptionalEnum() throws {
        let encoder = PointFreeFormEncoder()
        
        // Nil enum
        let nilEnum = OptionalEnum(enumValue: nil, name: "test")
        let data1 = try encoder.encode(nilEnum)
        let result1 = String(data: data1, encoding: .utf8)!
        print("Nil enum: \(result1)")
        #expect(result1.contains("name=test"))
        
        // With enum value
        let withEnum = OptionalEnum(enumValue: .one, name: "test")
        let data2 = try encoder.encode(withEnum)
        let result2 = String(data: data2, encoding: .utf8)!
        print("With enum: \(result2)")
        #expect(result2.contains("name=test"))
        #expect(result2.contains("enumValue=one"))
    }
}