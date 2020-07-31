//
//  AsyncImage.swift
//  DeltaMac
//
//  Created by Riley Testut on 7/30/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import Combine
import Foundation

class ImageLoader: ObservableObject
{
    @Published var image: UIImage?
    
    private let url: URL?
    private var cancellable: AnyCancellable?

    init(url: URL?)
    {
        self.url = url
    }
    
    deinit
    {
        cancellable?.cancel()
    }
    
    func load()
    {
        guard let url = self.url else { return }
        
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .assign(to: \.image, on: self)
    }
    
    func cancel()
    {
        cancellable?.cancel()
    }
}

struct AsyncImage<Placeholder: View>: View
{
    @ObservedObject private var loader: ImageLoader
    private let placeholder: Placeholder?
    
    init(url: URL?, placeholder: Placeholder? = nil)
    {
        self.loader = ImageLoader(url: url)
        self.placeholder = placeholder
    }

    var body: some View {
        image
            .onAppear(perform: loader.load)
            .onDisappear(perform: loader.cancel)
    }
    
    private var image: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder
            }
        }
    }
}
