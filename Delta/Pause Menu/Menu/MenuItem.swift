//
//  MenuItem.swift
//  Delta
//
//  Created by Riley Testut on 1/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

@Observable
class MenuItem: NSObject
{
    var text: String
    var image: UIImage?
    var action: ((MenuItem) -> Void)
    
    var menuOptions: [Action]
    
    @nonobjc var isSelected: Bool = false {
        didSet {
            self._isSelectedObjC = self.isSelected
        }
    }
    @ObservationIgnored @objc(isSelected) dynamic var _isSelectedObjC: Bool = false
    
    init(text: String, image: UIImage?, menuOptions: [Action] = [], action: @escaping ((MenuItem) -> Void))
    {
        self.image = image
        self.text = text
        self.menuOptions = menuOptions
        self.action = action
    }
}

extension MenuItem
{
    override func isEqual(_ object: Any?) -> Bool
    {
        guard let item = object as? MenuItem else { return false }
        return item.image == self.image && item.text == self.text
    }
}
