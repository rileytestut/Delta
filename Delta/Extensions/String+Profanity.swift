//
//  String+Profanity.swift
//  Delta
//
//  Created by Riley Testut on 12/4/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//
//  Based on IslandOfDoom's IODProfanityFilter ( https://github.com/IslandOfDoom/IODProfanityFilter )
//

import Foundation

extension String
{
    private static var naughtyWords: Set = {
        do
        {
            let fileURL = Bundle.main.url(forResource: "Profanity", withExtension: "txt")!
            let wordList = try String(contentsOf: fileURL, encoding: .utf8)
            
            let words = wordList.components(separatedBy: .newlines)
            return Set(words)
        }
        catch
        {
            fatalError("Failed to load Profanity.txt. \(error.localizedDescription)")
        }
    }()
    
    var containsProfanity: Bool {
        let scanner = Scanner(string: self)
        
        let wordCharacters = NSCharacterSet.alphanumerics
        let nonWordCharacters = wordCharacters.inverted
        
        while !scanner.isAtEnd
        {
            if let scanned = scanner.scanCharacters(from: wordCharacters)
            {
                // Found a word, look it up in the word set
                if String.naughtyWords.contains(scanned.lowercased())
                {
                    // Naughty word exists, return true
                    return true
                }
            }
            else
            {
                // Skip over non-word characters
                _ = scanner.scanCharacters(from: nonWordCharacters)
            }
        }
        
        return false
    }
}
