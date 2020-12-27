//
//  UIResponder+FirstResponder.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/14/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import UIKit

private class FirstResponderEvent: UIEvent
{
    var firstResponder: UIResponder?
}

extension UIResponder
{
    @objc(delta_firstResponder)
    class var firstResponder: UIResponder? {
        let event = FirstResponderEvent()
        UIApplication.delta_shared?.sendAction(#selector(UIResponder.findFirstResponder(sender:event:)), to: nil, from: nil, for: event)
        return event.firstResponder
    }
    
    @objc(delta_findFirstResponderWithSender:event:)
    private func findFirstResponder(sender: Any?, event: FirstResponderEvent)
    {
        event.firstResponder = self
    }
}
