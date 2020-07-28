//
//  GameCollectionView.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/24/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import DeltaCore

struct GameCell: View
{
    let game: Game
    
    var body: some View {
        VStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 5.0, style: /*@START_MENU_TOKEN@*/.continuous/*@END_MENU_TOKEN@*/)
                .aspectRatio(CGSize(width: 1, height: 1), contentMode: /*@START_MENU_TOKEN@*/.fill/*@END_MENU_TOKEN@*/)
                .foregroundColor(.red)
            
            Text(self.game.name + "\n")
                .font(.body)
                .lineLimit(2)
        }
    }
}

struct GameCollectionView: View
{
    let system: System?
    let games: [Game]
    
    @State var activeGame: Game?
    
    init(system: System?)
    {
        self.system = system
        self.games = system?.placeholderGames ?? []
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 25)]) {
                ForEach(self.games) { (game) in
                    NavigationLink(destination: GameView(game: game)) {
                        GameCell(game: game)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                
            }
            .padding()
        }
        .navigationTitle(self.system?.localizedName ?? "")
    }
}

struct GameCollectionView_Previews: PreviewProvider {
    static var previews: some View {
        GameCollectionView(system: .nes)
            .previewLayout(.fixed(width: 960, height: 640))
    }
}
