//
//  CharacterSet+Filename.swift
//  Delta
//
//  Created by Riley Testut on 4/28/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import Foundation

extension CharacterSet
{
    // Different than .urlPathAllowed
    // Copied from https://stackoverflow.com/a/39443252
    static var urlFilenameAllowed: CharacterSet {
        var illegalCharacters = CharacterSet(charactersIn: ":/")
        illegalCharacters.formUnion(.newlines)
        illegalCharacters.formUnion(.illegalCharacters)
        illegalCharacters.formUnion(.controlCharacters)
        return illegalCharacters.inverted
    }
}
