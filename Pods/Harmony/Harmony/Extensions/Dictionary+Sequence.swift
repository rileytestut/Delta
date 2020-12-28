//
//  Dictionary+Sequence.swift
//  Harmony
//
//  Created by Riley Testut on 11/8/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation

extension Dictionary
{
    init<S: Sequence>(_ sequence: S, keyedBy keyPath: KeyPath<Value, Key>) where S.Element == Value
    {
        let dictionary = Dictionary(sequence.lazy.map { ($0[keyPath: keyPath], $0) }, uniquingKeysWith: { (first, last) in last })
        self = dictionary
    }
    
    init<S: Sequence>(_ sequence: S, keyedBy closure: @escaping (Value) -> Key) where S.Element == Value
    {
        let dictionary = Dictionary(sequence.lazy.map { (closure($0), $0) }, uniquingKeysWith: { (first, last) in last })
        self = dictionary
    }
}
