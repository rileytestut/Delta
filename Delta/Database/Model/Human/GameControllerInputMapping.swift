//
//  GameControllerInputMapping.swift
//  Delta
//
//  Created by Riley Testut on 8/30/16.
//  Copyright (c) 2016 Riley Testut. All rights reserved.
//

import Foundation

import DeltaCore
import Harmony

@objc(GameControllerInputMapping)
public class GameControllerInputMapping: _GameControllerInputMapping
{
    private var inputMapping: DeltaCore.GameControllerInputMapping {
        get { return self.deltaCoreInputMapping as! DeltaCore.GameControllerInputMapping }
        set { self.deltaCoreInputMapping = newValue }
    }
    
    public convenience init(inputMapping: DeltaCore.GameControllerInputMapping, context: NSManagedObjectContext)
    {
        self.init(entity: GameControllerInputMapping.entity(), insertInto: context)
        
        self.inputMapping = inputMapping
    }
    
    public override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        self.identifier = UUID().uuidString
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
            
            let inputMapping = inputMappings.first(where: { !$0.isDeleted })
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

extension GameControllerInputMapping: Syncable
{
    public static var syncablePrimaryKey: AnyKeyPath {
        return \GameControllerInputMapping.identifier
    }

    public var syncableKeys: Set<AnyKeyPath> {
        return [\GameControllerInputMapping.deltaCoreInputMapping,
                \GameControllerInputMapping.gameControllerInputType,
                \GameControllerInputMapping.gameType,
                \GameControllerInputMapping.playerIndex]
    }
    
    public var syncableLocalizedName: String? {
        return self.name
    }
    
    public func resolveConflict(_ record: AnyRecord) -> ConflictResolution
    {
        return .newest
    }
}
