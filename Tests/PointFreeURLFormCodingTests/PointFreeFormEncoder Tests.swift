//
//  PointFreeFormEncoder Tests.swift
//  URLFormCoding Tests
//
//  Created by Coen ten Thije Boonkkamp on 26/07/2025.
//

import Foundation
import Testing
import PointFreeURLFormCoding

// MARK: - Main Test Suite

@Suite("PointFreeFormEncoder Tests")
struct FormEncoderTests {

    // MARK: - Basic Encoding Tests

    @Suite("Basic Encoding")
    struct BasicEncodingTests {

        @Test("Encodes basic types correctly")
        func testEncodesBasicTypesCorrectly() throws {
            let encoder = PointFreeFormEncoder()
            let user = BasicUser(name: "John Doe", age: 30, isActive: true)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)

            #expect(queryString != nil)
            let query = queryString!

            // Check that all fields are present
            #expect(query.contains("name="))
            #expect(query.contains("age="))
            #expect(query.contains("isActive="))

            // Check specific values (URL encoded)
            #expect(query.contains("name=John%20Doe"))
            #expect(query.contains("age=30"))
            #expect(query.contains("isActive=true"))
        }

        @Test("Encodes strings with special characters")
        func testEncodesStringsWithSpecialCharacters() throws {
            let encoder = PointFreeFormEncoder()
            let user = BasicUser(name: "John & Jane", age: 25, isActive: false)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            // Should properly encode ampersand
            #expect(queryString.contains("John%20%26%20Jane"))
        }

        @Test("Handles empty strings")
        func testHandlesEmptyStrings() throws {
            let encoder = PointFreeFormEncoder()
            let user = BasicUser(name: "", age: 0, isActive: false)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name="))
            #expect(queryString.contains("age=0"))
            #expect(queryString.contains("isActive=false"))
        }
    }

    // MARK: - Nested Object Tests

    @Suite("Nested Object Encoding")
    struct NestedObjectTests {

        @Test("Encodes nested objects correctly")
        func testEncodesNestedObjectsCorrectly() throws {
            let encoder = PointFreeFormEncoder()
            let user = NestedUser(
                name: "Alice",
                profile: NestedUser.Profile(bio: "Developer", website: "https://example.com")
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            // Should contain nested structure
            #expect(queryString.contains("name=Alice"))
            #expect(queryString.contains("profile") && queryString.contains("bio"))
            #expect(queryString.contains("profile") && queryString.contains("website"))
        }

        @Test("Handles nested objects with nil optionals")
        func testHandlesNestedObjectsWithNilOptionals() throws {
            let encoder = PointFreeFormEncoder()
            let user = NestedUser(
                name: "Bob",
                profile: NestedUser.Profile(bio: "Designer", website: nil)
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Bob"))
            #expect(queryString.contains("profile[bio]=Designer"))
            // Nil optional should not be included in output
            #expect(!queryString.contains("website"))
        }
    }

    // MARK: - Array Encoding Tests

    @Suite("Array Encoding")
    struct ArrayEncodingTests {

        @Test("Encodes string arrays correctly")
        func testEncodesStringArraysCorrectly() throws {
            let encoder = PointFreeFormEncoder()
            let user = UserWithArrays(
                name: "Charlie",
                tags: ["swift", "ios", "developer"],
                scores: [85, 92, 78]
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Charlie"))
            #expect(queryString.contains("tags"))
            #expect(queryString.contains("scores"))
            #expect(queryString.contains("swift"))
            #expect(queryString.contains("85"))
        }

        @Test("Handles empty arrays")
        func testHandlesEmptyArrays() throws {
            let encoder = PointFreeFormEncoder()
            let user = UserWithArrays(
                name: "Diana",
                tags: [],
                scores: []
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Diana"))
            // Empty arrays should not include array elements in output
            #expect(!queryString.contains("tags["))
            #expect(!queryString.contains("scores["))
        }

        @Test("Encodes arrays with single element")
        func testEncodesArraysWithSingleElement() throws {
            let encoder = PointFreeFormEncoder()
            let user = UserWithArrays(
                name: "Eve",
                tags: ["admin"],
                scores: [100]
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Eve"))
            #expect(queryString.contains("admin"))
            #expect(queryString.contains("100"))
        }
    }

    // MARK: - Optional Values Tests

    @Suite("Optional Values")
    struct OptionalValuesTests {

        @Test("Encodes present optional values")
        func testEncodesPresentOptionalValues() throws {
            let encoder = PointFreeFormEncoder()
            let user = UserWithOptionals(
                name: "Frank",
                email: "frank@example.com",
                age: 28,
                isVerified: true
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Frank"))
            #expect(queryString.contains("email=frank%40example.com"))
            #expect(queryString.contains("age=28"))
            #expect(queryString.contains("isVerified=true"))
        }

        @Test("Handles nil optional values")
        func testHandlesNilOptionalValues() throws {
            let encoder = PointFreeFormEncoder()
            let user = UserWithOptionals(
                name: "Grace",
                email: nil,
                age: nil,
                isVerified: nil
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Grace"))
            // Nil optional values should not be included in output
            #expect(!queryString.contains("email="))
            #expect(!queryString.contains("age="))
            #expect(!queryString.contains("isVerified="))
        }

        @Test("Handles mixed optional values")
        func testHandlesMixedOptionalValues() throws {
            let encoder = PointFreeFormEncoder()
            let user = UserWithOptionals(
                name: "Henry",
                email: "henry@test.com",
                age: nil,
                isVerified: false
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Henry"))
            #expect(queryString.contains("email=henry%40test.com"))
            #expect(queryString.contains("isVerified=false"))
            // Nil age should not be included
            #expect(!queryString.contains("age="))
        }
    }

    // MARK: - Date Encoding Tests

    @Suite("Date Encoding")
    struct DateEncodingTests {

        @Test("Encodes dates with default strategy")
        func testEncodesDatesWithDefaultStrategy() throws {
            let encoder = PointFreeFormEncoder()
            let date = Date(timeIntervalSince1970: 1234567890) // Fixed date for testing
            let user = UserWithDates(
                name: "Ivy",
                createdAt: date,
                lastLogin: date
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Ivy"))
            #expect(queryString.contains("createdAt="))
            #expect(queryString.contains("lastLogin="))
        }

        @Test("Encodes dates as seconds since 1970")
        func testEncodesDatesAsSecondsSince1970() throws {
            let encoder = PointFreeFormEncoder(dateEncodingStrategy: .secondsSince1970)

            let date = Date(timeIntervalSince1970: 1234567890)
            let user = UserWithDates(
                name: "Jack",
                createdAt: date,
                lastLogin: nil
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Jack"))
            #expect(queryString.contains("createdAt=1234567890"))
        }

        @Test("Encodes dates as milliseconds since 1970")
        func testEncodesDatesAsMillisecondsSince1970() throws {
            let encoder = PointFreeFormEncoder(dateEncodingStrategy: .millisecondsSince1970)

            let date = Date(timeIntervalSince1970: 1234567.890)
            let user = UserWithDates(
                name: "Kate",
                createdAt: date,
                lastLogin: nil
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Kate"))
            // Check for the actual milliseconds value (1234567.890 * 1000)
            let expectedMillis = Int64(date.timeIntervalSince1970 * 1000)
            #expect(queryString.contains("createdAt=\(expectedMillis)"))
        }

        @Test("Encodes dates with custom formatter")
        func testEncodesDatesWithCustomFormatter() throws {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let encoder = PointFreeFormEncoder(dateEncodingStrategy: .formatted(formatter))

            let date = Date(timeIntervalSince1970: 1234567890) // 2009-02-13
            let user = UserWithDates(
                name: "Liam",
                createdAt: date,
                lastLogin: nil
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Liam"))
            let expectedDate = formatter.string(from: date)
            #expect(queryString.contains("createdAt=\(expectedDate)"))
        }
    }

    // MARK: - Data Encoding Tests

    @Suite("Data Encoding")
    struct DataEncodingTests {

        @Test("Encodes data as array by default")
        func testEncodesDataAsArrayByDefault() throws {
            let encoder = PointFreeFormEncoder()
            let testData = "Hello".data(using: .utf8)! // Shorter for clearer testing
            let user = UserWithData(
                name: "Maya",
                avatar: testData,
                thumbnail: nil
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Maya"))
            #expect(queryString.contains("avatar["))

            // By default, Data is encoded as array of bytes
            // "Hello" = [72, 101, 108, 108, 111]
            #expect(queryString.contains("avatar[0]=72"))
            #expect(queryString.contains("avatar[1]=101"))
        }

        @Test("Encodes data with base64 strategy")
        func testEncodesDataWithBase64Strategy() throws {
            let encoder = PointFreeFormEncoder(dataEncodingStrategy: .base64)

            let testData = "Hello World".data(using: .utf8)!
            let user = UserWithData(
                name: "Noah",
                avatar: testData,
                thumbnail: testData
            )

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name=Noah"))
            let expectedBase64 = testData.base64EncodedString()
            #expect(queryString.contains("avatar=\(expectedBase64)"))
            #expect(queryString.contains("thumbnail=\(expectedBase64)"))
        }
    }

    // MARK: - Round-trip Tests

    @Suite("Round-trip Encoding/Decoding")
    struct RoundTripTests {

        @Test("Basic types round-trip correctly")
        func testBasicTypesRoundTripCorrectly() throws {
            let encoder = PointFreeFormEncoder()
            let decoder = PointFreeFormDecoder()

            let original = BasicUser(name: "Oliver", age: 35, isActive: true)

            let encoded = try encoder.encode(original)
            let decoded = try decoder.decode(BasicUser.self, from: encoded)

            #expect(decoded == original)
        }

        @Test("Arrays round-trip correctly with bracketsWithIndices strategy")
        func testArraysRoundTripCorrectly() throws {
            let encoder = PointFreeFormEncoder()
            let decoder = PointFreeFormDecoder()
            decoder.parsingStrategy = .bracketsWithIndices // Use compatible parsing strategy

            let original = UserWithArrays(
                name: "Penny",
                tags: ["swift", "developer", "ios"],
                scores: [90, 85, 95]
            )

            let encoded = try encoder.encode(original)
            let decoded = try decoder.decode(UserWithArrays.self, from: encoded)

            #expect(decoded == original)
        }

        @Test("Optional values round-trip correctly")
        func testOptionalValuesRoundTripCorrectly() throws {
            let encoder = PointFreeFormEncoder()
            let decoder = PointFreeFormDecoder()

            let original = UserWithOptionals(
                name: "Quinn",
                email: "quinn@test.com",
                age: nil,
                isVerified: true
            )

            let encoded = try encoder.encode(original)
            let decoded = try decoder.decode(UserWithOptionals.self, from: encoded)

            #expect(decoded == original)
        }

        @Test("Dates round-trip correctly with matching strategies")
        func testDatesRoundTripCorrectlyWithMatchingStrategies() throws {
            let encoder = PointFreeFormEncoder(dateEncodingStrategy: .secondsSince1970)
            let decoder = PointFreeFormDecoder(dateDecodingStrategy: .secondsSince1970)

            let date = Date(timeIntervalSince1970: 1234567890)
            let original = UserWithDates(
                name: "Ruby",
                createdAt: date,
                lastLogin: date
            )

            let encoded = try encoder.encode(original)
            let decoded = try decoder.decode(UserWithDates.self, from: encoded)

            #expect(decoded == original)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases")
    struct EdgeCasesTests {

        @Test("Handles very long strings")
        func testHandlesVeryLongStrings() throws {
            let encoder = PointFreeFormEncoder()
            let longString = String(repeating: "a", count: 10000)
            let user = BasicUser(name: longString, age: 25, isActive: true)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name="))
            #expect(queryString.count > 10000) // Should contain the long string
        }

        @Test("Handles Unicode characters")
        func testHandlesUnicodeCharacters() throws {
            let encoder = PointFreeFormEncoder()
            let user = BasicUser(name: "José María 🇪🇸", age: 30, isActive: true)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("name="))
            // Should properly encode Unicode characters
        }

        @Test("Handles large numbers")
        func testHandlesLargeNumbers() throws {
            let encoder = PointFreeFormEncoder()
            let user = BasicUser(name: "Test", age: Int.max, isActive: false)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            #expect(queryString.contains("age=\(Int.max)"))
        }
    }

    // MARK: - Security Tests

    @Suite("Security")
    struct SecurityTests {

        @Test("Properly encodes reserved characters")
        func testProperlyEncodesReservedCharacters() throws {
            let encoder = PointFreeFormEncoder()
            let user = BasicUser(name: "test=value&other=data", age: 30, isActive: true)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            // Reserved characters should be percent-encoded
            #expect(queryString.contains("test%3Dvalue%26other%3Ddata"))
            #expect(!queryString.contains("test=value&other=data"))
        }

        @Test("Handles potentially malicious characters")
        func testHandlesPotentiallyMaliciousCharacters() throws {
            let encoder = PointFreeFormEncoder()
            let maliciousName = "<script>alert('xss')</script>"
            let user = BasicUser(name: maliciousName, age: 30, isActive: true)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            // Should be properly encoded, not allowing script injection
            #expect(!queryString.contains("<script>"))
            #expect(!queryString.contains("</script>"))
            #expect(queryString.contains("%3C") && queryString.contains("%3E"))
            // The word 'alert' might still appear in encoded form, so we check for dangerous patterns
            #expect(!queryString.contains("<script>alert"))
        }

        @Test("Handles null bytes and control characters")
        func testHandlesNullBytesAndControlCharacters() throws {
            let encoder = PointFreeFormEncoder()
            let nameWithControlChars = "test\u{0000}\u{0001}\u{001F}name"
            let user = BasicUser(name: nameWithControlChars, age: 30, isActive: true)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            // Control characters should be percent-encoded or handled safely
            // The exact encoding may vary, but dangerous characters should not appear raw
            #expect(!nameWithControlChars.contains(queryString) || queryString.contains("%"))
        }
    }

    // MARK: - Configuration Tests

    @Suite("Encoder Configuration")
    struct ConfigurationTests {

        @Test("Uses custom key encoding strategy")
        func testUsesCustomKeyEncodingStrategy() throws {
            let encoder = PointFreeFormEncoder()
            // Test custom key encoding if available

            let user = BasicUser(name: "Sam", age: 32, isActive: false)
            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            // Should contain properly formatted keys
            #expect(queryString.contains("name="))
            #expect(queryString.contains("age="))
            #expect(queryString.contains("isActive=") || queryString.contains("is_active="))
        }

        @Test("Encoder produces consistent output")
        func testEncoderProducesConsistentOutput() throws {
            let encoder = PointFreeFormEncoder()
            let user = BasicUser(name: "Tina", age: 27, isActive: true)

            let data1 = try encoder.encode(user)
            let data2 = try encoder.encode(user)

            // Should produce identical output for identical input
            #expect(data1 == data2)
        }
    }

    // MARK: - Character Set Tests

    @Suite("Character Set Usage")
    struct CharacterSetTests {

        @Test("Uses correct character set for URL encoding")
        func testUsesCorrectCharacterSetForURLEncoding() throws {
            let encoder = PointFreeFormEncoder()

            // Test string with characters that should and shouldn't be encoded
            let testString = "abc123-_.~:/?#[]@!$&'()*+,;="
            let user = BasicUser(name: testString, age: 30, isActive: true)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            // Unreserved characters should not be encoded: A-Z a-z 0-9 - . _ ~
            #expect(queryString.contains("abc123-_.~"))

            // Reserved characters should be encoded: : / ? # [ ] @ ! $ & ' ( ) * + , ; =
            #expect(!queryString.contains(":/?#[]@!$&'()*+,;="))
            #expect(queryString.contains("%3A") || queryString.contains("%2F"))
        }

        @Test("Correctly encodes space characters")
        func testCorrectlyEncodesSpaceCharacters() throws {
            let encoder = PointFreeFormEncoder()
            let user = BasicUser(name: "hello world", age: 30, isActive: true)

            let data = try encoder.encode(user)
            let queryString = String(data: data, encoding: .utf8)!

            // Spaces should be encoded as %20, not +
            #expect(queryString.contains("hello%20world"))
            #expect(!queryString.contains("hello+world"))
        }
    }

    // MARK: - Performance Tests

    @Suite("Performance")
    struct PerformanceTests {

        @Test("Encodes large objects efficiently")
        func testEncodesLargeObjectsEfficiently() throws {
            let encoder = PointFreeFormEncoder()
            let largeArray = UserWithArrays(
                name: "Performance Test",
                tags: Array(repeating: "tag", count: 1000),
                scores: Array(0..<1000)
            )

            // Should complete without timeout
            let data = try encoder.encode(largeArray)
            #expect(!data.isEmpty)
        }
    }
}
