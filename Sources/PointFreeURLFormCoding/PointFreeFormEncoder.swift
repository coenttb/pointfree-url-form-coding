import Foundation

/// An encoder that converts Swift Codable types to URL-encoded form data.
///
/// `PointFreeFormEncoder` implements the `Encoder` protocol to provide seamless
/// conversion from Swift types to `application/x-www-form-urlencoded` format,
/// the standard format used by HTML forms and many web APIs.
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
/// let encoder = PointFreeFormEncoder()
/// let user = User(name: "John Doe", age: 30, isActive: true)
/// let formData = try encoder.encode(user)
/// // Result: "name=John%20Doe&age=30&isActive=true"
/// ```
///
/// ## Configuration Options
///
/// The encoder supports various encoding strategies:
/// - **Date encoding**: ISO8601, seconds since 1970, milliseconds, custom formats
/// - **Data encoding**: Base64 or custom strategies
/// - **Array encoding**: Multiple strategies for handling arrays
///   - `.accumulateValues`: field=value1&field=value2
///   - `.brackets`: field[]=value1&field[]=value2 (PHP/Rails style)
///   - `.bracketsWithIndices`: field[0]=value1&field[1]=value2
///
/// ```swift
/// let encoder = PointFreeFormEncoder()
/// encoder.dateEncodingStrategy = .iso8601
/// encoder.dataEncodingStrategy = .base64
/// encoder.encodingStrategy = .brackets // For PHP/Rails compatibility
/// ```
///
/// ## Advanced Features
///
/// - Supports nested objects and arrays
/// - Configurable encoding strategies for different data types
/// - Thread-safe encoding operations
/// - Comprehensive error reporting
///
/// - Note: This encoder is designed to work with ``PointFreeFormDecoder`` for round-trip compatibility.
/// - Important: Ensure encoding strategies match your server's expected format.
public final class PointFreeFormEncoder: Swift.Encoder {
    private var container: Container?
    public private(set) var codingPath: [CodingKey] = []
    public var dataEncodingStrategy: PointFreeFormEncoder.DataEncodingStrategy
    public var dateEncodingStrategy: PointFreeFormEncoder.DateEncodingStrategy
    public var arrayEncodingStrategy: PointFreeFormEncoder.ArrayEncodingStrategy
    public let userInfo: [CodingUserInfoKey: Any] = [:]

    public init(
        dataEncodingStrategy: PointFreeFormEncoder.DataEncodingStrategy = .deferredToData,
        dateEncodingStrategy: PointFreeFormEncoder.DateEncodingStrategy = .deferredToDate,
        arrayEncodingStrategy: PointFreeFormEncoder.ArrayEncodingStrategy = .accumulateValues
    ) {
        self.dataEncodingStrategy = dataEncodingStrategy
        self.dateEncodingStrategy = dateEncodingStrategy
        self.arrayEncodingStrategy = arrayEncodingStrategy
    }

    public func encode<T: Encodable>(_ value: T) throws -> Data {
        try value.encode(to: self)
        guard let container = self.container else {
            throw Error.encodingError("No container found", self.codingPath)
        }

        let queryString = serialize(container, strategy: self.arrayEncodingStrategy)
        return Data(queryString.utf8)
    }

    private func box<T: Encodable>(_ value: T) throws -> Container {
        if let date = value as? Date {
            return try self.box(date)
        } else if let data = value as? Data {
            return try self.box(data)
        } else if let decimal = value as? Decimal {
            // Handle Decimal specially to avoid its complex internal encoding
            return .singleValue(String(describing: decimal))
        }

        let encoder = PointFreeFormEncoder(
            dataEncodingStrategy: self.dataEncodingStrategy,
            dateEncodingStrategy: self.dateEncodingStrategy,
            arrayEncodingStrategy: self.arrayEncodingStrategy
        )
        try value.encode(to: encoder)
        guard let container = encoder.container else {
            throw Error.encodingError("No container found", encoder.codingPath)
        }
        return container
    }

    private func box(_ date: Date) throws -> Container {
        // Check if using deferredToDate by looking for the special marker
        let result = self.dateEncodingStrategy.encode(date)
        
        if result == "__DEFERRED_TO_DATE__" {
            let encoder = PointFreeFormEncoder(
                dataEncodingStrategy: self.dataEncodingStrategy,
                dateEncodingStrategy: self.dateEncodingStrategy,
                arrayEncodingStrategy: self.arrayEncodingStrategy
            )
            try date.encode(to: encoder)
            guard let container = encoder.container else {
                throw Error.encodingError("No container found", encoder.codingPath)
            }
            return container
        } else {
            return .singleValue(result)
        }
    }

    private func box(_ data: Data) throws -> Container {
        // Check if using deferredToData by looking for the special marker
        let result = self.dataEncodingStrategy.encode(data)
        
        if result == "__DEFERRED_TO_DATA__" {
            let encoder = PointFreeFormEncoder()
            try data.encode(to: encoder)
            guard let container = encoder.container else {
                throw Error.encodingError("No container found", encoder.codingPath)
            }
            return container
        } else {
            return .singleValue(result)
        }
    }

    public func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let container = KeyedContainer<Key>(encoder: self)
        self.container = .keyed([:])
        return KeyedEncodingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        let container = UnkeyedContainer(encoder: self)
        self.container = .unkeyed([])
        return container
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        let container = SingleValueContainer(encoder: self)
        self.container = nil
        return container
    }

    public enum Error: Swift.Error, CustomStringConvertible {
        case encodingError(String, [CodingKey])
        
        public var description: String {
            switch self {
            case let .encodingError(message, path):
                let pathString = path.map { $0.stringValue }.joined(separator: ".")
                let location = pathString.isEmpty ? "" : " at path '\(pathString)'"
                return "\(message)\(location)"
            }
        }
    }

    struct KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
        private let encoder: PointFreeFormEncoder

        var codingPath: [CodingKey] {
            return self.encoder.codingPath
        }

        init(encoder: PointFreeFormEncoder) {
            self.encoder = encoder
        }

        mutating func encodeNil(forKey key: Key) throws {
            var container = self.encoder.container?.params ?? [:]
            container[key.stringValue] = .singleValue("")
            self.encoder.container = .keyed(container)
        }

        mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
            self.encoder.codingPath.append(key)
            defer { self.encoder.codingPath.removeLast() }
            var container = self.encoder.container?.params ?? [:]
            container[key.stringValue] = try self.encoder.box(value)
            self.encoder.container = .keyed(container)
        }

        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            self.encoder.codingPath.append(key)
            defer { self.encoder.codingPath.removeLast() }
            let container = KeyedContainer<NestedKey>(encoder: self.encoder)
            var params = self.encoder.container?.params ?? [:]
            params[key.stringValue] = .keyed([:])
            self.encoder.container = .keyed(params)
            return KeyedEncodingContainer(container)
        }

        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            self.encoder.codingPath.append(key)
            defer { self.encoder.codingPath.removeLast() }
            let container = UnkeyedContainer(encoder: self.encoder)
            var params = self.encoder.container?.params ?? [:]
            params[key.stringValue] = .unkeyed([])
            self.encoder.container = .keyed(params)
            return container
        }

        mutating func superEncoder() -> Swift.Encoder {
            fatalError("Not implemented")
        }

        mutating func superEncoder(forKey key: Key) -> Swift.Encoder {
            fatalError("Not implemented")
        }
    }

    struct UnkeyedContainer: UnkeyedEncodingContainer {
        private let encoder: PointFreeFormEncoder

        var codingPath: [CodingKey] {
            return self.encoder.codingPath
        }

        var count: Int {
            return self.encoder.container?.values?.count ?? 0
        }

        init(encoder: PointFreeFormEncoder) {
            self.encoder = encoder
        }

        mutating func encodeNil() throws {
            var values = self.encoder.container?.values ?? []
            values.append(.singleValue(""))
            self.encoder.container = .unkeyed(values)
        }

        mutating func encode<T>(_ value: T) throws where T: Encodable {
            var values = self.encoder.container?.values ?? []
            values.append(try self.encoder.box(value))
            self.encoder.container = .unkeyed(values)
        }

        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            let container = KeyedContainer<NestedKey>(encoder: self.encoder)
            var values = self.encoder.container?.values ?? []
            values.append(.keyed([:]))
            self.encoder.container = .unkeyed(values)
            return KeyedEncodingContainer(container)
        }

        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            let container = UnkeyedContainer(encoder: self.encoder)
            var values = self.encoder.container?.values ?? []
            values.append(.unkeyed([]))
            self.encoder.container = .unkeyed(values)
            return container
        }

        mutating func superEncoder() -> Swift.Encoder {
            fatalError("Not implemented")
        }
    }

    struct SingleValueContainer: SingleValueEncodingContainer {
        private let encoder: PointFreeFormEncoder

        var codingPath: [CodingKey] = []

        init(encoder: PointFreeFormEncoder) {
            self.encoder = encoder
        }

        mutating func encodeNil() throws {
            self.encoder.container = .singleValue("")
        }

        mutating func encode(_ value: Bool) throws {
            try encode(value ? "true" : "false")
        }

        mutating func encode(_ value: String) throws {
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryParamAllowed) ?? value
            self.encoder.container = .singleValue(encoded)
        }

        mutating func encode(_ value: Double) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: Float) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: Int) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: Int8) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: Int16) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: Int32) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: Int64) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: UInt) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: UInt8) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: UInt16) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: UInt32) throws {
            try encode(String(value))
        }

        mutating func encode(_ value: UInt64) throws {
            try encode(String(value))
        }

        mutating func encode<T>(_ value: T) throws where T: Encodable {
            if let strValue = value as? String {
                try encode(strValue)
            } else {
                // Instead of using String(describing:) which can fail for certain types,
                // we need to properly encode the value through the encoder
                self.encoder.container = try self.encoder.box(value)
            }
        }
    }

    /// A strategy for encoding Data values in URL form data.
    ///
    /// You can use one of the built-in strategies or create your own custom strategy.
    ///
    /// ## Built-in Strategies
    /// - ``deferredToData``: Uses Data's default Codable implementation
    /// - ``base64``: Encodes data as base64 string
    ///
    /// ## Custom Strategies
    /// You can create custom strategies by providing your own encoding logic:
    /// ```swift
    /// extension PointFreeFormEncoder.DataEncodingStrategy {
    ///     static let hexEncoding = DataEncodingStrategy { data in
    ///         data.map { String(format: "%02x", $0) }.joined()
    ///     }
    /// }
    /// ```
    public struct DataEncodingStrategy: Sendable {
        internal let encode: @Sendable (Data) -> String
        
        /// Creates a custom data encoding strategy.
        /// - Parameter encode: A closure that takes Data and returns the encoded string.
        public init(encode: @escaping @Sendable (Data) -> String) {
            self.encode = encode
        }
        
        /// Defers to Data's default Codable implementation
        public static let deferredToData = DataEncodingStrategy { data in
            // Return a special marker that indicates deferred encoding
            "__DEFERRED_TO_DATA__"
        }
        
        /// Encodes data as base64 string
        public static let base64 = DataEncodingStrategy { data in
            data.base64EncodedString()
        }
        
        /// Creates a custom data encoding strategy
        public static func custom(_ strategy: @escaping @Sendable (Data) -> String) -> DataEncodingStrategy {
            DataEncodingStrategy(encode: strategy)
        }
    }

    /// A strategy for encoding Date values in URL form data.
    ///
    /// You can use one of the built-in strategies or create your own custom strategy.
    ///
    /// ## Built-in Strategies
    /// - ``deferredToDate``: Uses Date's default Codable implementation
    /// - ``secondsSince1970``: Encodes dates as seconds since 1970
    /// - ``millisecondsSince1970``: Encodes dates as milliseconds since 1970
    /// - ``iso8601``: Encodes dates in ISO8601 format
    /// - ``formatted(_:)``: Encodes dates using a custom DateFormatter
    ///
    /// ## Custom Strategies
    /// You can create custom strategies by providing your own encoding logic:
    /// ```swift
    /// extension PointFreeFormEncoder.DateEncodingStrategy {
    ///     static let yearOnly = DateEncodingStrategy { date in
    ///         let formatter = DateFormatter()
    ///         formatter.dateFormat = "yyyy"
    ///         return formatter.string(from: date)
    ///     }
    /// }
    /// ```
    public struct DateEncodingStrategy: Sendable {
        internal let encode: @Sendable (Date) -> String
        
        /// Creates a custom date encoding strategy.
        /// - Parameter encode: A closure that takes a Date and returns the encoded string.
        public init(encode: @escaping @Sendable (Date) -> String) {
            self.encode = encode
        }
        
        /// Defers to Date's default Codable implementation
        public static let deferredToDate = DateEncodingStrategy { _ in
            "__DEFERRED_TO_DATE__" // Special marker for deferred encoding
        }
        
        /// Encodes dates as seconds since 1970
        public static let secondsSince1970 = DateEncodingStrategy { date in
            String(Int(date.timeIntervalSince1970))
        }
        
        /// Encodes dates as milliseconds since 1970
        public static let millisecondsSince1970 = DateEncodingStrategy { date in
            String(Int(date.timeIntervalSince1970 * 1000))
        }
        
        /// Encodes dates in ISO8601 format
        public static let iso8601 = DateEncodingStrategy { date in
            iso8601DateFormatter.string(from: date)
        }
        
        /// Encodes dates using a custom DateFormatter
        public static func formatted(_ formatter: DateFormatter) -> DateEncodingStrategy {
            DateEncodingStrategy { date in
                formatter.string(from: date)
            }
        }
        
        /// Creates a custom date encoding strategy
        public static func custom(_ strategy: @escaping @Sendable (Date) -> String) -> DateEncodingStrategy {
            DateEncodingStrategy(encode: strategy)
        }
    }

    public enum Container {
        indirect case keyed([String: Container])
        indirect case unkeyed([Container])
        case singleValue(String)

        var params: [String: Container]? {
            switch self {
            case let .keyed(params):
                return params
            case .unkeyed, .singleValue:
                return nil
            }
        }

        var values: [Container]? {
            switch self {
            case let .unkeyed(values):
                return values
            case .keyed, .singleValue:
                return nil
            }
        }

        var value: String? {
            switch self {
            case let .singleValue(value):
                return value
            case .keyed, .unkeyed:
                return nil
            }
        }
    }
    
    /// A strategy for encoding arrays in URL form data.
    ///
    /// You can use one of the built-in strategies or create your own custom strategy.
    ///
    /// ## Built-in Strategies
    /// - ``accumulateValues``: Repeats keys for array values (tags=swift&tags=ios)
    /// - ``brackets``: Uses empty brackets (tags[]=swift&tags[]=ios)
    /// - ``bracketsWithIndices``: Uses indexed brackets (tags[0]=swift&tags[1]=ios)
    ///
    /// ## Custom Strategies
    /// You can create custom strategies by providing your own encoding logic:
    /// ```swift
    /// extension PointFreeFormEncoder.ArrayEncodingStrategy {
    ///     static let customStrategy = ArrayEncodingStrategy { container, prefix in
    ///         // Your custom encoding logic here
    ///     }
    /// }
    /// ```
    public struct ArrayEncodingStrategy: Sendable {
        internal let encode: @Sendable (Container, String) -> String
        
        /// Creates a custom encoding strategy.
        /// - Parameter encode: A closure that takes a container and prefix, and returns the encoded string.
        public init(encode: @escaping @Sendable (Container, String) -> String) {
            self.encode = encode
        }
        
        /// Accumulate values strategy encodes arrays as repeated keys
        /// Example: tags=swift&tags=ios&tags=server
        public static let accumulateValues = ArrayEncodingStrategy { container, prefix in
            serializeWithStrategy(container, prefix: prefix, arrayHandler: .accumulate)
        }
        
        /// Brackets strategy encodes arrays with empty brackets
        /// Example: tags[]=swift&tags[]=ios&tags[]=server
        public static let brackets = ArrayEncodingStrategy { container, prefix in
            serializeWithStrategy(container, prefix: prefix, arrayHandler: .brackets)
        }
        
        /// Brackets with indices strategy encodes arrays with indexed brackets
        /// Example: tags[0]=swift&tags[1]=ios&tags[2]=server
        public static let bracketsWithIndices = ArrayEncodingStrategy { container, prefix in
            serializeWithStrategy(container, prefix: prefix, arrayHandler: .bracketsWithIndices)
        }
    }
}

private func serialize(_ container: PointFreeFormEncoder.Container, strategy: PointFreeFormEncoder.ArrayEncodingStrategy, prefix: String = "") -> String {
    return strategy.encode(container, prefix)
}

// Helper enum for array handling strategies
private enum ArrayHandler {
    case accumulate
    case brackets
    case bracketsWithIndices
}

// Helper function that implements the core serialization logic
private func serializeWithStrategy(_ container: PointFreeFormEncoder.Container, prefix: String, arrayHandler: ArrayHandler) -> String {
    switch container {
    case let .keyed(dict):
        return dict.sorted(by: { $0.key < $1.key }).map { key, value in
            let newPrefix = prefix.isEmpty ? key : "\(prefix)[\(key)]"
            return serializeWithStrategy(value, prefix: newPrefix, arrayHandler: arrayHandler)
        }.joined(separator: "&")

    case let .unkeyed(array):
        switch arrayHandler {
        case .accumulate:
            // For accumulate values, repeat the key for each value
            return array.map { value in
                serializeWithStrategy(value, prefix: prefix, arrayHandler: arrayHandler)
            }.joined(separator: "&")
            
        case .brackets:
            // For brackets, use empty bracket notation
            return array.map { value in
                let newPrefix = "\(prefix)[]"
                return serializeWithStrategy(value, prefix: newPrefix, arrayHandler: arrayHandler)
            }.joined(separator: "&")
            
        case .bracketsWithIndices:
            // For brackets with indices, use indexed notation
            return array.enumerated().map { idx, value in
                let newPrefix = "\(prefix)[\(idx)]"
                return serializeWithStrategy(value, prefix: newPrefix, arrayHandler: arrayHandler)
            }.joined(separator: "&")
        }

    case let .singleValue(value):
        return prefix.isEmpty ? value : "\(prefix)=\(value)"
    }
}

private let iso8601DateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(abbreviation: "GMT")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
    return formatter
}()
