//
//  MenuItem.swift
//  Delta
//
//  Created by Riley Testut on 1/30/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit

// Must be class for use with Objective-C generics :(
@Observable
class MenuItem: NSObject
{
    var text: String
    var image: UIImage?
    var action: ((MenuItem) -> Void)
    
    var menuOptions: [Action]
    var menu: UIMenu?
    
//    @objc(isSelected) private dynamic var isSelected = false
    
    var isSelected: Bool = false
    
    init(text: String, image: UIImage?, menuOptions: [Action] = [], menu: UIMenu? = nil, action: @escaping ((MenuItem) -> Void))
    {
        self.image = image
        self.text = text
        self.menuOptions = menuOptions
        self.menu = menu
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
