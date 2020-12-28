//
//  ClipboardImportOption.swift
//  Delta
//
//  Created by Riley Testut on 5/1/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit
import MobileCoreServices

import Roxas

struct ClipboardImportOption: ImportOption
{
    let title = NSLocalizedString("Clipboard", comment: "")
    let image: UIImage? = nil
    
    func `import`(withCompletionHandler completionHandler: @escaping (Set<URL>?) -> Void)
    {
        guard UIPasteboard.general.hasImages else { return completionHandler([]) }
        
        guard let data = UIPasteboard.general.data(forPasteboardType: kUTTypeImage as String) else { return completionHandler([]) }
        
        do
        {
            let temporaryURL = FileManager.default.uniqueTemporaryURL()
            try data.write(to: temporaryURL, options: .atomic)
            
            completionHandler([temporaryURL])
        }
        catch
        {
            print(error)
            
            completionHandler([])
        }
    }
}
