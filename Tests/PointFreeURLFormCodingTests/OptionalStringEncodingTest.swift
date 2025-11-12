//
//  OptionalStringEncodingTest.swift
//  URLFormCoding Tests
//
//  Created to investigate optional string encoding issues
//

import Foundation
import Testing
import PointFreeURLFormCoding

@Suite("Optional String Encoding Tests")
struct OptionalStringEncodingTests {
    
    struct RequestWithOptionals: Codable {
        let description: String?
        let role: String
        let kind: String?
    }
    
    @Test("Encodes struct with optional strings correctly")
    func testEncodesOptionalStrings() throws {
        let encoder = PointFreeFormEncoder()
        
        // Test with all optionals as nil
        let request1 = RequestWithOptionals(
            description: nil,
            role: "admin",
            kind: nil
        )
        
        let data1 = try encoder.encode(request1)
        let queryString1 = String(data: data1, encoding: .utf8)!
        print("Nil optionals result: \(queryString1)")
        #expect(queryString1.contains("role=admin"))
        
        // Test with optionals having values
        let request2 = RequestWithOptionals(
            description: "Test description",
            role: "user",
            kind: "standard"
        )
        
        let data2 = try encoder.encode(request2)
        let queryString2 = String(data: data2, encoding: .utf8)!
        print("With values result: \(queryString2)")
        #expect(queryString2.contains("role=user"))
        #expect(queryString2.contains("description=Test+description"))
        #expect(queryString2.contains("kind=standard"))
        
        // Test with mixed (some nil, some with values)
        let request3 = RequestWithOptionals(
            description: "Another test",
            role: "moderator",
            kind: nil
        )
        
        let data3 = try encoder.encode(request3)
        let queryString3 = String(data: data3, encoding: .utf8)!
        print("Mixed result: \(queryString3)")
        #expect(queryString3.contains("role=moderator"))
        #expect(queryString3.contains("description=Another+test"))
    }
    
    @Test("Handles special characters in optional strings")
    func testSpecialCharactersInOptionals() throws {
        let encoder = PointFreeFormEncoder()
        
        let request = RequestWithOptionals(
            description: "Test & special < > characters",
            role: "admin",
            kind: "type/subtype"
        )
        
        let data = try encoder.encode(request)
        let queryString = String(data: data, encoding: .utf8)!
        print("Special chars result: \(queryString)")
        
        // Check encoding happened properly
        #expect(queryString.contains("role=admin"))
        // The special characters should be percent-encoded
        #expect(queryString.contains("description="))
        #expect(queryString.contains("kind="))
    }
    
    @Test("Reproduce NSError issue with optional encoding")
    func testOptionalEncodingBug() throws {
        let encoder = PointFreeFormEncoder()
        
        // Create a struct that mimics the Mailgun case
        struct TestRequest: Codable {
            let optionalField: String?
            let requiredField: String
        }
        
        // Test case that might trigger the bug
        let request = TestRequest(
            optionalField: nil,
            requiredField: "test"
        )
        
        // This should encode without crashing
        let data = try encoder.encode(request)
        let result = String(data: data, encoding: .utf8)!
        print("Bug test result: \(result)")
        
        #expect(result.contains("requiredField=test"))
    }
}