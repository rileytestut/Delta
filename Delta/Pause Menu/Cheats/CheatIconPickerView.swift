//
//  CheatIconPickerView.swift
//  Delta
//
//  Created by Caroline on 4/3/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

extension CheatIconPickerView
{
    private struct Symbol: Decodable, Identifiable
    {
        var id: String { self.symbolName }
        var symbolName: String
    }
    
    static func makeViewController(selectedSymbolName: String?, selectionHandler: @escaping (String?) -> Void) -> UIHostingController<CheatIconPickerView>
    {
        let view = CheatIconPickerView(selectionHandler: selectionHandler, selectedSymbolName: selectedSymbolName)

        let hostingController = UIHostingController(rootView: view)
        hostingController.navigationItem.largeTitleDisplayMode = .never
        hostingController.navigationItem.title = NSLocalizedString("Change Icon", comment: "")

        return hostingController
    }
}

struct CheatIconPickerView: View
{
    var selectionHandler: ((String?) -> Void)?

    @State
    private var selectedSymbolName: String?

    private let symbols: [Symbol] = {
        do
        {
            let url = Bundle.main.url(forResource: "CheatIcons", withExtension: "plist")!
            let data = try Data(contentsOf: url)
            
            let symbols = try PropertyListDecoder().decode([Symbol].self, from: data)
            return symbols
        }
        catch
        {
            fatalError(error.localizedDescription)
        }
    }()

    private let columns = [
        GridItem(.adaptive(minimum: 70), spacing: 5)
    ]
    
    init(selectionHandler: ((String?) -> Void)? = nil, selectedSymbolName: String? = nil)
    {
        self.selectionHandler = selectionHandler
        self.selectedSymbolName = selectedSymbolName
    }

    var body: some View
    {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(symbols) { symbol in
                    Button {
                        selectedSymbolName = symbol.symbolName
                        selectionHandler?(symbol.symbolName)
                    } label: {
                        Image(systemName: symbol.symbolName)
                            .font(.largeTitle)
                            .frame(width: 70, height: 70)
                            .background(selectedSymbolName == symbol.symbolName ? Color.accentColor.opacity(0.2) : Color.clear)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

#Preview("No Selection") {
    CheatIconPickerView()
}

#Preview("Pre-selected") {
    CheatIconPickerView(selectedSymbolName: "flame.fill")
}
