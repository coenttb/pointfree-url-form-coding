//
//  TestModels.swift
//  URLFormCoding Tests
//
//  Created by Coen ten Thije Boonkkamp on 26/07/2025.
//

import Foundation

// MARK: - Shared Test Models

struct BasicUser: Codable, Equatable {
    let name: String
    let age: Int
    let isActive: Bool
}

struct NestedUser: Codable, Equatable {
    let name: String
    let profile: Profile

    struct Profile: Codable, Equatable {
        let bio: String
        let website: String?
    }
}

struct UserWithArrays: Codable, Equatable {
    let name: String
    let tags: [String]
    let scores: [Int]
}

struct UserWithOptionals: Codable, Equatable {
    let name: String
    let email: String?
    let age: Int?
    let isVerified: Bool?
}

struct UserWithDates: Codable, Equatable {
    let name: String
    let createdAt: Date
    let lastLogin: Date?
}

struct UserWithData: Codable, Equatable {
    let name: String
    let avatar: Data
    let thumbnail: Data?
}
