//
//  UILabel+FontSize.swift
//  Delta
//
//  Created by Riley Testut on 12/25/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import UIKit

internal extension UILabel
{
    var currentScaleFactor: CGFloat
    {
        guard let text = self.text else { return 1.0 }
        
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = self.minimumScaleFactor
        
        // Using self.attributedString returns incorrect calculations, so we create our own attributed string
        let attributedString = NSAttributedString(string: text, attributes: [.font: self.font!])
        attributedString.boundingRect(with: self.bounds.size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: context)
        
        let scaleFactor = context.actualScaleFactor
        return scaleFactor
    }
}

