//
//  LegacySearchBar.swift
//  Delta
//
//  Created by Riley Testut on 1/25/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI

@available(iOS 13, *)
struct LegacySearchBar: UIViewRepresentable
{
    class Coordinator: NSObject, UISearchBarDelegate
    {
        @Binding
        var text: String
        
        init(text: Binding<String>)
        {
            self._text = text
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String)
        {
            self.text = searchText
        }
    }
    
    @Binding
    var text: String
    
    func makeUIView(context: Context) -> UISearchBar
    {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = NSLocalizedString("Search", comment: "")
        return searchBar
    }
    
    func updateUIView(_ uiView: UISearchBar, context: Context)
    {
        uiView.text = self.text
    }
    
    func makeCoordinator() -> Coordinator
    {
        return Coordinator(text: $text)
    }
}
