//
//  EmulatorCore+Cheats.swift
//  Delta
//
//  Created by Riley Testut on 8/11/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import DeltaCore

extension EmulatorCore
{
    func activateCheatWithErrorLogging(_ cheat: Cheat)
    {
        do
        {
            try self.activate(cheat)
        }
        catch EmulatorCore.CheatError.invalid
        {
            print("Invalid cheat:", cheat.name, cheat.code)
        }
        catch
        {
            print("Unknown Cheat Error:", error, cheat.name, cheat.code)
        }
    }
    
    func updateCheats()
    {
        guard let game = self.game as? Game else { return }
        
        let running = (self.state == .running)
        
        if running
        {
            // Core MUST be paused when activating cheats, or else race conditions could crash the core
            self.pause()
        }
        
        let backgroundContext = DatabaseManager.shared.newBackgroundContext()
        backgroundContext.performAndWait {
            
            let predicate = NSPredicate(format: "%K == %@", #keyPath(Cheat.game), game)
            
            let cheats = Cheat.instancesWithPredicate(predicate, inManagedObjectContext: backgroundContext, type: Cheat.self)
            for cheat in cheats
            {
                if cheat.isEnabled
                {
                    self.activateCheatWithErrorLogging(cheat)
                }
                else
                {
                    self.deactivate(cheat)
                }
            }
        }
        
        if running
        {
            self.resume()
        }

    }
}
