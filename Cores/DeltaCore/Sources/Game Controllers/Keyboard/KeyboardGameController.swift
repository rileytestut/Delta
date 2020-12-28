//
//  KeyboardGameController.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/14/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit

public extension GameControllerInputType
{
    static let keyboard = GameControllerInputType("keyboard")
}

extension KeyboardGameController
{
    public struct Input: Hashable, RawRepresentable, Codable
    {
        public let rawValue: String
        
        public init(rawValue: String)
        {
            self.rawValue = rawValue
        }
        
        public init(_ rawValue: String)
        {
            self.rawValue = rawValue
        }
    }
}

extension KeyboardGameController.Input: Input
{
    public var type: InputType {
        return .controller(.keyboard)
    }
    
    public init(stringValue: String)
    {
        self.init(rawValue: stringValue)
    }
}

public extension KeyboardGameController.Input
{
    static let up = KeyboardGameController.Input("up")
    static let down = KeyboardGameController.Input("down")
    static let left = KeyboardGameController.Input("left")
    static let right = KeyboardGameController.Input("right")
    
    static let escape = KeyboardGameController.Input("escape")
    
    static let shift = KeyboardGameController.Input("shift")
    static let command = KeyboardGameController.Input("command")
    static let option = KeyboardGameController.Input("option")
    static let control = KeyboardGameController.Input("control")
    static let capsLock = KeyboardGameController.Input("capsLock")
    
    static let space = KeyboardGameController.Input("space")
    static let `return` = KeyboardGameController.Input("return")
    static let tab = KeyboardGameController.Input("tab")
}

public class KeyboardGameController: UIResponder, GameController
{
    public var name: String {
        return NSLocalizedString("Keyboard", comment: "")
    }
    
    public var playerIndex: Int?
    
    public let inputType: GameControllerInputType = .keyboard
    
    public private(set) lazy var defaultInputMapping: GameControllerInputMappingProtocol? = {
        guard let fileURL = Bundle.resources.url(forResource: "KeyboardGameController", withExtension: "deltamapping") else {
            fatalError("KeyboardGameController.deltamapping does not exist.")
        }
        
        do
        {
            let inputMapping = try GameControllerInputMapping(fileURL: fileURL)
            return inputMapping
        }
        catch
        {
            print(error)
            
            fatalError("KeyboardGameController.deltamapping does not exist.")
        }
    }()
}

public extension KeyboardGameController
{
    override func keyPressesBegan(_ presses: Set<KeyPress>, with event: UIEvent)
    {
        for press in presses
        {
            let input = Input(press.key)
            self.activate(input)
        }
    }
    
    override func keyPressesEnded(_ presses: Set<KeyPress>, with event: UIEvent)
    {
        for press in presses
        {
            let input = Input(press.key)
            self.deactivate(input)
        }
    }
}
