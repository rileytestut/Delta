//
//  TvOSTextViewerViewController.swift
//  TvOSTextViewer
//
//  Created by David Cordero on 15.02.17.
//  Copyright © 2017 David Cordero. All rights reserved.
//

import UIKit


private let defaultTextColor: UIColor = .white
private let defaultFontSize: CGFloat = 41
private let defaultFont: UIFont = .systemFont(ofSize: defaultFontSize)
private let defaultBackgroundBlurEffectStyle: UIBlurEffect.Style = .dark

public class TvOSTextViewerViewController: UIViewController {
    
    @objc public var text: String = ""
    @objc public var textEdgeInsets: UIEdgeInsets = .zero
    @objc public var backgroundBlurEffectSyle = UIBlurEffect(style: defaultBackgroundBlurEffectStyle)
    @objc public var textAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: defaultTextColor,
                                                                     .font: defaultFont]
    
    private var backgroundView: UIVisualEffectView!
    private var textView: FadedTextView!
    
    // MARK: UIViewController
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        setUpView()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if textView.contentSize.height > textView.bounds.height {
            textView.contentInset = .zero
        }
        else {
            moveTextViewToTheCenter()
        }
    }
    
    // MARK: Private
    
    private func setUpView() {
        setUpBackgroundView()
        setUpTextView()
        
        setUpConstraints()
    }
    
    private func setUpBackgroundView() {
        backgroundView = UIVisualEffectView(effect: backgroundBlurEffectSyle)
        view.addSubview(backgroundView)
    }
    
    private func setUpTextView() {
        textView = FadedTextView()
        textView.panGestureRecognizer.allowedTouchTypes = [NSNumber(integerLiteral: UITouch.TouchType.indirect.rawValue)]
        textView.isUserInteractionEnabled = true
        
        textView.attributedText = NSAttributedString(string: text,
                                                     attributes: textAttributes)
        view.addSubview(textView)
    }

    private func moveTextViewToTheCenter() {
        var contentInset = UIEdgeInsets.zero
        contentInset.top = textView.bounds.height / 2
        contentInset.top -= textView.contentSize.height / 2
        textView.contentInset = contentInset
    }
    
    private func setUpConstraints() {
        setUpBackgroundConstraints()
        setUpTextViewConstraints()
    }
    
    private func setUpBackgroundConstraints() {
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        backgroundView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        backgroundView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        backgroundView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
    
    private func setUpTextViewConstraints() {
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        textView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
        let widthConstant = -(textEdgeInsets.left + textEdgeInsets.right)
        textView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: widthConstant).isActive = true
        textView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: textEdgeInsets.top).isActive = true
        textView.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor, constant: -(textEdgeInsets.bottom)).isActive = true
    }
}
