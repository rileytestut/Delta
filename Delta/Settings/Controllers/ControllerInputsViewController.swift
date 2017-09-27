//
//  ControllerInputsViewController.swift
//  Delta
//
//  Created by Riley Testut on 7/1/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import UIKit
import Roxas

import DeltaCore

import SMCalloutView

class ControllerInputsViewController: UIViewController
{
    var gameController: GameController! {
        didSet {
            self.prepareGameController()
        }
    }
    
    var system: System = .snes {
        didSet {
            guard self.system != oldValue else { return }
            self.updateSystem()
        }
    }
    
    fileprivate var inputMapping: GameControllerInputMapping!
    fileprivate var previousInputMapping: GameControllerInputMappingProtocol?
    
    fileprivate let supportedActionInputs: [ActionInput] = [.saveState, .loadState, .fastForward]
    
    fileprivate var gameViewController: DeltaCore.GameViewController!
    fileprivate var actionsMenuViewController: GridMenuViewController!
    
    fileprivate var calloutViews = [AnyInput: InputCalloutView]()
    
    fileprivate var activeCalloutView: InputCalloutView?
    
    @IBOutlet private var actionsMenuViewControllerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var cancelTapGestureRecognizer: UITapGestureRecognizer!
        
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.gameViewController.controllerView.addReceiver(self)
        
        self.navigationController?.navigationBar.barStyle = .black
        
        NSLayoutConstraint.activate([self.gameViewController.gameView.centerYAnchor.constraint(equalTo: self.actionsMenuViewController.view.centerYAnchor)])
        
        self.preparePopoverMenuController()
        self.updateSystem()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        if self.actionsMenuViewController.preferredContentSize.height > 0
        {
            self.actionsMenuViewControllerHeightConstraint.constant = self.actionsMenuViewController.preferredContentSize.height
        }
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if self.calloutViews.isEmpty
        {
            self.prepareCallouts()
        }
    }
}

extension ControllerInputsViewController
{
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "embedGameViewController": self.gameViewController = segue.destination as! DeltaCore.GameViewController
        case "embedActionsMenuViewController":
            self.actionsMenuViewController = segue.destination as! GridMenuViewController
            self.prepareActionsMenuViewController()
            
        case "cancelControllerControls": self.gameController.inputMapping = self.previousInputMapping
        case "saveControllerControls": self.gameController.inputMapping = self.inputMapping
            
        default: break
        }
    }
}

private extension ControllerInputsViewController
{
    func updateSystem()
    {
        guard self.isViewLoaded else { return }
        
        if let popoverMenuButton = self.navigationItem.popoverMenuController?.popoverMenuButton
        {
            popoverMenuButton.title = self.system.localizedShortName
            popoverMenuButton.bounds.size = popoverMenuButton.intrinsicContentSize
            
            self.navigationController?.navigationBar.layoutIfNeeded()
        }
        
        self.gameViewController.controllerView.controllerSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: self.system.gameType)
        
        if self.view.window != nil
        {
            self.calloutViews.forEach { $1.dismissCallout(animated: true) }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.calloutViews = [:]
                self.prepareCallouts()
            }
        }
    }
    
    func prepareGameController()
    {
        self.gameController.addReceiver(self)
        
        self.previousInputMapping = self.gameController.inputMapping
        
        self.inputMapping = self.gameController.inputMapping as? GameControllerInputMapping ?? GameControllerInputMapping(gameControllerInputType: self.gameController.inputType)
        self.inputMapping.name = String.localizedStringWithFormat("Custom %@", self.gameController.name)
        
        self.gameController.inputMapping = nil
    }
    
    func preparePopoverMenuController()
    {
        let listMenuViewController = ListMenuViewController()
        listMenuViewController.title = NSLocalizedString("Game System", comment: "")
        
        let navigationController = UINavigationController(rootViewController: listMenuViewController)
        
        let popoverMenuController = PopoverMenuController(popoverViewController: navigationController)
        self.navigationItem.popoverMenuController = popoverMenuController
        
        let items = System.supportedSystems.map { [unowned self, weak popoverMenuController, weak listMenuViewController] system -> MenuItem in
            let item = MenuItem(text: system.localizedShortName, image: #imageLiteral(resourceName: "CheatCodes")) { [weak popoverMenuController, weak listMenuViewController] item in
                listMenuViewController?.items.forEach { $0.isSelected = ($0 == item) }
                popoverMenuController?.isActive = false
                
                self.system = system
            }
            item.isSelected = (system == self.system)
            
            return item
        }
        listMenuViewController.items = items
    }
    
    func prepareActionsMenuViewController()
    {
        var items = [MenuItem]()
        
        for input in self.supportedActionInputs
        {
            let image: UIImage
            let text: String
            
            switch input
            {
            case .saveState:
                image = #imageLiteral(resourceName: "SaveSaveState")
                text = NSLocalizedString("Save State", comment: "")
                
            case .loadState:
                image = #imageLiteral(resourceName: "LoadSaveState")
                text = NSLocalizedString("Load State", comment: "")
                
            case .fastForward:
                image = #imageLiteral(resourceName: "FastForward")
                text = NSLocalizedString("Fast Forward", comment: "")
            }
            
            let item = MenuItem(text: text, image: image) { (item) in
                guard let calloutView = self.calloutViews[AnyInput(input)] else { return }
                self.toggle(calloutView)
            }
            
            items.append(item)
        }
        
        self.actionsMenuViewController.items = items
        self.actionsMenuViewController.isVibrancyEnabled = false
    }
    
    func prepareCallouts()
    {
        guard
            let controllerView = self.gameViewController.controllerView,
            let traits = controllerView.controllerSkinTraits,
            let items = controllerView.controllerSkin?.items(for: traits),
            let controllerViewInputMapping = controllerView.inputMapping
        else { return }
        
        // Implicit assumption that all skins used for controller input mapping don't have multiple items with same input.
        let mappedInputs = items.flatMap { $0.inputs.allInputs.flatMap(controllerViewInputMapping.input(forControllerInput:)) } + (self.supportedActionInputs as [Input])
        
        // Create callout view for each on-screen input.
        for input in mappedInputs
        {
            let calloutView = InputCalloutView()
            calloutView.delegate = self
            self.calloutViews[AnyInput(input)] = calloutView
        }
        
        // Update callout views with controller inputs that map to callout views' associated controller skin inputs.
        for input in self.inputMapping.supportedControllerInputs
        {
            let mappedInput = self.mappedInput(for: input)
            
            if let calloutView = self.calloutViews[mappedInput]
            {
                if let previousInput = calloutView.input
                {
                    // Ensure the input we display has a higher priority.
                    calloutView.input = (input.displayPriority > previousInput.displayPriority) ? input : previousInput
                }
                else
                {
                    calloutView.input = input
                }
            }
        }
        
        // Present only callout views that are associated with a controller input.
        for calloutView in self.calloutViews.values
        {
            if let presentationRect = self.presentationRect(for: calloutView), calloutView.input != nil
            {
                calloutView.presentCallout(from: presentationRect, in: self.view, constrainedTo: self.view, animated: true)
            }
        }
    }
}

private extension ControllerInputsViewController
{
    func updateActiveCalloutView(with controllerInput: Input?)
    {
        guard let activeCalloutView = self.activeCalloutView else { return }
        
        guard let input = self.calloutViews.first(where: { $0.value == activeCalloutView })?.key else { return }
        
        if let controllerInput = controllerInput
        {
            for (_, calloutView) in self.calloutViews
            {
                guard let calloutInput = calloutView.input else { continue }
                
                if calloutInput == controllerInput
                {
                    // Hide callout views that previously displayed the controller input.
                    calloutView.input = nil
                    calloutView.dismissCallout(animated: true)
                }
            }
        }
        
        for supportedInput in self.inputMapping.supportedControllerInputs
        {
            let mappedInput = self.mappedInput(for: supportedInput)
            
            if mappedInput == input
            {
                // Set all existing controller inputs that currently map to "input" to instead map to nil.
                self.inputMapping.set(nil, forControllerInput: supportedInput)
            }
        }
        
        if let controllerInput = controllerInput
        {
            self.inputMapping.set(input, forControllerInput: controllerInput)
        }
        
        activeCalloutView.input = controllerInput
        
        self.toggle(activeCalloutView)
    }
    
    func toggle(_ calloutView: InputCalloutView)
    {
        if let activeCalloutView = self.activeCalloutView, activeCalloutView != calloutView
        {
            self.toggle(activeCalloutView)
        }
        
        let menuItem: MenuItem?
        
        if let input = self.calloutViews.first(where: { $0.value == calloutView })?.key, let index = self.supportedActionInputs.index(where: { $0 == input })
        {
            menuItem = self.actionsMenuViewController.items[index]
        }
        else
        {
            menuItem = nil
        }
        
        switch calloutView.state
        {
        case .normal:
            calloutView.state = .listening
            menuItem?.isSelected = true
            self.activeCalloutView = calloutView
            
        case .listening:
            calloutView.state = .normal
            menuItem?.isSelected = false
            self.activeCalloutView = nil
        }
        
        calloutView.dismissCallout(animated: true)
        
        if let presentationRect = self.presentationRect(for: calloutView)
        {
            if calloutView.state == .listening || calloutView.input != nil
            {
                calloutView.presentCallout(from: presentationRect, in: self.view, constrainedTo: self.view, animated: true)
            }
        }
    }
}

extension ControllerInputsViewController: UIGestureRecognizerDelegate
{
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool
    {
        return self.activeCalloutView != nil
    }
    
    @IBAction private func handleTapGesture(_ tapGestureRecognizer: UITapGestureRecognizer)
    {
        self.updateActiveCalloutView(with: nil)
    }
}

private extension ControllerInputsViewController
{
    func mappedInput(for input: Input) -> AnyInput
    {
        guard let mappedInput = self.inputMapping.input(forControllerInput: input) else {
            fatalError("Mapped input for provided input does not exist.")
        }
        
        if let standardInput = StandardGameControllerInput(input: mappedInput)
        {
            if let gameInput = standardInput.input(for: self.system.gameType)
            {
                return AnyInput(gameInput)
            }
        }
        
        return AnyInput(mappedInput)
    }
    
    func presentationRect(for calloutView: InputCalloutView) -> CGRect?
    {
        guard let input = self.calloutViews.first(where: { $0.value == calloutView })?.key else { return nil }
        
        guard
            let controllerView = self.gameViewController.controllerView,
            let traits = controllerView.controllerSkinTraits,
            let items = controllerView.controllerSkin?.items(for: traits)
        else { return nil }
        
        if let item = items.first(where: { $0.inputs.allInputs.contains(where: { $0.stringValue == input.stringValue })})
        {
            // Input is a controller skin input.
            
            let itemFrame: CGRect?
            
            switch item.inputs
            {
            case .standard: itemFrame = item.frame
            case let .directional(up, down, left, right):
                
                switch input.stringValue
                {
                case up.stringValue:
                    itemFrame = CGRect(x: item.frame.minX + item.frame.width / 3,
                                       y: item.frame.minY,
                                       width: item.frame.width / 3,
                                       height: item.frame.height / 3)
                case down.stringValue:
                    itemFrame = CGRect(x: item.frame.minX + item.frame.width / 3,
                                       y: item.frame.minY + (item.frame.height / 3) * 2,
                                       width: item.frame.width / 3,
                                       height: item.frame.height / 3)
                    
                case left.stringValue:
                    itemFrame = CGRect(x: item.frame.minX,
                                       y: item.frame.minY + (item.frame.height / 3),
                                       width: item.frame.width / 3,
                                       height: item.frame.height / 3)
                    
                case right.stringValue:
                    itemFrame = CGRect(x: item.frame.minX + (item.frame.width / 3) * 2,
                                       y: item.frame.minY + (item.frame.height / 3),
                                       width: item.frame.width / 3,
                                       height: item.frame.height / 3)
                    
                default: itemFrame = nil
                }
            }
            
            if let itemFrame = itemFrame
            {
                var presentationFrame = itemFrame.applying(CGAffineTransform(scaleX: controllerView.bounds.width, y: controllerView.bounds.height))
                presentationFrame = self.view.convert(presentationFrame, from: controllerView)
                
                return presentationFrame
            }
        }
        else if let index = self.supportedActionInputs.index(where: { $0 == input })
        {
            // Input is an ActionInput.
            
            let indexPath = IndexPath(item: index, section: 0)
            
            if let attributes = self.actionsMenuViewController.collectionViewLayout.layoutAttributesForItem(at: indexPath)
            {
                let presentationFrame = self.view.convert(attributes.frame, from: self.actionsMenuViewController.view)
                return presentationFrame
            }
        }
        else
        {
            // Input is not an on-screen input.
        }
        
        return nil
    }
}

extension ControllerInputsViewController: GameControllerReceiver
{
    func gameController(_ gameController: GameController, didActivate controllerInput: DeltaCore.Input)
    {
        switch gameController
        {
        case self.gameViewController.controllerView:
            if let calloutView = self.calloutViews[AnyInput(controllerInput)]
            {
                self.toggle(calloutView)
            }
            
        case self.gameController: self.updateActiveCalloutView(with: controllerInput)
            
        default: break
        }
    }
    
    func gameController(_ gameController: GameController, didDeactivate input: DeltaCore.Input)
    {
    }
}

extension ControllerInputsViewController: SMCalloutViewDelegate
{
    func calloutViewClicked(_ calloutView: SMCalloutView)
    {
        guard let calloutView = calloutView as? InputCalloutView else { return }

        self.toggle(calloutView)
    }
}
