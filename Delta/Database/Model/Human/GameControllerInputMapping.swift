//
//  GameControllerInputMapping.swift
//  Delta
//
//  Created by Riley Testut on 8/30/16.
//  Copyright (c) 2016 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore

@objc(GameControllerInputMapping)
public class GameControllerInputMapping: _GameControllerInputMapping
{
    fileprivate var inputMapping: DeltaCore.GameControllerInputMapping {
        get { return self.deltaCoreInputMapping as! DeltaCore.GameControllerInputMapping }
        set { self.deltaCoreInputMapping = newValue }
    }
    
    public convenience init(inputMapping: DeltaCore.GameControllerInputMapping, context: NSManagedObjectContext)
    {
        self.init(entity: GameControllerInputMapping.entity(), insertInto: context)
        
        self.inputMapping = inputMapping
    }
}

extension GameControllerInputMapping
{
    class func inputMapping(for gameController: GameController, gameType: GameType, in managedObjectContext: NSManagedObjectContext) -> GameControllerInputMapping?
    {
        guard let playerIndex = gameController.playerIndex else {
            return nil
        }
                
        let fetchRequest: NSFetchRequest<GameControllerInputMapping> = GameControllerInputMapping.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.predicate = NSPredicate(format: "%K == %@ AND %K == %@ AND %K == %d", #keyPath(GameControllerInputMapping.gameControllerInputType), gameController.inputType.rawValue, #keyPath(GameControllerInputMapping.gameType), gameType.rawValue, #keyPath(GameControllerInputMapping.playerIndex), playerIndex)
        
        do
        {
            let inputMappings = try managedObjectContext.fetch(fetchRequest)
            
            let inputMapping = inputMappings.first
            return inputMapping
        }
        catch
        {
            print(error)
            
            return nil
        }        
    }
}

extension GameControllerInputMapping: GameControllerInputMappingProtocol
{
    var name: String? {
        get { return self.inputMapping.name }
        set { self.inputMapping.name = newValue }
    }
    
    var supportedControllerInputs: [Input] {
        return self.inputMapping.supportedControllerInputs
    }
    
    public func input(forControllerInput controllerInput: Input) -> Input?
    {
        return self.inputMapping.input(forControllerInput: controllerInput)
    }
    
    func set(_ input: Input?, forControllerInput controllerInput: Input)
    {
        self.inputMapping.set(input, forControllerInput: controllerInput)
    }
}
