//
//  AttributedHeaderFooterView.swift
//  Delta
//
//  Created by Riley Testut on 11/15/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import UIKit

@available(iOS 15, *)
final class AttributedHeaderFooterView: UITableViewHeaderFooterView
{
    static let reuseIdentifier: String = "TextViewHeaderFooterView"
    
    var attributedText: AttributedString? {
        get {
            guard let attributedText = self.textView.attributedText else { return nil }
            return AttributedString(attributedText)
        }
        set {
            guard var attributedText = newValue else {
                self.textView.attributedText = nil
                return
            }
            
            var attributes = AttributeContainer()
            attributes.foregroundColor = UIColor.secondaryLabel
            attributes.font = self.textLabel?.font ?? UIFont.preferredFont(forTextStyle: .footnote)
            
            attributedText.mergeAttributes(attributes, mergePolicy: .keepCurrent)
            self.textView.attributedText = NSAttributedString(attributedText)
        }
    }
    
    private let textView: UITextView
    
    override init(reuseIdentifier: String?)
    {
        self.textView = UITextView(frame: .zero)
        self.textView.translatesAutoresizingMaskIntoConstraints = false
        self.textView.textContainer.lineFragmentPadding = 0
        self.textView.textContainerInset = .zero
        self.textView.isSelectable = true // Must be true to open links
        self.textView.isEditable = false
        self.textView.isScrollEnabled = false
        self.textView.backgroundColor = nil
        self.textView.textContainer.lineBreakMode = .byWordWrapping
        
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.textView.delegate = self
        self.contentView.addSubview(self.textView)
        
        NSLayoutConstraint.activate([
            self.textView.topAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.topAnchor),
            self.textView.bottomAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.bottomAnchor),
            self.textView.leadingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leadingAnchor),
            self.textView.trailingAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.trailingAnchor),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(iOS 15, *)
extension AttributedHeaderFooterView: UITextViewDelegate
{
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool
    {
        return true
    }
}
