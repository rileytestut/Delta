//
//  PageControl.swift
//  Delta
//
//  Created by Caroline Moore on 3/10/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

struct PageIndicator: Identifiable, Equatable
{
    var id: String
    var image: UIImage
    var alwaysShowsImage: Bool = false
    var imageScale: Double = 1.0
}

@MainActor
@Observable
class PageModel
{
    var indicators: [PageIndicator] = []
    var currentPage: Int = 0

    @ObservationIgnored
    var onPageSelected: ((Int, _ animated: Bool) -> Void)?
}

class PageControlView: UIView
{
    let model: PageModel
    private var contentView: UIView!

    init()
    {
        let model = PageModel()
        self.model = model
        super.init(frame: .zero)

        let hostingConfiguration = UIHostingConfiguration {
            PageControl(model: model)
        }
        .margins(.all, 0)

        self.contentView = hostingConfiguration.makeContentView()
        self.addSubview(self.contentView, pinningEdgesWith: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct PageControl: View
{
    @Namespace
    private var animation
    
    @State
    private var model: PageModel

    @State
    private var scrubbingPage: Int?

    var body: some View {
        if #available(iOS 26, *)
        {
            GlassEffectContainer {
                indicators
                    .glassEffect()
            }
            .frame(height: 40) // Ensures correct layout when appearing from hidden
        }
        else
        {
            indicators
        }
    }

    private var indicators: some View {
        HStack(spacing: 3) {
            ForEach(Array(zip(0..., model.indicators)), id: \.1.id) { index, indicator in
                IndicatorImage(
                    indicator: indicator,
                    isSelected: index == model.currentPage,
                    namespace: animation
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .animation(.spring(duration: 0.3), value: model.indicators)
        .animation(.spring(duration: 0.3), value: model.currentPage)
        .sensoryFeedback(.selection, trigger: model.currentPage) { _, _ in scrubbingPage != nil }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    // Convert drag position to page index, accounting for 14pt horizontal padding and 23pt indicator width (20 + 3)
                    let index = max(0, min(model.indicators.count - 1, Int((value.location.x - 14) / 23)))
                    
                    if index != scrubbingPage
                    {
                        let animated = scrubbingPage == nil // Animate on first change only, subsequent changes are scrubs
                        scrubbingPage = index
                        model.onPageSelected?(index, animated)
                    }
                }
                .onEnded { _ in scrubbingPage = nil }
        )
    }

    fileprivate init(model: PageModel)
    {
        self.model = model
    }
}

private struct IndicatorImage: View
{
    let indicator: PageIndicator
    let isSelected: Bool
    let namespace: Namespace.ID

    private var image: some View {
        Image(uiImage: indicator.image)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    var body: some View {
        ZStack {
            if isSelected
            {
                image
                    .foregroundStyle(.white)
                    .matchedGeometryEffect(id: indicator.id, in: namespace)
            }
            else if indicator.alwaysShowsImage
            {
                image
                    .frame(width: 13 * indicator.imageScale, height: 13 * indicator.imageScale)
                    .foregroundStyle(.white.opacity(0.4))
                    .matchedGeometryEffect(id: indicator.id, in: namespace)
            }
            else
            {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(.white.opacity(0.4))
                    .matchedGeometryEffect(id: indicator.id, in: namespace)
            }
        }
        .frame(width: 20, height: 20)
    }
}


#Preview {
    let model = PageModel()
    model.indicators = [
        PageIndicator(id: "Favorites",       image: UIImage(systemName: "star.fill")!, alwaysShowsImage: true),
        PageIndicator(id: "Recently Played", image: UIImage(systemName: "clock.fill")!, alwaysShowsImage: true, imageScale: 0.8),
        PageIndicator(id: "NES",             image: UIImage(named: "NES") ?? UIImage(systemName: "gamecontroller.fill")!, alwaysShowsImage: false),
        PageIndicator(id: "SNES",            image: UIImage(named: "SNES") ?? UIImage(systemName: "gamecontroller.fill")!, alwaysShowsImage: false),
        PageIndicator(id: "GBA",             image: UIImage(named: "GBA") ?? UIImage(systemName: "gamecontroller.fill")!, alwaysShowsImage: false),
    ]

    return PageControl(model: model)
}
