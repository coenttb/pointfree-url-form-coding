//
//  DebuggingNSErrorTest.swift
//  URLFormCoding Tests
//
//  Debugging the NSError issue
//

import Foundation
import Testing
import PointFreeURLFormCoding

@Suite("Debugging NSError Issue")
struct DebuggingNSErrorTests {
    
    // Try to reproduce the exact Mailgun scenario
    struct MailgunRequest: Codable {
        let from: String
        let to: [String]
        let subject: String
        let text: String?
        let html: String?
        let cc: [String]?
        let bcc: [String]?
        let tags: [String]?
        let testMode: Bool?
        let description: String?
        let kind: String?
    }
    
    @Test("Encode Mailgun-like request with all optionals")
    func testMailgunRequest() throws {
        let encoder = PointFreeFormEncoder()
        encoder.arrayEncodingStrategy = .bracketsWithIndices
        
        // Test with various combinations
        let request1 = MailgunRequest(
            from: "sender@test.com",
            to: ["recipient@test.com"],
            subject: "Test",
            text: nil,
            html: nil,
            cc: nil,
            bcc: nil,
            tags: nil,
            testMode: nil,
            description: nil,
            kind: nil
        )
        
        let data1 = try encoder.encode(request1)
        let result1 = String(data: data1, encoding: .utf8)!
        print("All nils: \(result1)")
        
        // Test with some values
        let request2 = MailgunRequest(
            from: "sender@test.com",
            to: ["recipient@test.com"],
            subject: "Test",
            text: "Plain text",
            html: "<p>HTML</p>",
            cc: ["cc@test.com"],
            bcc: ["bcc@test.com"],
            tags: ["tag1", "tag2"],
            testMode: true,
            description: "Test description",
            kind: "test"
        )
        
        let data2 = try encoder.encode(request2)
        let result2 = String(data: data2, encoding: .utf8)!
        print("With values: \(result2)")
    }
    
    // Test encoding error objects
    enum TestError: Error, Codable {
        case someError
    }
    
    struct RequestWithError: Codable {
        let error: TestError?
        let message: String
    }
    
    @Test("Test encoding error types")
    func testErrorEncoding() throws {
        let encoder = PointFreeFormEncoder()
        
        let request = RequestWithError(
            error: .someError,
            message: "test"
        )
        
        let data = try encoder.encode(request)
        let result = String(data: data, encoding: .utf8)!
        print("Error encoding: \(result)")
    }
    
    // Test with URL type which might be problematic
    struct RequestWithURL: Codable {
        let url: URL?
        let name: String
    }
    
    @Test("Test URL encoding")
    func testURLEncoding() throws {
        let encoder = PointFreeFormEncoder()
        
        let request1 = RequestWithURL(
            url: nil,
            name: "test"
        )
        
        let data1 = try encoder.encode(request1)
        let result1 = String(data: data1, encoding: .utf8)!
        print("Nil URL: \(result1)")
        
        let request2 = RequestWithURL(
            url: URL(string: "https://example.com"),
            name: "test"
        )
        
        let data2 = try encoder.encode(request2)
        let result2 = String(data: data2, encoding: .utf8)!
        print("With URL: \(result2)")
    }
    
    // Test what happens with non-string primitive optionals
    struct MixedOptionals: Codable {
        let optString: String?
        let optInt: Int?
        let optDouble: Double?
        let optBool: Bool?
        let required: String
    }
    
    @Test("Test mixed optional primitives")
    func testMixedOptionalPrimitives() throws {
        let encoder = PointFreeFormEncoder()
        
        // All nil
        let allNil = MixedOptionals(
            optString: nil,
            optInt: nil,
            optDouble: nil,
            optBool: nil,
            required: "test"
        )
        
        print("Encoding all nil...")
        let data1 = try encoder.encode(allNil)
        let result1 = String(data: data1, encoding: .utf8)!
        print("All nil result: \(result1)")
        
        // Some values
        let someValues = MixedOptionals(
            optString: "string",
            optInt: 42,
            optDouble: nil,
            optBool: true,
            required: "test"
        )
        
        print("Encoding some values...")
        let data2 = try encoder.encode(someValues)
        let result2 = String(data: data2, encoding: .utf8)!
        print("Some values result: \(result2)")
    }
}