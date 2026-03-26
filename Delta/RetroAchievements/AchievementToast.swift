//
//  AchievementToast.swift
//  Delta
//
//  Created by Natalie Pekker on 3/12/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI

@available(iOS 26, *)
extension AchievementToastView
{
    static let preferredExpandedWidth: Double = 450
}

@available(iOS 26, *)
@Observable
class AchievementToastView: UIView
{
    var contentView: UIView!
    
    fileprivate var isVisible: Bool = false
    
    // Should only be accessed by Achievement Views
    var _timer: Timer?
    
    init<Content: View>(@ViewBuilder content: @escaping () -> Content) {
        super.init(frame: .zero)
        
        let hostingConfiguration = UIHostingConfiguration { [unowned self] in
            content()
                .environment(self)
        }
        .margins(.all, 0)
        
        self.contentView = hostingConfiguration.makeContentView()
        self.addSubview(self.contentView, pinningEdgesWith: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        self.update()
    }

    func show(in view: UIView, duration: TimeInterval = 4.0, useAutoLayout: Bool = true)
    {
        if useAutoLayout
        {
            self.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(self)
            
            let preferredWidthConstraint = self.widthAnchor.constraint(equalToConstant: AchievementToastView.preferredExpandedWidth)
            preferredWidthConstraint.priority = .defaultHigh // We'll grow to AchievementToastView.preferredExpandedWidth if we have the horizontal space available
            
            NSLayoutConstraint.activate([
                self.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                self.topAnchor.constraint(equalToSystemSpacingBelow: view.safeAreaLayoutGuide.topAnchor, multiplier: 1.0),
                
                // Fill up to AchievementToastView.preferredExpandedWidth, but content will still determine visual size
                // This allows us to grow from collapsed to expanded states across SwiftUI/UIKit boundary
                preferredWidthConstraint,
                self.leadingAnchor.constraint(greaterThanOrEqualToSystemSpacingAfter: view.safeAreaLayoutGuide.leadingAnchor, multiplier: 1.0),
                view.safeAreaLayoutGuide.trailingAnchor.constraint(greaterThanOrEqualToSystemSpacingAfter: self.trailingAnchor, multiplier: 1.0)
            ])
        }
        else
        {
            self.translatesAutoresizingMaskIntoConstraints = true
            
            let size = self.contentView.intrinsicContentSize
            self.frame = CGRect(origin: .zero, size: size)
            view.addSubview(self)
            self.update()
        }
        
        // Show is always called on main thread, but we dispatch this because onChange doesn't fire on first render
        DispatchQueue.main.async {
            self.isVisible = true
        }
        
        // Use Timer so we can cancel later (if needed)
        self._timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { timer in
            self.hide()
        }
    }
    
    func hide()
    {
        self.isVisible = false
    }
    
    private func update()
    {
        guard let superview = self.superview, self.translatesAutoresizingMaskIntoConstraints else { return }
                
        let xCoordinate = (superview.bounds.width - self.bounds.size.width) / 2
        let yCoordinate = max(superview.safeAreaInsets.top, 8.0) // Explicit 8.0 ensures there's padding above the toast in landscape
        
        self.frame = CGRect(
            x: xCoordinate,
            y: yCoordinate,
            width: self.bounds.width,
            height: self.bounds.height
        )
    }
}


@available(iOS 26, *)
struct AchievementToast<Content: View, S: InsettableShape>: View
{
    @Environment(AchievementToastView.self)
    private var hostingView

    private let glassShape: S

    private let content: Content
    
    @State
    private var isVisible: Bool = false
    
    init(glassShape: S, @ViewBuilder content: () -> Content)
    {
        self.glassShape = glassShape
        self.content = content()
    }
    
    var body: some View {
        GlassEffectContainer {
            ZStack {
                // Invisible content so toast doesn't collapse when it animates out
                content
                    .opacity(0)
                    .accessibilityHidden(true)
                
                if isVisible {
                    content
                        .glassEffect(.regular.tint(Color(uiColor: .deltaPurple).opacity(0.3)).interactive(), in: glassShape)
                        .glassEffectTransition(.materialize)
                        .foregroundStyle(.white)
                }
            }
        }
        .environment(\.colorScheme, .dark) // Used instead of preferredColorScheme since we're embedded in UIKit
        .onChange(of: hostingView.isVisible) { oldValue, newValue in
            withAnimation
            {
                isVisible = newValue
            }
            completion:
            {
                if !newValue {
                    DispatchQueue.main.async {
                        hostingView.hide()
                        hostingView.removeFromSuperview()
                    }
                }
            }
        }
    }
}

@available(iOS 26, *)
struct AchievementToastIcon: View
{
    var url: URL?
    var size: CGFloat
    var fallbackImageName: String
    
    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color(uiColor: .deltaLightPurple).opacity(0.3)
                Image(systemName: fallbackImageName)
                    .resizable()
                    .scaledToFit()
                    .padding(size > 34 ? 12 : 8)
            }
        }
        .frame(width: size, height: size)
    }

}
