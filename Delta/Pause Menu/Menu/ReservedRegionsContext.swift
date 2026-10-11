//
//  ReservedRegionsContext.swift
//  Delta
//
//  Created by Riley Testut on 10/11/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

struct ReservedRegionsContext
{
    var regionsCount: Int = 1
    
    var dividerSize: CGSize = .zero
    var regionSize: CGSize = .zero
    
    init(geometry: GeometryProxy)
    {
        if #available(iOS 27.1, *)
        {
            let regions = geometry.reservedRegions(kind: .division)
            self.regionsCount = regions.count + 1
            
            if let region = regions.first
            {
                self.dividerSize = region.frame.size
            }
        }
        
        if geometry.size.height > geometry.size.width
        {
            // Portrait (full width, half height)
            self.regionSize = CGSize(width: geometry.size.width, height: (geometry.size.height - self.dividerSize.height) / Double(self.regionsCount))
        }
        else
        {
            // Landscape (half width, full height)
            self.regionSize = CGSize(width: (geometry.size.width - self.dividerSize.width) / Double(self.regionsCount), height: geometry.size.height)
        }
    }
}
