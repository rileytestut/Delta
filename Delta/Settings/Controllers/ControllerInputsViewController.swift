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

#if os (iOS)
import SMCalloutView
#endif

import GameController

class ControllerInputsViewController: GCEventViewController // need to inherit from this so that tvOS handles b button correctly
{
    var gameController: GameController! {
        didSet {
            self.gameController.addReceiver(self, inputMapping: nil)
        }
    }
    
    var system: System = System.gba {
        didSet {
            guard self.system != oldValue else { return }
            self.updateSystem()
        }
    }
    
    private lazy var managedObjectContext: NSManagedObjectContext = DatabaseManager.shared.newBackgroundContext()
    private var inputMappings = [System: GameControllerInputMapping]()
    
    private let supportedActionInputs: [ActionInput] = [.quickSave, .quickLoad, .fastForward]
    
    private var gameViewController: DeltaCore.GameViewController!
    private var actionsMenuViewController: GridMenuViewController!

    #if os(iOS)
    private var calloutViews = [AnyInput: InputCalloutView]()
    
    private var activeCalloutView: InputCalloutView?
    
    @IBOutlet private var actionsMenuViewControllerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var cancelTapGestureRecognizer: UITapGestureRecognizer!
    #elseif os(tvOS)
    private var allMappedInputs = [Input]()
    
    private var inputDisplayMap = [AnyInput: Input?]()
    
    private var activeListeningInput: Input?
    
    @IBOutlet var tableView: UITableView!
    #endif
    
    public override var next: UIResponder? {
        return KeyboardResponder(nextResponder: super.next)
    }
    
    #if os (iOS)
    override var shouldAutorotate: Bool {
        return false
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    #endif
        
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.gameViewController.controllerView.addReceiver(self)
        
        #if os (iOS)
        self.navigationController?.navigationBar.barStyle = .black
        #endif
        
        NSLayoutConstraint.activate([self.gameViewController.gameView.centerYAnchor.constraint(equalTo: self.actionsMenuViewController.view.centerYAnchor)])
        
        self.preparePopoverMenuController()
        self.updateSystem()
        
        #if os(tvOS)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        #endif
        
        self.controllerUserInteractionEnabled = true
    }
    
    #if os (iOS)
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
    #endif
}

extension ControllerInputsViewController
{
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "embedGameViewController": self.gameViewController = segue.destination as? DeltaCore.GameViewController
        case "embedActionsMenuViewController":
            self.actionsMenuViewController = segue.destination as? GridMenuViewController
            self.prepareActionsMenuViewController()
            
        case "cancelControllerInputs": break
        case "saveControllerInputs":
            self.managedObjectContext.performAndWait {
                self.managedObjectContext.saveWithErrorLogging()
            }
            
        default: break
        }
    }
}

private extension ControllerInputsViewController
{
    func makeDefaultInputMapping() -> GameControllerInputMapping
    {
        let deltaCoreInputMapping = self.gameController.defaultInputMapping as? DeltaCore.GameControllerInputMapping ?? DeltaCore.GameControllerInputMapping(gameControllerInputType: gameController.inputType)
        
        let inputMapping = GameControllerInputMapping(inputMapping: deltaCoreInputMapping, context: self.managedObjectContext)
        inputMapping.gameControllerInputType = gameController.inputType
        inputMapping.gameType = self.system.gameType
        
        if let controller = self.gameController, let playerIndex = controller.playerIndex
        {
            inputMapping.playerIndex = Int16(playerIndex)
        }
        
        return inputMapping
    }
    
    func updateSystem()
    {
        guard self.isViewLoaded else { return }
        
        // Update popoverMenuButton to display correctly on iOS 10.
        if let popoverMenuButton = self.navigationItem.popoverMenuController?.popoverMenuButton
        {
            popoverMenuButton.title = self.system.localizedShortName
            popoverMenuButton.bounds.size = popoverMenuButton.intrinsicContentSize
            
            self.navigationController?.navigationBar.layoutIfNeeded()
        }
        
        // Update controller view's controller skin.
        self.gameViewController.controllerView.controllerSkin = DeltaCore.ControllerSkin.standardControllerSkin(for: self.system.gameType)
        self.gameViewController.view.setNeedsUpdateConstraints()
        
        // Fetch input mapping if it hasn't already been fetched.
        if let gameController = self.gameController, self.inputMappings[self.system] == nil
        {
            self.managedObjectContext.performAndWait {
                let inputMapping = GameControllerInputMapping.inputMapping(for: gameController, gameType: self.system.gameType, in: self.managedObjectContext) ?? self.makeDefaultInputMapping()
                
                inputMapping.name = String.localizedStringWithFormat("Custom %@", gameController.name)
                
                self.inputMappings[self.system] = inputMapping
            }
        }
        #if os (iOS)
        // Update callouts, if view is already on screen.
        if self.view.window != nil
        {
            self.calloutViews.forEach { $1.dismissCallout(animated: true) }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.calloutViews = [:]
                self.prepareCallouts()
            }
        }
        #elseif os (tvOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.inputDisplayMap = [:]
            self.prepareCallouts()
        }
        #endif
    }
    
    func preparePopoverMenuController()
    {
        let listMenuViewController = ListMenuViewController()
        listMenuViewController.title = NSLocalizedString("Game System", comment: "")
        
        let navigationController = UINavigationController(rootViewController: listMenuViewController)
        
        let popoverMenuController = PopoverMenuController(popoverViewController: navigationController)
        self.navigationItem.popoverMenuController = popoverMenuController
        
        let items = System.allCases.map { [unowned self, weak popoverMenuController, weak listMenuViewController] system -> MenuItem in
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
            case .quickSave:
                image = #imageLiteral(resourceName: "SaveSaveState")
                text = NSLocalizedString("Quick Save", comment: "")
                
            case .quickLoad:
                image = #imageLiteral(resourceName: "LoadSaveState")
                text = NSLocalizedString("Quick Load", comment: "")
                
            case .fastForward:
                image = #imageLiteral(resourceName: "FastForward")
                text = NSLocalizedString("Fast Forward", comment: "")
            }
            
            let item = MenuItem(text: text, image: image) { [unowned self] (item) in
                #if os (iOS)
                guard let calloutView = self.calloutViews[AnyInput(input)] else { return }
                self.toggle(calloutView)
                #elseif os (tvOS)
                // TODO: this, but for tvOS
                #endif
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
            let controllerViewInputMapping = controllerView.defaultInputMapping,
            let inputMapping = self.inputMappings[self.system]
        else { return }
        
                // po inputMapping
        //        {
        //            deltaCoreInputMapping = DeltaCore.GameControllerInputMapping(
        //                name: Optional("Custom Nimbus"),
        //                gameControllerInputType: __C.GameControllerInputType(_rawValue: mfi),
        //                inputMappings:
        //                    ["rightThumbstickRight": AnyInput(stringValue: "rightThumbstickRight", intValue: nil),
        //                     "down": AnyInput(stringValue: "down", intValue: nil),
        //                     "rightThumbstickDown": AnyInput(stringValue: "rightThumbstickDown", intValue: nil),
        //                     "leftTrigger": AnyInput(stringValue: "l2", intValue: nil),
        //                     "x": AnyInput(stringValue: "x", intValue: nil),
        //                     "leftThumbstickRight": AnyInput(stringValue: "leftThumbstickRight", intValue: nil),
        //                     "y": AnyInput(stringValue: "y", intValue: nil),
        //                     "leftThumbstickUp": AnyInput(stringValue: "leftThumbstickUp", intValue: nil),
        //                     "rightThumbstickUp": AnyInput(stringValue: "rightThumbstickUp", intValue: nil),
        //                     "a": AnyInput(stringValue: "a", intValue: nil),
        //                     "leftShoulder": AnyInput(stringValue: "l1", intValue: nil),
        //                     "rightThumbstickLeft": AnyInput(stringValue: "rightThumbstickLeft", intValue: nil),
        //                     "b": AnyInput(stringValue: "b", intValue: nil),
        //                     "leftThumbstickDown": AnyInput(stringValue: "leftThumbstickDown", intValue: nil),
        //                     "rightShoulder": AnyInput(stringValue: "r1", intValue: nil),
        //                     "up": AnyInput(stringValue: "up", intValue: nil),
        //                     "left": AnyInput(stringValue: "left", intValue: nil),
        //                     "rightTrigger": AnyInput(stringValue: "r2", intValue: nil),
        //                     "leftThumbstickLeft": AnyInput(stringValue: "leftThumbstickLeft", intValue: nil),
        //                     "menu": AnyInput(stringValue: "menu", intValue: nil),
        //                     "right": AnyInput(stringValue: "right", intValue: nil)
        //                    ]
        //            );
        //            gameControllerInputType = mfi;
        //            gameType = "com.rileytestut.delta.game.nes";
        //            identifier = "C699D47F-8CF1-4A56-9B8E-F2EAECB24C98";
        //            playerIndex = 0;
        //        }
        
        // Implicit assumption that all skins used for controller input mapping don't have multiple items with same input.
        let mappedInputs = items.flatMap { $0.inputs.allInputs.compactMap(controllerViewInputMapping.input(forControllerInput:)) } + (self.supportedActionInputs as [Input])
        
        #if os(tvOS)
        self.allMappedInputs = mappedInputs
        #endif
        
        // Create callout view for each on-screen input.
        for input in mappedInputs
        {
            #if os (iOS)
            let calloutView = InputCalloutView()
            calloutView.delegate = self
            self.calloutViews[AnyInput(input)] = calloutView
            #elseif os (tvOS)
            self.inputDisplayMap[AnyInput(input)] = input
            #endif
        }

        self.managedObjectContext.performAndWait {
            // Update callout views with controller inputs that map to callout views' associated controller skin inputs.
            for input in inputMapping.supportedControllerInputs // GameControllerInputType
            {
                let mappedInput = self.mappedInput(for: input)

                #if os (iOS)
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
                #elseif os(tvOS)
                self.inputDisplayMap[AnyInput(input)] = input
                #endif
            }
        }
        
        #if os (iOS)
        // Present only callout views that are associated with a controller input.
        for calloutView in self.calloutViews.values
        {
            if let presentationRect = self.presentationRect(for: calloutView), calloutView.input != nil
            {
                calloutView.presentCallout(from: presentationRect, in: self.view, constrainedTo: self.view, animated: true)
            }
        }
        #elseif os (tvOS)
        self.tableView.reloadData()
        #endif
    }
}

private extension ControllerInputsViewController
{
    #if os(iOS)
    func updateActiveCalloutView(with controllerInput: Input?)
    {
        guard let inputMapping = self.inputMappings[self.system] else { return }
        
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
        
        self.managedObjectContext.performAndWait {
            for supportedInput in inputMapping.supportedControllerInputs
            {
                let mappedInput = self.mappedInput(for: supportedInput)
                
                if mappedInput == input
                {
                    // Set all existing controller inputs that currently map to "input" to instead map to nil.
                    inputMapping.set(nil, forControllerInput: supportedInput)
                }
            }
            
            if let controllerInput = controllerInput
            {
                inputMapping.set(input, forControllerInput: controllerInput)
            }
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
        
        if let input = self.calloutViews.first(where: { $0.value == calloutView })?.key, let index = self.supportedActionInputs.firstIndex(where: { $0 == input })
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
    #endif
    
    #if os(tvOS)
    func updateWaitingCell(with controllerInput: Input?)
    {
        guard let inputMapping = self.inputMappings[self.system] else {
            self.controllerUserInteractionEnabled = true
            return
        }

        guard let input = self.activeListeningInput else {
            self.controllerUserInteractionEnabled = true
            return
        }
        
        if let controllerInput = controllerInput
        {
            inputDisplayMap.forEach { (key: AnyInput, value: Input?) in
                guard let calloutInput = value else { return }
                
                if calloutInput.stringValue == controllerInput.stringValue {
                   // Hide callout views that previously displayed the controller input.
                    inputDisplayMap[key] = nil
                }
            }
        }

        self.managedObjectContext.performAndWait {
            for supportedInput in inputMapping.supportedControllerInputs
            {
                
                let mappedInput = self.mappedInput(for: supportedInput)

                if mappedInput == input
                {
                    // Set all existing controller inputs that currently map to "input" to instead map to nil.
                    inputMapping.set(nil, forControllerInput: supportedInput)
                }
            }

            if let controllerInput = controllerInput
            {
                inputMapping.set(input, forControllerInput: controllerInput)
            }
        }

        self.activeListeningInput = nil
        
        self.inputDisplayMap[AnyInput(input)] = controllerInput
        
        self.tableView.reloadData()
    }
    #endif
    
    @IBAction func resetInputMapping(_ sender: UIBarButtonItem)
    {
        func reset()
        {
            self.managedObjectContext.perform {
                guard let inputMapping = self.inputMappings[self.system] else { return }
                
                self.managedObjectContext.delete(inputMapping)
                self.inputMappings[self.system] = nil
                
                DispatchQueue.main.async {
                    self.updateSystem()
                }
            }
        }
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(.cancel)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Reset Controls to Defaults", comment: ""), style: .destructive, handler: { (action) in
            reset()
        }))
        self.present(alertController, animated: true, completion: nil)
    }
}

#if os (iOS)
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
#endif

private extension ControllerInputsViewController
{
    func mappedInput(for input: Input) -> AnyInput
    {
        guard let inputMapping = self.inputMappings[self.system] else {
            fatalError("Input mapping for current system does not exist.")
        }
        
        guard let mappedInput = inputMapping.input(forControllerInput: input) else {
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

    #if os (iOS)
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
            case .touch: itemFrame = item.frame
            case let .directional(up, down, left, right):
                let frame = (item.kind == .thumbstick) ? item.extendedFrame : item.frame
                
                switch input.stringValue
                {
                case up.stringValue:
                    itemFrame = CGRect(x: frame.minX + frame.width / 3,
                                       y: frame.minY,
                                       width: frame.width / 3,
                                       height: frame.height / 3)
                case down.stringValue:
                    itemFrame = CGRect(x: frame.minX + frame.width / 3,
                                       y: frame.minY + (frame.height / 3) * 2,
                                       width: frame.width / 3,
                                       height: frame.height / 3)
                    
                case left.stringValue:
                    itemFrame = CGRect(x: frame.minX,
                                       y: frame.minY + (frame.height / 3),
                                       width: frame.width / 3,
                                       height: frame.height / 3)
                    
                case right.stringValue:
                    itemFrame = CGRect(x: frame.minX + (frame.width / 3) * 2,
                                       y: frame.minY + (frame.height / 3),
                                       width: frame.width / 3,
                                       height: frame.height / 3)
                    
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
        else if let index = self.supportedActionInputs.firstIndex(where: { $0 == input })
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
    #endif
}

extension ControllerInputsViewController: GameControllerReceiver
{
    func gameController(_ gameController: GameController, didActivate controllerInput: DeltaCore.Input, value: Double)
    {
        guard self.isViewLoaded else { return }

        #if os(tvOS)
        guard self.activeListeningInput != nil else {
            self.controllerUserInteractionEnabled = true
            return
        }
        #endif
        
        switch gameController
        {
        case self.gameViewController.controllerView:
            #if os (iOS)
            if let calloutView = self.calloutViews[AnyInput(controllerInput)]
            {
                self.toggle(calloutView)
            }
            #endif
            
        case self.gameController:
            #if os (iOS)
            self.updateActiveCalloutView(with: controllerInput)
            #elseif os(tvOS)
            self.updateWaitingCell(with: controllerInput)
            #endif
            
        default: break
        }
    }
    
    func gameController(_ gameController: GameController, didDeactivate input: DeltaCore.Input)
    {
    }
}

#if os (iOS)
extension ControllerInputsViewController: SMCalloutViewDelegate
{
    func calloutViewClicked(_ calloutView: SMCalloutView)
    {
        guard let calloutView = calloutView as? InputCalloutView else { return }

        self.toggle(calloutView)
    }
}
#endif

#if os(tvOS)
extension ControllerInputsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.allMappedInputs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let input = self.allMappedInputs[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "InputCell", for: indexPath)
        cell.textLabel?.text = input.stringValue
        
        if let activeListeningInput = self.activeListeningInput, activeListeningInput == input {
            cell.detailTextLabel?.text = "AWAITING INPUT"
        } else {
            if let mappedVal = self.inputDisplayMap[AnyInput(input)], let validMappedVal = mappedVal {
                cell.detailTextLabel?.text = validMappedVal.stringValue
            } else {
                cell.detailTextLabel?.text = "none/Default"
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let input = self.allMappedInputs[indexPath.row]
        self.activeListeningInput = input
        self.controllerUserInteractionEnabled = false // tells tvOS to NOT let UIKit know about controller input; will reset after input is received
        self.tableView.reloadData()
    }
}

#endif
