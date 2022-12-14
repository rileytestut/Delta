//
//  PopoverMenuButton.swift
//  Delta
//
//  Created by Riley Testut on 9/2/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit

extension UINavigationBar
{
    fileprivate var defaultTitleTextAttributes: [NSAttributedString.Key: Any]? {
        if let textAttributes = self._defaultTitleTextAttributes
        {
            return textAttributes
        }
        
        // Make "copy" of self.
        let navigationBar = UINavigationBar(frame: .zero)
        navigationBar.barStyle = self.barStyle
        
        // Set item with title so we can retrieve default text attributes.
        let navigationItem = UINavigationItem(title: "Testut")
        navigationBar.items = [navigationItem]
        navigationBar.isHidden = true
        
        // Must be added to window hierarchy for it to create title UILabel.
        self.addSubview(navigationBar)
        defer { navigationBar.removeFromSuperview() }
        
        navigationBar.layoutIfNeeded()
        
        let textAttributes = navigationBar._defaultTitleTextAttributes
        return textAttributes
    }
    
    private var _defaultTitleTextAttributes: [NSAttributedString.Key: Any]? {
        guard self.titleTextAttributes == nil else { return self.titleTextAttributes }
        
        guard let contentView = self.subviews.first(where: { NSStringFromClass(type(of: $0)).contains("ContentView") || NSStringFromClass(type(of: $0)).contains("ItemView") })
        else { return nil }
        
        let containerView: UIView
        
        if #available(iOS 16, *)
        {
            guard let titleControl = contentView.subviews.first(where: { NSStringFromClass(type(of: $0)).contains("Title") }) else { return nil }
            containerView = titleControl
        }
        else
        {
            containerView = contentView
        }
        
        guard let titleLabel = containerView.subviews.first(where: { $0 is UILabel }) as? UILabel else { return nil }
        
        let textAttributes = titleLabel.attributedText?.attributes(at: 0, effectiveRange: nil)
        return textAttributes
    }
}

class PopoverMenuButton: UIControl
{
    var title: String {
        get { return self.textLabel.text ?? "" }
        set { 
            self.textLabel.text = newValue
            self.updateTextAttributes() 
            self.invalidateIntrinsicContentSize()
        }
    }
    
    private let textLabel: UILabel
    private let arrowLabel: UILabel
    private let stackView: UIStackView
    
    private var _didLayoutSubviews = false
    
    private var parentNavigationBar: UINavigationBar? {
        guard let navigationController = self.parentViewController as? UINavigationController ?? self.parentViewController?.navigationController else { return nil }
        guard self.isDescendant(of: navigationController.navigationBar) else { return nil }
        
        return navigationController.navigationBar
    }
    
    override var intrinsicContentSize: CGSize {
        return self.stackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    }
    
    init()
    {
        self.textLabel = UILabel()
        self.textLabel.textColor = .black
        
        self.arrowLabel = UILabel()
        self.arrowLabel.text = "▾"
        self.arrowLabel.textColor = .black
        
        self.stackView = UIStackView(arrangedSubviews: [self.textLabel, self.arrowLabel])
        self.stackView.axis = .horizontal
        self.stackView.distribution = .fillProportionally
        self.stackView.alignment = .center
        self.stackView.spacing = 4.0
        self.stackView.isUserInteractionEnabled = false
        
        let intrinsicContentSize = self.stackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        super.init(frame: CGRect(origin: .zero, size: intrinsicContentSize))
        
        self.addSubview(self.stackView, pinningEdgesWith: .zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview()
    {
        self.updateTextAttributes()
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        
        if !_didLayoutSubviews
        {
            _didLayoutSubviews = true
            
            // didMoveToSuperview() can be too early to accurately
            // update text attributes, so ensure we also update
            // during first layoutSubviews() call.
            self.updateTextAttributes()
        }
    }
}

private extension PopoverMenuButton
{
    func updateTextAttributes()
    {
        guard let parentNavigationBar = self.parentNavigationBar else { return }
        guard let textAttributes = parentNavigationBar.defaultTitleTextAttributes else { return }
        
        for label in [self.textLabel, self.arrowLabel]
        {
            label.attributedText = NSAttributedString(string: label.text ?? "", attributes: textAttributes)
        }
    }
}
