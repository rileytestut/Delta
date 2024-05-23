//
//  NSUserActivity+Delta.swift
//  Delta
//
//  Created by Riley Testut on 5/9/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import Foundation

extension NSUserActivity
{
    static let playGameActivityType = "com.rileytestut.Delta.PlayGame"
    
    static let gameIDKey = "gameID"
    static let systemIDKey = "systemID"
    
    convenience init(game: Game)
    {
        self.init(activityType: NSUserActivity.playGameActivityType)
        self.userInfo = [NSUserActivity.gameIDKey: game.identifier]
    }
}
