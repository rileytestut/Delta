//
//  UIAlertController+Importing.swift
//  Delta
//
//  Created by Riley Testut on 1/13/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

extension UIAlertController
{
    enum ImportType
    {
        case games
        case controllerSkins
    }
    
    class func alertController(for importType: ImportType, with errors: Set<DatabaseManager.ImportError>) -> UIAlertController
    {
        let title: String
        
        switch importType
        {
        case .games: title = NSLocalizedString("Error Importing Games", comment: "")
        case .controllerSkins: title = NSLocalizedString("Error Importing Controller Skins", comment: "")
        }
        
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        
        var urls = Set<URL>()
        
        for error in errors
        {
            switch error
            {
            case .doesNotExist(let url): urls.insert(url)
            case .invalid(let url): urls.insert(url)
            case .unknown(let url, _): urls.insert(url)
            case .saveFailed(let errorURLs, _): urls.formUnion(errorURLs)
            }
        }
        
        let filenames = urls.map{ $0.lastPathComponent }.sorted()
        
        if filenames.count > 0
        {
            var message: String
            
            switch importType
            {
            case .games: message = NSLocalizedString("The following game files could not be imported:", comment: "") + "\n"
            case .controllerSkins: message = NSLocalizedString("The following controller skin files could not be imported:", comment: "") + "\n"
            }
            
            for filename in filenames
            {
                message += "\n" + filename
            }
            
            alertController.message = message
        }
        else
        {
            // This branch can be executed when there are no input URLs when importing, but there is an error saving the database anyway.
            
            switch importType
            {
            case .games: alertController.message = NSLocalizedString("Delta was unable to import games. Please try again later.", comment: "")
            case .controllerSkins: alertController.message = NSLocalizedString("Delta was unable to import controller skins. Please try again later.", comment: "")
            }
        }
        
        alertController.addAction(UIAlertAction(title: RSTSystemLocalizedString("OK"), style: .cancel, handler: nil))
        
        return alertController
    }
}
