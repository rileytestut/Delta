//
//  GameViewController+CustomFilters.swift
//  Delta
//
//  Created by Shane on 10/5/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import UIKit
import CoreImage
import MetalKit

import DeltaCore

extension GameViewController
{
    func updateCustomFilters()
    {
        guard ExperimentalFeatures.shared.customFilters.isEnabled else { return }
        
        // DeltaCore disables rendering while game views are resizing (e.g. rotating), so wait until it's finished.
        // viewWillTransition(to:with:) calls this method again once resizing completes.
        guard self.emulatorCore?.videoManager.isEnabled ?? true else { return }

        var shaderURL: URL?

        if ExperimentalFeatures.shared.customFilters.isEnabled, let game = self.game
        {
            shaderURL = ExperimentalFeatures.shared.customFilters.shaderURL(for: game.type)
        }

        var gameViews = self.gameViews

        if let scene = UIApplication.shared.externalDisplayScene, scene.gameViewController.delegate === self
        {
            // Also apply to game views on external displays.
            gameViews += scene.gameViewController.gameViews
        }

        for gameView in gameViews
        {
            gameView.applyCustomScreenFilter(shaderURL: shaderURL)
        }
    }
}

private extension GameView
{
    func applyCustomScreenFilter(shaderURL: URL?)
    {
        // DeltaCore resets `filter` whenever the controller skin changes, so CustomScreenFilter is appended to any existing filters (e.g. DS screen crops).
        var filters: [CIFilter]
        switch self.filter
        {
        case let filterChain as FilterChain: filters = filterChain.inputFilters
        case let filter?: filters = [filter]
        case nil: filters = []
        }

        let currentFilter = filters.lazy.compactMap { $0 as? CustomScreenFilter }.first
        let targetSize = self.drawableSize

        // Only replace filter when something has changed, since this is called on every layout pass.
        if let shaderURL
        {
            // Wait until game view has been laid out.
            guard targetSize != .zero else { return }
            guard currentFilter?.inputShaderPath != shaderURL.path || currentFilter?.targetSize != targetSize else { return }
        }
        else
        {
            guard currentFilter != nil else { return }
        }

        // Reuse the existing filters rather than copying them, since copying reads their inputImage while the render thread may be updating it.
        filters.removeAll { $0 is CustomScreenFilter }

        if let shaderURL
        {
            filters.append(CustomScreenFilter(shaderURL: shaderURL, targetSize: targetSize))
        }

        // Setting `filter` immediately renders a frame on the calling thread, which can crash (especially with OpenGL ES) if the render thread is also rendering.
        // Temporarily disable the game view so the render thread draws the new filter with the next frame instead.
        let isEnabled = self.isEnabled
        self.isEnabled = false
        self.filter = filters.isEmpty ? nil : FilterChain(filters: filters)
        self.isEnabled = isEnabled
    }

    // Size (in pixels) GameView renders its output image into.
    // When rendering with Metal, GameView scales its output image to exactly fill its MTKView's drawable, which may be fractional and differ slightly from bounds * scale.
    // CustomScreenFilter must output exactly this size, since scaling makes Core Image render the filter into a cached intermediate image that can be displayed again in later frames.
    var drawableSize: CGSize {
        if let metalView = self.subviews.lazy.compactMap({ $0 as? MTKView }).first, metalView.drawableSize != .zero
        {
            return metalView.drawableSize
        }

        let scale = max(self.traitCollection.displayScale, 1.0)
        return CGSize(width: self.bounds.width * scale, height: self.bounds.height * scale)
    }
}
