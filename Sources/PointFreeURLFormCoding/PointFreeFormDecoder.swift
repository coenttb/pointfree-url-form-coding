import Foundation
import WHATWG_URL_Encoding

/// A decoder that converts URL-encoded form data to Swift Codable types.
///
/// `PointFreeFormDecoder` implements the `Decoder` protocol to provide seamless
/// conversion from `application/x-www-form-urlencoded` format to Swift types.
/// It supports various parsing strategies for handling different form data formats.
///
/// ## Basic Usage
///
/// ```swift
/// struct User: Codable {
///     let name: String
///     let age: Int
///     let isActive: Bool
/// }
///
/// let decoder = PointFreeFormDecoder()
/// let formData = "name=John%20Doe&age=30&isActive=true".data(using: .utf8)!
/// let user = try decoder.decode(User.self, from: formData)
/// ```
///
/// ## Parsing Strategies
///
/// The decoder supports multiple parsing strategies for different form data formats:
///
/// ### Accumulate Values (Default)
/// ```
/// tags=swift&tags=ios&tags=server
/// // Parsed as: tags = ["swift", "ios", "server"]
/// ```
///
/// ### Brackets
/// ```
/// user[name]=John&user[email]=john@example.com
/// // Parsed as: user = {name: "John", email: "john@example.com"}
/// ```
///
/// ### Brackets with Indices
/// ```
/// items[0]=apple&items[1]=banana
/// // Parsed as: items = ["apple", "banana"]
/// ```
///
/// ## Configuration
///
/// ```swift
/// let decoder = PointFreeFormDecoder()
/// decoder.arrayParsingStrategy = .brackets
/// decoder.dateDecodingStrategy = .iso8601
/// decoder.dataDecodingStrategy = .base64
/// ```
///
/// ## Advanced Features
///
/// - Multiple parsing strategies for different form formats
/// - Configurable date and data decoding strategies
/// - Support for nested objects and arrays
/// - Custom parsing strategy support
/// - Comprehensive error reporting with coding paths
///
/// - Note: This decoder is designed to work with ``PointFreeFormEncoder`` for round-trip compatibility.
/// - Important: Choose parsing strategies that match your form data format.
public final class PointFreeFormDecoder: Swift.Decoder {
    private(set) var containers: [Container] = []
    private var container: Container {
        return containers.last!
    }
    public private(set) var codingPath: [CodingKey] = []
    public var dataDecodingStrategy: PointFreeFormDecoder.DataDecodingStrategy
    public var dateDecodingStrategy: PointFreeFormDecoder.DateDecodingStrategy
    public var arrayParsingStrategy: PointFreeFormDecoder.ArrayParsingStrategy
    public let userInfo: [CodingUserInfoKey: Any] = [:]

    public init(
        dataDecodingStrategy: PointFreeFormDecoder.DataDecodingStrategy = .deferredToData,
        dateDecodingStrategy: PointFreeFormDecoder.DateDecodingStrategy = .deferredToDate,
        arrayParsingStrategy: PointFreeFormDecoder.ArrayParsingStrategy = .accumulateValues
    ) {
        self.dataDecodingStrategy = dataDecodingStrategy
        self.dateDecodingStrategy = dateDecodingStrategy
        self.arrayParsingStrategy = arrayParsingStrategy
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let query = String(decoding: data, as: UTF8.self)
        let container = self.arrayParsingStrategy.parse(query)
        self.containers.append(container)
        defer { self.containers.removeLast() }
        return try T(from: self)
    }

    private func unbox(_ container: Container) -> String? {
        if self.arrayParsingStrategy.handleSingleValue {
            // For accumulateValues strategy, handle both single values and arrays
            // If it's an array, take the last value; if it's a single value, return it
            return container.values?.last?.value ?? container.value
        } else {
            return container.value
        }
    }

    private func unbox(_ value: Container, as type: Data.Type) throws -> Data {
        guard let string = unbox(value) else {
            throw Error.decodingError("Expected string data, got \(value)", self.codingPath)
        }

        // Decode the data using the strategy
        guard let data = self.dataDecodingStrategy.decode(string) else {
            // If decode returns nil, it means we should use deferredToData
            return try Data(from: self)
        }
        return data
    }

    private func unbox(_ value: Container, as type: Date.Type) throws -> Date {
        guard let string = unbox(value) else {
            throw Error.decodingError("Expected string date, got \(value)", self.codingPath)
        }

        // Decode the date using the strategy
        guard let date = self.dateDecodingStrategy.decode(string) else {
            // If decode returns nil, it means we should use deferredToDate
            return try Date(from: self)
        }
        return date
    }

    private func unbox<T: Decodable>(_ value: Container, as type: T.Type) throws -> T {
        if type == Data.self {
            return try self.unbox(value, as: Data.self) as! T
        } else if type == Date.self {
            return try self.unbox(value, as: Date.self) as! T
        } else if type == Decimal.self {
            return try self.unbox(value, as: Decimal.self) as! T
        } else {
            return try T(from: self)
        }
    }
    
    private func unbox(_ value: Container, as type: Decimal.Type) throws -> Decimal {
        guard let string = unbox(value) else {
            throw Error.decodingError("Expected string decimal, got \(value)", self.codingPath)
        }
        
        guard let decimal = Decimal(string: string) else {
            throw Error.decodingError("Invalid decimal string: \(string)", self.codingPath)
        }
        
        return decimal
    }

    public func container<Key>(keyedBy type: Key.Type) throws
    -> KeyedDecodingContainer<Key>
    where Key: CodingKey {

        guard case let .keyed(container) = self.container else {
            throw Error.decodingError("Expected keyed container, got \(self.container)", self.codingPath)
        }
        return .init(KeyedContainer(decoder: self, container: container))
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        switch self.container {
        case let .unkeyed(container):
            return UnkeyedContainer(decoder: self, container: container, codingPath: self.codingPath)
        case let .singleValue(value):
            // For strategies like accumulateValues, treat a single value as an array with one element
            if self.arrayParsingStrategy.handleSingleValue {
                let container = [Container.singleValue(value)]
                return UnkeyedContainer(decoder: self, container: container, codingPath: self.codingPath)
            } else {
                throw Error.decodingError("Expected unkeyed container, got \(self.container)", self.codingPath)
            }
        default:
            throw Error.decodingError("Expected unkeyed container, got \(self.container)", self.codingPath)
        }
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SingleValueContainer(decoder: self, container: self.container)
    }

    public enum Error: Swift.Error, CustomStringConvertible {
        case decodingError(String, [CodingKey])
        
        public var description: String {
            switch self {
            case let .decodingError(message, path):
                let pathString = path.map { $0.stringValue }.joined(separator: ".")
                let location = pathString.isEmpty ? "" : " at path '\(pathString)'"
                
                // Add helpful hints for common issues
                if message.contains("Expected Array") || message.contains("Expected unkeyed") {
                    return "\(message)\(location). Hint: This might be a parsing strategy mismatch. Arrays encoded with 'bracketsWithIndices' (tags[0]=value) need to be decoded with the same strategy, not 'accumulateValues' (tags=value)."
                } else if message.contains("got nil") && (pathString.contains("tags") || pathString.contains("items")) {
                    return "\(message)\(location). Hint: Array fields may require matching encoding/decoding strategies. Check if encoder uses 'bracketsWithIndices' and decoder uses the same."
                } else {
                    return "\(message)\(location)"
                }
            }
        }
    }

    struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
        private(set) var decoder: PointFreeFormDecoder
        let container: [String: Container]

        var codingPath: [CodingKey] {
            return self.decoder.codingPath
        }
        var allKeys: [Key] {
            return self.container.keys.compactMap(Key.init(stringValue:))
        }

        private func checked<T>(_ key: Key, _ block: (String) throws -> T) throws -> T {
            guard let value = self.container[key.stringValue].flatMap(self.decoder.unbox) else {
                throw Error.decodingError("Expected \(T.self) at \(key), got nil", self.codingPath)
            }
            return try block(value)
        }

        private func unwrap<T>(_ key: Key, _ block: (String) -> T?) throws -> T {
            guard let value = try self.checked(key, block) else {
                throw Error.decodingError("Expected \(T.self) at \(key), got nil", self.codingPath)
            }
            return value
        }

        func contains(_ key: Key) -> Bool {
            return self.container[key.stringValue] != nil
        }

        func decodeNil(forKey key: Key) throws -> Bool {
            return self.container[key.stringValue].flatMap(self.decoder.unbox).map { $0.isEmpty } ?? true
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            return try self.unwrap(key, isTrue)
        }

        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            return try self.unwrap(key, Int.init)
        }

        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            return try self.unwrap(key, Int8.init)
        }

        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            return try self.unwrap(key, Int16.init)
        }

        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            return try self.unwrap(key, Int32.init)
        }

        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            return try self.unwrap(key, Int64.init)
        }

        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            return try self.unwrap(key, UInt.init)
        }

        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            return try self.unwrap(key, UInt8.init)
        }

        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            return try self.unwrap(key, UInt16.init)
        }

        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            return try self.unwrap(key, UInt32.init)
        }

        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            return try self.unwrap(key, UInt64.init)
        }

        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            return try self.unwrap(key, Float.init)
        }

        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            return try self.unwrap(key, Double.init)
        }

        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            return try self.unwrap(key, id)
        }
        
        func decode(_ type: Decimal.Type, forKey key: Key) throws -> Decimal {
            return try self.unwrap(key) { Decimal(string: $0) ?? Decimal() }
        }

        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
            self.decoder.codingPath.append(key)
            defer { self.decoder.codingPath.removeLast() }
            guard let container = self.container[key.stringValue] else {
                throw Error.decodingError("Expected \(T.self) at \(key), got nil", self.codingPath)
            }
            self.decoder.containers.append(container)
            defer { self.decoder.containers.removeLast() }
            return try self.decoder.unbox(container, as: T.self)
        }
        
        func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
            guard self.contains(key) else { return nil }
            // Check if the value is empty
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(Bool.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
            guard self.contains(key) else { return nil }
            // Check if the value is empty (for cases like age=)
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(Int.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(Int8.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(Int16.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(Int32.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(Int64.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(UInt.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(UInt8.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(UInt16.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(UInt32.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(UInt64.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(Float.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(Double.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
            guard self.contains(key) else { return nil }
            return try self.decode(String.self, forKey: key)
        }
        
        func decodeIfPresent(_ type: Decimal.Type, forKey key: Key) throws -> Decimal? {
            guard self.contains(key) else { return nil }
            if let value = self.container[key.stringValue].flatMap(self.decoder.unbox), value.isEmpty {
                return nil
            }
            return try self.decode(Decimal.self, forKey: key)
        }
        
        func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T? where T: Decodable {
            guard self.contains(key) else { return nil }
            return try self.decode(T.self, forKey: key)
        }

        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws
        -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {

            self.decoder.codingPath.append(key)
            defer { self.decoder.codingPath.removeLast() }
            guard case let .keyed(container)? = self.container[key.stringValue] else {
                throw Error.decodingError("Expected value at \(key), got nil", self.codingPath)
            }
            self.decoder.containers.append(.keyed(container)) // FIXME?
            defer { self.decoder.containers.removeLast() }
            return .init(KeyedContainer<NestedKey>(decoder: self.decoder, container: container))
        }

        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            self.decoder.codingPath.append(key)
            defer { self.decoder.codingPath.removeLast() }
            guard case let .unkeyed(container)? = self.container[key.stringValue] else {
                throw Error.decodingError("Expected value at \(key), got nil", self.codingPath)
            }
            self.decoder.containers.append(.unkeyed(container)) // FIXME?
            defer { self.decoder.containers.removeLast() }
            return UnkeyedContainer(decoder: self.decoder, container: container, codingPath: self.codingPath)
        }

        func superDecoder() throws -> Swift.Decoder {
            fatalError()
        }

        func superDecoder(forKey key: Key) throws -> Swift.Decoder {
            self.decoder.codingPath.append(key)
            defer { self.decoder.codingPath.removeLast() }
            guard let container = self.container[key.stringValue] else {
                throw Error.decodingError("Expected value at \(key), got nil", self.codingPath)
            }
            let decoder = PointFreeFormDecoder()
            decoder.containers = [container]
            decoder.codingPath = self.codingPath
            decoder.dataDecodingStrategy = self.decoder.dataDecodingStrategy
            decoder.dateDecodingStrategy = self.decoder.dateDecodingStrategy
            decoder.arrayParsingStrategy = self.decoder.arrayParsingStrategy
            return decoder
        }
    }

    struct UnkeyedContainer: UnkeyedDecodingContainer {
        struct Key {
            let index: Int
        }

        let decoder: PointFreeFormDecoder
        let container: [Container]

        private(set) var codingPath: [CodingKey]
        var count: Int? {
            return self.container.count
        }
        var isAtEnd: Bool {
            return self.currentIndex >= self.container.count
        }
        private(set) var currentIndex: Int = 0

        init(decoder: PointFreeFormDecoder, container: [Container], codingPath: [CodingKey]) {
            self.decoder = decoder
            self.container = container
            self.codingPath = codingPath
        }

        mutating private func checked<T>(_ block: (String) throws -> T) throws -> T {
            guard !self.isAtEnd else { throw Error.decodingError("Unkeyed container is at end", self.codingPath) }
            self.codingPath.append(Key(index: self.currentIndex))
            defer { self.codingPath.removeLast() }
            guard let container = self.decoder.unbox(self.container[self.currentIndex]) else {
                throw Error.decodingError("Expected \(T.self) at \(self.currentIndex), got nil", self.codingPath)
            }
            let value = try block(container)
            self.currentIndex += 1
            return value
        }

        mutating private func unwrap<T>(_ block: (String) -> T?) throws -> T {
            guard let value = try self.checked(block) else {
                throw Error.decodingError("Expected \(T.self) at \(self.currentIndex), got nil", self.codingPath)
            }
            return value
        }

        mutating func decodeNil() throws -> Bool {
            return try self.unwrap { $0.isEmpty }
        }

        mutating func decode(_ type: Bool.Type) throws -> Bool {
            return try self.unwrap(isTrue)
        }

        mutating func decode(_ type: Int.Type) throws -> Int {
            return try self.unwrap(Int.init)
        }

        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            return try self.unwrap(Int8.init)
        }

        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            return try self.unwrap(Int16.init)
        }

        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            return try self.unwrap(Int32.init)
        }

        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            return try self.unwrap(Int64.init)
        }

        mutating func decode(_ type: UInt.Type) throws -> UInt {
            return try self.unwrap(UInt.init)
        }

        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            return try self.unwrap(UInt8.init)
        }

        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            return try self.unwrap(UInt16.init)
        }

        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            return try self.unwrap(UInt32.init)
        }

        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            return try self.unwrap(UInt64.init)
        }

        mutating func decode(_ type: Float.Type) throws -> Float {
            return try self.unwrap(Float.init)
        }

        mutating func decode(_ type: Double.Type) throws -> Double {
            return try self.unwrap(Double.init)
        }

        mutating func decode(_ type: String.Type) throws -> String {
            return try self.unwrap(id)
        }
        
        mutating func decode(_ type: Decimal.Type) throws -> Decimal {
            return try self.unwrap { Decimal(string: $0) ?? Decimal() }
        }

        mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            guard !self.isAtEnd else { throw Error.decodingError("Unkeyed container is at end", self.codingPath) }
            self.codingPath.append(Key(index: self.currentIndex))
            defer { self.codingPath.removeLast() }
            let container = self.container[self.currentIndex]
            self.currentIndex += 1
            self.decoder.containers.append(container)
            defer { self.decoder.containers.removeLast() }
            return try self.decoder.unbox(container, as: T.self)
        }

        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws
        -> KeyedDecodingContainer<NestedKey>
        where NestedKey: CodingKey {

            guard !self.isAtEnd else { throw Error.decodingError("Unkeyed container is at end", self.codingPath) }
            self.codingPath.append(Key(index: self.currentIndex))
            defer { self.codingPath.removeLast() }
            guard case let .keyed(container) = self.container[self.currentIndex] else {
                throw Error.decodingError("Expected value at \(self.currentIndex), got nil", self.codingPath)
            }
            self.currentIndex += 1
            self.decoder.containers.append(.keyed(container)) // FIXME?
            defer { self.decoder.containers.removeLast() }
            return .init(KeyedContainer(decoder: self.decoder, container: container))
        }

        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            guard !self.isAtEnd else { throw Error.decodingError("Unkeyed container is at end", self.codingPath) }
            self.codingPath.append(Key(index: self.currentIndex))
            defer { self.codingPath.removeLast() }
            guard case let .unkeyed(container) = self.container[self.currentIndex] else {
                throw Error.decodingError("Expected value at \(self.currentIndex), got nil", self.codingPath)
            }
            self.currentIndex += 1
            self.decoder.containers.append(.unkeyed(container)) // FIXME?
            defer { self.decoder.containers.removeLast() }
            return UnkeyedContainer(decoder: self.decoder, container: container, codingPath: self.codingPath)
        }

        mutating func superDecoder() throws -> Swift.Decoder {
            guard !self.isAtEnd else { throw Error.decodingError("Unkeyed container is at end", self.codingPath) }
            self.codingPath.append(Key(index: self.currentIndex))
            defer { self.codingPath.removeLast() }
            let container = self.container[self.currentIndex]
            self.currentIndex += 1
            let decoder = PointFreeFormDecoder()
            decoder.containers = [container]
            decoder.codingPath = self.codingPath
            decoder.dataDecodingStrategy = self.decoder.dataDecodingStrategy
            decoder.dateDecodingStrategy = self.decoder.dateDecodingStrategy
            decoder.arrayParsingStrategy = self.decoder.arrayParsingStrategy
            return decoder
        }
    }

    struct SingleValueContainer: SingleValueDecodingContainer {
        let decoder: PointFreeFormDecoder
        let container: Container

        let codingPath: [CodingKey] = []

        private func unwrap<T>(_ block: (String) -> T?, _ line: UInt = #line) throws -> T {
            guard
                case let .singleValue(container) = self.container,
                let value = block(container)
            else { throw Error.decodingError("Expected \(T.self), got nil", self.codingPath) }

            return value
        }

        func decodeNil() -> Bool {
            switch self.container {
            case let .singleValue(string):
                return string.isEmpty
            default:
                return false
            }
        }

        func decode(_ type: Bool.Type) throws -> Bool {
            return try self.unwrap(isTrue)
        }

        func decode(_ type: Int.Type) throws -> Int {
            return try self.unwrap(Int.init)
        }

        func decode(_ type: Int8.Type) throws -> Int8 {
            return try self.unwrap(Int8.init)
        }

        func decode(_ type: Int16.Type) throws -> Int16 {
            return try self.unwrap(Int16.init)
        }

        func decode(_ type: Int32.Type) throws -> Int32 {
            return try self.unwrap(Int32.init)
        }

        func decode(_ type: Int64.Type) throws -> Int64 {
            return try self.unwrap(Int64.init)
        }

        func decode(_ type: UInt.Type) throws -> UInt {
            return try self.unwrap(UInt.init)
        }

        func decode(_ type: UInt8.Type) throws -> UInt8 {
            return try self.unwrap(UInt8.init)
        }

        func decode(_ type: UInt16.Type) throws -> UInt16 {
            return try self.unwrap(UInt16.init)
        }

        func decode(_ type: UInt32.Type) throws -> UInt32 {
            return try self.unwrap(UInt32.init)
        }

        func decode(_ type: UInt64.Type) throws -> UInt64 {
            return try self.unwrap(UInt64.init)
        }

        func decode(_ type: Float.Type) throws -> Float {
            return try self.unwrap(Float.init)
        }

        func decode(_ type: Double.Type) throws -> Double {
            return try self.unwrap(Double.init)
        }

        func decode(_ type: String.Type) throws -> String {
            return try self.unwrap(id)
        }
        
        func decode(_ type: Decimal.Type) throws -> Decimal {
            return try self.unwrap { Decimal(string: $0) ?? Decimal() }
        }

        func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            self.decoder.containers.append(self.container)
            defer { self.decoder.containers.removeLast() }
            return try self.decoder.unbox(self.container, as: T.self)
        }
    }

    /// A strategy for decoding Data values from URL form data.
    ///
    /// You can use one of the built-in strategies or create your own custom strategy.
    ///
    /// ## Built-in Strategies
    /// - ``deferredToData``: Uses Data's default Codable implementation
    /// - ``base64``: Decodes data from base64 string
    ///
    /// ## Custom Strategies
    /// You can create custom strategies by providing your own decoding logic:
    /// ```swift
    /// extension PointFreeFormDecoder.DataDecodingStrategy {
    ///     static let hexDecoding = DataDecodingStrategy { string in
    ///         // Convert hex string to Data
    ///         var data = Data()
    ///         var index = string.startIndex
    ///         while index < string.endIndex {
    ///             let nextIndex = string.index(index, offsetBy: 2, limitedBy: string.endIndex) ?? string.endIndex
    ///             if let byte = UInt8(String(string[index..<nextIndex]), radix: 16) {
    ///                 data.append(byte)
    ///             }
    ///             index = nextIndex
    ///         }
    ///         return data
    ///     }
    /// }
    /// ```
    public struct DataDecodingStrategy: Sendable {
        internal let decode: @Sendable (String) -> Data?
        
        /// Creates a custom data decoding strategy.
        /// - Parameter decode: A closure that takes a string and returns the decoded Data.
        public init(decode: @escaping @Sendable (String) -> Data?) {
            self.decode = decode
        }
        
        /// Defers to Data's default Codable implementation
        public static let deferredToData = DataDecodingStrategy { _ in
            nil // Always return nil to signal deferred implementation
        }
        
        /// Decodes data from base64 string
        public static let base64 = DataDecodingStrategy { string in
            Data(base64Encoded: string)
        }
        
        /// Creates a custom data decoding strategy
        public static func custom(_ strategy: @escaping @Sendable (String) -> Data?) -> DataDecodingStrategy {
            DataDecodingStrategy(decode: strategy)
        }
    }

    /// A strategy for decoding Date values from URL form data.
    ///
    /// You can use one of the built-in strategies or create your own custom strategy.
    ///
    /// ## Built-in Strategies
    /// - ``deferredToDate``: Uses Date's default Codable implementation
    /// - ``secondsSince1970``: Decodes dates as seconds since 1970
    /// - ``millisecondsSince1970``: Decodes dates as milliseconds since 1970
    /// - ``iso8601``: Decodes dates from ISO8601 format
    /// - ``formatted(_:)``: Decodes dates using a custom DateFormatter
    ///
    /// ## Custom Strategies
    /// You can create custom strategies by providing your own decoding logic:
    /// ```swift
    /// extension PointFreeFormDecoder.DateDecodingStrategy {
    ///     static let yearOnly = DateDecodingStrategy { string in
    ///         let formatter = DateFormatter()
    ///         formatter.dateFormat = "yyyy"
    ///         return formatter.date(from: string)
    ///     }
    /// }
    /// ```
    public struct DateDecodingStrategy: Sendable {
        internal let decode: @Sendable (String) -> Date?
        
        /// Creates a custom date decoding strategy.
        /// - Parameter decode: A closure that takes a string and returns the decoded Date.
        public init(decode: @escaping @Sendable (String) -> Date?) {
            self.decode = decode
        }
        
        /// Defers to Date's default Codable implementation
        public static let deferredToDate = DateDecodingStrategy { _ in
            nil // Signal to use deferred implementation
        }
        
        /// Decodes dates as seconds since 1970
        public static let secondsSince1970 = DateDecodingStrategy { string in
            guard let interval = Double(string) else { return nil }
            return Date(timeIntervalSince1970: interval)
        }
        
        /// Decodes dates as milliseconds since 1970
        public static let millisecondsSince1970 = DateDecodingStrategy { string in
            guard let milliseconds = Double(string) else { return nil }
            return Date(timeIntervalSince1970: milliseconds / 1000)
        }
        
        /// Decodes dates from ISO8601 format
        public static let iso8601 = DateDecodingStrategy { string in
            iso8601DateFormatter.date(from: string) 
            ?? iso8601DateFormatterWithoutMilliseconds.date(from: string)
        }
        
        /// Decodes dates using a custom DateFormatter
        public static func formatted(_ formatter: DateFormatter) -> DateDecodingStrategy {
            DateDecodingStrategy { string in
                formatter.date(from: string)
            }
        }
        
        /// Creates a custom date decoding strategy
        public static func custom(_ strategy: @escaping @Sendable (String) -> Date?) -> DateDecodingStrategy {
            DateDecodingStrategy(decode: strategy)
        }
    }

    public enum Container {
        indirect case keyed([String: Container])
        indirect case unkeyed([Container])
        case singleValue(String)

        package var params: [String: Container]? {
            switch self {
            case let .keyed(params):
                return params
            case .unkeyed, .singleValue:
                return nil
            }
        }

        package var values: [Container]? {
            switch self {
            case let .unkeyed(values):
                return values
            case .keyed, .singleValue:
                return nil
            }
        }

        package var value: String? {
            switch self {
            case let .singleValue(value):
                return value
            case .keyed, .unkeyed:
                return nil
            }
        }
    }

    /// A strategy for parsing arrays from URL form data.
    ///
    /// You can use one of the built-in strategies or create your own custom strategy.
    ///
    /// ## Built-in Strategies
    /// - ``accumulateValues``: Accumulates multiple values with the same key
    /// - ``brackets``: Parses bracketed keys for nested structures (empty brackets for arrays)
    /// - ``bracketsWithIndices``: Parses bracketed keys with indices for ordered arrays
    ///
    /// ## Custom Strategies
    /// You can create custom strategies by providing your own parsing logic:
    /// ```swift
    /// extension PointFreeFormDecoder.ArrayParsingStrategy {
    ///     static let customStrategy = ArrayParsingStrategy { query in
    ///         // Your custom parsing logic here
    ///         // Return a Container
    ///     }
    /// }
    /// ```
    public struct ArrayParsingStrategy: Sendable {
        internal let parse: @Sendable (String) -> Container
        internal let handleSingleValue: Bool
        
        /// Creates a custom parsing strategy.
        /// - Parameters:
        ///   - parse: A closure that takes a query string and returns a Container.
        ///   - handleSingleValue: Whether to handle single values specially (default: false).
        public init(parse: @escaping @Sendable (String) -> Container, handleSingleValue: Bool = false) {
            self.parse = parse
            self.handleSingleValue = handleSingleValue
        }
        
        /// A parsing strategy that accumulates values when multiple keys are provided.
        ///
        ///     ids=1&ids=2
        ///     // Parsed as ["ids": ["1", "2"]]
        ///
        /// Wherever the decoder expects a single value (rather than an array), it will use the _last_ value
        /// given.
        ///
        /// - Note: This parsing strategy is "flat" and cannot decode deeper structures.
        public static let accumulateValues = ArrayParsingStrategy(
            parse: PointFreeFormDecoder.accumulateValuesParser,
            handleSingleValue: true
        )

        /// A parsing strategy that uses keys with a bracketed suffix to produce nested structures.
        ///
        /// Keyed, nested structures name each key in brackets.
        ///
        ///     user[name]=Blob&user[email]=blob@pointfree.co
        ///     // Parsed as ["user": ["name": "Blob", "email": "blob@pointfree.co"]]
        ///
        /// Unkeyed, nested structures leave the brackets empty and accumulate single values.
        ///
        ///     ids[]=1&ids[]=2
        ///     // Parsed as ["ids": ["1", "2"]]
        ///
        /// Series of brackets can create deeply-nested structures.
        ///
        ///     user[pets][][id]=1&user[pets][][id]=2
        ///     // Parsed as ["user": ["pets": [["id": "1"], ["id": "2"]]]]
        ///
        /// - Note: Unkeyed brackets do not specify collection indices, so they cannot accumulate complex
        ///   structures by using multiple keys. See `bracketsWithIndices` as an alternative parsing strategy.
        public static let brackets = ArrayParsingStrategy(
            parse: PointFreeFormDecoder.parse(isArray: { $0.isEmpty })
        )

        /// A parsing strategy that uses keys with a bracketed suffix to produce nested structures.
        ///
        /// Keyed, nested structures name each key in brackets.
        ///
        ///     user[name]=Blob&user[email]=blob@pointfree.co
        ///     // Parsed as ["user": ["name": "Blob", "email": "blob@pointfree.co"]]
        ///
        /// Unkeyed, nested structures name each collection index in brackets and accumulate values.
        ///
        ///     ids[1]=2&ids[0]=1
        ///     // Parsed as ["ids": ["1", "2"]]
        ///
        /// Series of brackets can create deeply-nested structures that accumulate over multiple keys.
        ///
        ///     user[pets][0][id]=1&user[pets][0][name]=Fido
        ///     // Parsed as ["user": ["pets": [["id": "1"], ["name": "Fido"]]]]
        public static let bracketsWithIndices = ArrayParsingStrategy(
            parse: PointFreeFormDecoder.parse(isArray: { Int($0) != nil }, sort: true)
        )
        
        /// Creates a custom parsing strategy with a custom function.
        /// This is provided for backward compatibility.
        public static func custom(_ parseFunction: @escaping @Sendable (String) -> Container) -> ArrayParsingStrategy {
            return ArrayParsingStrategy(parse: parseFunction)
        }
    }
}

extension PointFreeFormDecoder.UnkeyedContainer.Key: CodingKey {
    public var stringValue: String {
        return String(self.index)
    }

    public init?(stringValue: String) {
        guard let intValue = Int(stringValue) else { return nil }
        self.init(intValue: intValue)
    }

    public var intValue: Int? {
        return .some(self.index)
    }

    public init?(intValue: Int) {
        self.init(index: intValue)
    }
}

nonisolated(unsafe) private let iso8601: (DateFormatter) -> DateFormatter = { formatter in
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(abbreviation: "GMT")
    return formatter
}

private let iso8601DateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    let formatted = iso8601(formatter)
    formatted.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
    return formatted
}()

private let iso8601DateFormatterWithoutMilliseconds: DateFormatter = {
    let formatter = DateFormatter()
    let formatted = iso8601(formatter)
    formatted.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
    return formatted
}()

private extension PointFreeFormDecoder {
    @Sendable
    static func parse(isArray: @escaping @Sendable (String) -> Bool, sort: Bool = false) -> @Sendable (String) -> Container {

    @Sendable func parseHelp(_ container: inout PointFreeFormDecoder.Container, _ path: [String], _ value: String) {
        switch container {
        case .keyed(let originalParams):
            var params = originalParams
            let key = path[0]
            if path.count == 1 {
                let valueContainer = PointFreeFormDecoder.Container.singleValue(value)
                params[key] = valueContainer
            } else if path.count == 2, isArray(path[1]) {
                var values = params[key]?.values ?? []
                let valueContainer = PointFreeFormDecoder.Container.singleValue(value)
                values.append(valueContainer)
                params[key] = .unkeyed(values)
            } else if isArray(path[1]) {
                // Check if it's an empty bracket (accumulate) or indexed bracket
                if path[1].isEmpty {
                    // Empty brackets - accumulate values
                    var values = params[key]?.values ?? []
                    
                    if path.count > 2 {
                        // Create a new keyed container for this array element
                        var newContainer = PointFreeFormDecoder.Container.keyed([:])
                        parseHelp(&newContainer, Array(path[2...]), value)
                        values.append(newContainer)
                    } else {
                        // This is a direct value
                        values.append(.singleValue(value))
                    }
                    
                    params[key] = .unkeyed(values)
                } else {
                    // Indexed arrays - use specific index
                    let index = Int(path[1]) ?? 0
                    var values = params[key]?.values ?? []
                    
                    // Expand array if needed
                    while values.count <= index {
                        values.append(.keyed([:]))
                    }
                    
                    // If we have more path components, recurse into the specific index
                    if path.count > 2 {
                        parseHelp(&values[index], Array(path[2...]), value)
                    } else {
                        // This is the final value
                        values[index] = .singleValue(value)
                    }
                    
                    params[key] = .unkeyed(values)
                }
            } else {
                var values = PointFreeFormDecoder.Container.keyed(params[key]?.params ?? [:])
                parseHelp(&values, Array(path[1...]), value)
                params[key] = values
            }
            container = .keyed(params)
        case .unkeyed(let originalValues):
            var values = originalValues
            if path.count == 1 {
                let valueContainer = PointFreeFormDecoder.Container.singleValue(value)
                values.append(valueContainer)
            } else if isArray(path[1]) {
                // For indexed arrays, we need to ensure we have enough elements
                let index = Int(path[1]) ?? 0
                
                // Expand array if needed
                while values.count <= index {
                    values.append(.keyed([:]))
                }
                
                // Recursively parse into the element at the specific index
                parseHelp(&values[index], Array(path[2...]), value)
            } else {
                var params = PointFreeFormDecoder.Container.keyed([:])
                parseHelp(&params, Array(path[1...]), value)
                values.append(params)
            }
            container = .unkeyed(values)
        case .singleValue:
            fatalError()
        }
    }

    return { query in
        var params = PointFreeFormDecoder.Container.keyed([:])

        for (name, value) in pairs(query, sort: sort) {
            let result = name.reduce(into: (path: [] as [String], current: "")) { result, char in
                switch char {
                case "[":
                    if result.path.isEmpty {
                        result.path.append(result.current)
                        result.current.removeAll()
                    }
                case "]":
                    result.path.append(result.current)
                    result.current.removeAll()
                default:
                    result.current.append(char)
                }
            }
            let path = result.current.isEmpty ? result.path : result.path + [result.current]
            parseHelp(&params, path.isEmpty ? [""] : path, value ?? "")
        }

        return params
    }
    }
    
    @Sendable
    static func accumulateValuesParser(_ query: String) -> Container {
        var params: [String: Container] = [:]
        for (name, value) in pairs(query) {
            if var values = params[name]?.values {
                values.append(.singleValue(value ?? ""))
                params[name] = .unkeyed(values)
            } else if params[name] != nil {
                params[name] = .unkeyed([params[name]!, .singleValue(value ?? "")])
            } else {
                params[name] = .singleValue(value ?? "")
            }
        }
        return .keyed(params)
    }
}

private func pairs(_ query: String, sort: Bool = false) -> [(String, String?)] {
    let pairs = query
        .split(separator: "&")
        .map { (pairString: Substring) -> (name: String, value: String?) in
            let pairArray = pairString.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                .compactMap(
                    String.init
                    >>> { WHATWG_URL_Encoding.percentDecode($0, plusAsSpace: true) }
                )
            return (pairArray[0], pairArray.count == 2 ? pairArray[1] : nil)
        }

    return sort ? pairs.sorted { $0.name < $1.name } : pairs
}

private let truths: Set<String> = ["1", "true"]

private func isTrue(_ string: String) -> Bool {
    return truths.contains(string.lowercased())
}
