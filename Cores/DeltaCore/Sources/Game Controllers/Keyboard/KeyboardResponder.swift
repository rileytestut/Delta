//
//  KeyboardResponder.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/14/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit
import ObjectiveC

public extension UIResponder
{
    @objc func keyPressesBegan(_ presses: Set<KeyPress>, with event: UIEvent)
    {
        self.next?.keyPressesBegan(presses, with: event)
    }
    
    @objc func keyPressesEnded(_ presses: Set<KeyPress>, with event: UIEvent)
    {
        self.next?.keyPressesEnded(presses, with: event)
    }
}

private extension UIResponder
{
    @objc(_keyCommandForEvent:target:)
    @NSManaged func _keyCommand(for event: UIEvent, target: UnsafeMutablePointer<UIResponder>) -> UIKeyCommand?
}

@objc public class KeyPress: NSObject
{
    public fileprivate(set) var key: String
    public fileprivate(set) var keyCode: Int
    
    public fileprivate(set) var modifierFlags: UIKeyModifierFlags
    
    public fileprivate(set) var isActive: Bool = true
    
    fileprivate init(key: String, keyCode: Int, modifierFlags: UIKeyModifierFlags)
    {
        self.key = key
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }
}

public class KeyboardResponder: UIResponder
{
    private let _nextResponder: UIResponder?
    
    public override var next: UIResponder? {
        return self._nextResponder
    }
    
    // Use KeyPress.keyCode as dictionary key because KeyPress.key may be invalid for keyUp events.
    private static var activeKeyPresses = [Int: KeyPress]()
    private static var activeModifierFlags = UIKeyModifierFlags(rawValue: 0)
    
    public init(nextResponder: UIResponder?)
    {
        self._nextResponder = nextResponder
    }
}

private extension KeyboardResponder
{
    // Implementation based on Steve Troughton-Smith's gist: https://gist.github.com/steventroughtonsmith/7515380
    override func _keyCommand(for event: UIEvent, target: UnsafeMutablePointer<UIResponder>) -> UIKeyCommand?
    {
        // Retrieve information from event.
        guard
            let key = event.value(forKey: "_unmodifiedInput") as? String,
            let keyCode = event.value(forKey: "_keyCode") as? Int,
            let rawModifierFlags = event.value(forKey: "_modifierFlags") as? Int,
            let isActive = event.value(forKey: "_isKeyDown") as? Bool
        else { return nil }
        
        let modifierFlags = UIKeyModifierFlags(rawValue: rawModifierFlags)
        defer { KeyboardResponder.activeModifierFlags = modifierFlags }
        
        let previousKeyPress = KeyboardResponder.activeKeyPresses[keyCode]
        
        // Ignore key presses that haven't changed activate state to filter out duplicate key press events.
        guard previousKeyPress?.isActive != isActive else { return nil }
        
        // Attempt to use previousKeyPress.key because key may be invalid for keyUp events.
        var pressedKey = previousKeyPress?.key ?? key
        
        // Check if pressedKey is a whitespace or newline character.
        if pressedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        {
            if pressedKey.isEmpty
            {
                if isActive
                {
                    // Determine the newly activated modifier key.
                    let activatedModifierFlags = modifierFlags.subtracting(KeyboardResponder.activeModifierFlags)
                    
                    guard let key = self.key(for: activatedModifierFlags) else { return nil }
                    pressedKey = key
                }
                else
                {
                    // Determine the newly deactivated modifier key.
                    let deactivatedModifierFlags = KeyboardResponder.activeModifierFlags.subtracting(modifierFlags)
                    
                    guard let key = self.key(for: deactivatedModifierFlags) else { return nil }
                    pressedKey = key
                }
            }
            else
            {
                switch pressedKey
                {
                case " ": pressedKey = KeyboardGameController.Input.space.rawValue
                case "\r", "\n": pressedKey = KeyboardGameController.Input.return.rawValue
                case "\t": pressedKey = KeyboardGameController.Input.tab.rawValue
                default: break
                }
            }
        }
        else
        {
            switch pressedKey
            {
            case UIKeyCommand.inputUpArrow: pressedKey = KeyboardGameController.Input.up.rawValue
            case UIKeyCommand.inputDownArrow: pressedKey = KeyboardGameController.Input.down.rawValue
            case UIKeyCommand.inputLeftArrow: pressedKey = KeyboardGameController.Input.left.rawValue
            case UIKeyCommand.inputRightArrow: pressedKey = KeyboardGameController.Input.right.rawValue
            case UIKeyCommand.inputEscape: pressedKey = KeyboardGameController.Input.escape.rawValue
            default: break
            }
        }

        let keyPress = previousKeyPress ?? KeyPress(key: pressedKey, keyCode: keyCode, modifierFlags: modifierFlags)
        keyPress.isActive = isActive
        
        if keyPress.isActive
        {
            KeyboardResponder.activeKeyPresses[keyCode] = keyPress
            
            UIResponder.firstResponder?.keyPressesBegan([keyPress], with: event)
            ExternalGameControllerManager.shared.keyPressesBegan([keyPress], with: event)
        }
        else
        {
            UIResponder.firstResponder?.keyPressesEnded([keyPress], with: event)
            ExternalGameControllerManager.shared.keyPressesEnded([keyPress], with: event)
            
            KeyboardResponder.activeKeyPresses[keyCode] = nil
        }
        
        return nil
    }
    
    func key(for modifierFlags: UIKeyModifierFlags) -> String?
    {
        switch modifierFlags
        {
        case .shift: return KeyboardGameController.Input.shift.rawValue
        case .control: return KeyboardGameController.Input.control.rawValue
        case .alternate: return KeyboardGameController.Input.option.rawValue
        case .command: return KeyboardGameController.Input.command.rawValue
        case .alphaShift: return KeyboardGameController.Input.capsLock.rawValue
        default: return nil
        }
    }
}
