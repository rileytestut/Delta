//
//  CharacterSet+Hexadecimals.swift
//  DeltaCore
//
//  Created by Riley Testut on 4/30/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

// Extend NSCharacterSet for Objective-C interopability.
public extension NSCharacterSet
{
    @objc(hexadecimalCharacterSet)
    class var hexadecimals: NSCharacterSet
    {
        let characterSet = NSCharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        return characterSet
    }
}

public extension NSMutableCharacterSet
{
    @objc(hexadecimalCharacterSet)
    override class var hexadecimals: NSMutableCharacterSet
    {
        let characterSet = NSCharacterSet.hexadecimals.mutableCopy() as! NSMutableCharacterSet
        return characterSet
    }
}

public extension CharacterSet
{
    static var hexadecimals: CharacterSet
    {
        return NSCharacterSet.hexadecimals as CharacterSet
    }
}
