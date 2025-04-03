//
//  Achievement.swift
//  Delta
//
//  Created by Riley Testut on 3/4/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import rcheevos

struct Achievement
{
    var title: String
    var description: String?
    var progress: Double
    var points: Int
    
    init(achievement: rc_client_achievement_t)
    {
        self.title = String(cString: achievement.title)
        
        if let description = achievement.description
        {
            self.description = String(cString: description)
        }
        
        self.progress = Double(achievement.measured_percent)
        self.points = Int(achievement.points)
    }
}
