//
//  File.swift
//  pointfree-url-form-coding
//
//  Created by Coen ten Thije Boonkkamp on 26/07/2025.
//

import Foundation

extension CharacterSet {
    @usableFromInline
    static let urlQueryParamAllowed = CharacterSet
        .urlQueryAllowed
        .subtracting(Self(charactersIn: ":#[]@!$&'()*+,;="))
}
