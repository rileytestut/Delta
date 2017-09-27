//
//  ImportOption.swift
//  Delta
//
//  Created by Riley Testut on 5/1/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

import DeltaCore

extension UIDocumentMenuViewController
{
    func add(_ importOption: ImportOption, order: UIDocumentMenuOrder, completionHandler: @escaping (Set<URL>?) -> Void)
    {
        self.addOption(withTitle: importOption.title, image: importOption.image, order: order) {
            importOption.import(withCompletionHandler: completionHandler)
        }
    }
}

extension UIAlertController
{
    func add(_ importOption: ImportOption, completionHandler: @escaping (Set<URL>?) -> Void)
    {
        let action = UIAlertAction(title: importOption.title, style: .default, handler: { action in
            importOption.import(withCompletionHandler: completionHandler)
        })
        self.addAction(action)
    }
}

protocol ImportOption
{
    var title: String { get }
    var image: UIImage? { get }
    
    func `import`(withCompletionHandler completionHandler: @escaping (Set<URL>?) -> Void)
}