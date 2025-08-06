import Foundation

extension PointFreeFormDecoder {
    /// Attempts to detect the parsing strategy from the encoded data
    public static func detectStrategy(from data: Data) -> ArrayParsingStrategy? {
        guard let string = String(data: data, encoding: .utf8) else { return nil }
        
        // Check for bracketsWithIndices pattern: field[0]=value, field[1]=value
        if string.contains("[0]") || string.contains("[1]") || string.contains("[2]") {
            return .bracketsWithIndices
        }
        
        // Check for brackets (empty) pattern: field[]=value
        if string.contains("[]") {
            return .brackets
        }
        
        // Check for accumulate values pattern: field=value1&field=value2
        let components = string.split(separator: "&")
        var seenKeys = Set<String>()
        var duplicateKeys = Set<String>()
        
        for component in components {
            if let equalIndex = component.firstIndex(of: "=") {
                let key = String(component[..<equalIndex])
                // Remove any bracket notation for this check
                let cleanKey = key.split(separator: "[").first.map(String.init) ?? key
                if seenKeys.contains(cleanKey) {
                    duplicateKeys.insert(cleanKey)
                }
                seenKeys.insert(cleanKey)
            }
        }
        
        if !duplicateKeys.isEmpty {
            return .accumulateValues
        }
        
        // Default to accumulate values for simple cases
        return .accumulateValues
    }
    
    /// Creates a decoder with auto-detected parsing strategy
    public static func withAutoDetectedStrategy(
        from data: Data,
        dataDecodingStrategy: DataDecodingStrategy = .deferredToData,
        dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
    ) -> PointFreeFormDecoder {
        let strategy = detectStrategy(from: data) ?? .accumulateValues
        return PointFreeFormDecoder(
            dataDecodingStrategy: dataDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            arrayParsingStrategy: strategy
        )
    }
    
    /// Convenience method to decode with auto-detected strategy
    public static func decodeWithAutoDetection<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        dataDecodingStrategy: DataDecodingStrategy = .deferredToData,
        dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
    ) throws -> T {
        let decoder = withAutoDetectedStrategy(
            from: data,
            dataDecodingStrategy: dataDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy
        )
        return try decoder.decode(type, from: data)
    }
}