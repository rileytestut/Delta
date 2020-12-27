//
//  NSManagedObject+Harmony.swift
//  Harmony
//
//  Created by Riley Testut on 10/22/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import CoreData

public extension NSManagedObjectModel
{
    class func harmonyModel(byMergingWith managedObjectModels: [NSManagedObjectModel]) -> NSManagedObjectModel?
    {
        guard
            let modelURL = Bundle(for: RecordController.self).url(forResource: "Harmony", withExtension: "momd"),
            let harmonyModel = NSManagedObjectModel(contentsOf: modelURL)
        else
        {
            fatalError("Harmony Core Data model cannot be found. Aborting.")
        }
        
        let models = managedObjectModels + [harmonyModel]
        
        guard let mergedModel = NSManagedObjectModel(byMerging: models) else { return nil }
        
        // Retrieve entity names from provided managed object models, and then retrieve matching entities from merged model.
        let externalEntityNames = Set(managedObjectModels.flatMap { $0.entities.compactMap { $0.name } })
        let externalEntities = mergedModel.entities.filter { externalEntityNames.contains($0.name!) }
        
        mergedModel.setEntities(externalEntities, forConfigurationName: Configuration.external.rawValue)
        
        return mergedModel
    }
}

