//
//  ControlsEditorView.swift
//  Delta
//
//  Created by Caroline Moore on 7/1/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import SwiftUI
import CoreData

import DeltaCore

import NESDeltaCore
import SNESDeltaCore
import GBADeltaCore
import GBCDeltaCore
import N64DeltaCore
import MelonDSDeltaCore
import GPGXDeltaCore

@Observable
private class ControlsEditor
{
    let controller: GameController
    let system: System
    let playerIndex: Int
    
    let defaultMapping: DeltaCore.GameControllerInputMapping
    var inputMapping: DeltaCore.GameControllerInputMapping
    
    init(controller: GameController, system: System, playerIndex: Int)
    {
        self.controller = controller
        self.system = system
        self.playerIndex = playerIndex
        
        self.defaultMapping = controller.defaultInputMapping as? DeltaCore.GameControllerInputMapping ?? DeltaCore.GameControllerInputMapping(gameControllerInputType: controller.inputType)
        
        self.inputMapping = self.defaultMapping
        self.loadMapping()
    }
    
    // Creates an editable copy of the saved mapping, or the controller's default mapping.
    func loadMapping()
    {
        let existingMapping = GameControllerInputMapping.inputMapping(forPlayer: self.playerIndex, gameType: self.system.gameType, controllerType: self.controller.inputType, in: DatabaseManager.shared.viewContext)
        self.inputMapping = existingMapping?.deltaCoreInputMapping as? DeltaCore.GameControllerInputMapping ?? self.defaultMapping
    }
    
    func save()
    {
        // True when all inputs exactly match the controller's defaults.
        let isEffectivelyDefault = self.inputMapping.supportedControllerInputs.count == self.defaultMapping.supportedControllerInputs.count &&
        self.defaultMapping.supportedControllerInputs.allSatisfy {
            self.normalizedInput(self.inputMapping.input(forControllerInput: $0)) == self.normalizedInput(self.defaultMapping.input(forControllerInput: $0))
        }
        
        var inputMapping = self.inputMapping
        inputMapping.name = String.localizedStringWithFormat("Custom %@", self.controller.name)
        
        DatabaseManager.shared.performBackgroundTask { context in
            let existingMapping = GameControllerInputMapping.inputMapping(forPlayer: self.playerIndex, gameType: self.system.gameType, controllerType: self.controller.inputType, in: context)
            
            if isEffectivelyDefault
            {
                // A custom mapping was reset to default.
                if let existingMapping
                {
                    context.delete(existingMapping)
                }
            }
            else if let existingMapping
            {
                // A custom mapping was modified.
                existingMapping.deltaCoreInputMapping = inputMapping
            }
            else
            {
                // A default mapping was customized.
                let mapping = GameControllerInputMapping(inputMapping: inputMapping, context: context)
                mapping.gameControllerInputType = self.controller.inputType
                mapping.gameType = self.system.gameType
                mapping.playerIndex = Int16(self.playerIndex)
            }
            
            context.saveWithErrorLogging()
        }
    }
    
    // Resolve standard inputs to the system's game input before comparing or displaying. (Returns AnyInput so the Picker can use it for selection.)
    func normalizedInput(_ input: Input?) -> AnyInput?
    {
        guard let input else { return nil }
        
        if let standardInput = StandardGameControllerInput(input: input), let gameInput = standardInput.input(for: self.system.gameType)
        {
            return AnyInput(gameInput)
        }
        
        return AnyInput(input)
    }
}

// Edits the input mapping for one player + system + controller type.
struct ControlsEditorView: View
{
    @SwiftUI.State
    private var editor: ControlsEditor
    
    @SwiftUI.State
    private var isConfirmingReset = false
    
    @Environment(\.dismiss)
    private var dismiss
    
    init(controller: GameController, system: System, playerIndex: Int)
    {
        self._editor = SwiftUI.State(initialValue: ControlsEditor(controller: controller, system: system, playerIndex: playerIndex))
    }
    
    var body: some View {
        Form {
            if editor.controller.inputType == .keyboard
            {
                KeyboardMappingSections(editor: editor)
            }
            else
            {
                MFiMappingSections(editor: editor)
            }
        }
        .navigationTitle(editor.system.localizedDisplayName)
        .navigationBarTitleDisplayMode(.inline)
        // NavigationLink keeps this view alive after navigating back, so re-fetch the mapping whenever it appears.
        // (Only safe because this screen never pushes another view.)
        .onAppear(perform: editor.loadMapping)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    editor.save()
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .bottomBar) {
                Button("Reset All", role: .destructive) {
                    isConfirmingReset = true
                }
                .bold()
                .tint(.red)
                .confirmationDialog("Are you sure you want to reset all inputs?", isPresented: $isConfirmingReset, titleVisibility: .visible) {
                    Button("Reset All", role: .destructive) {
                        editor.inputMapping = editor.defaultMapping
                    }
                }
            }
        }
    }
}

// MARK: - Game Controller -

private struct MFiMappingSections: View
{
    let editor: ControlsEditor
    
    var body: some View {
        ForEach(InputSection.mfiSections, id: \.name) { section in
            Section(section.name) {
                ForEach(section.inputs, id: \.stringValue) { input in
                    InputMappingRow(editor: editor, controllerInput: input)
                }
            }
        }
    }
}

// MARK: - Keyboard -

private struct KeyboardMappingSections: View
{
    let editor: ControlsEditor
    
    var mappedStrings: Set<String> {
        Set(editor.inputMapping.supportedControllerInputs.map(\.stringValue))
    }
    
    // Show mapped keys in a stable order, then append any existing keys we haven't recognized so they stay visible.
    var mappedKeys: [Input] {
        let mapped = mappedStrings
        let recognized = InputSection.keyboardSections.flatMap(\.inputs)
        let ordered = recognized.filter { mapped.contains($0.stringValue) }
        let extras: [Input] = mapped.subtracting(recognized.map(\.stringValue)).sorted().map { KeyboardGameController.Input($0) }
        return ordered + extras
    }
    
    var body: some View {
        Section {
            ForEach(mappedKeys, id: \.stringValue) { key in
                InputMappingRow(editor: editor, controllerInput: key)
            }
            .onDelete { offsets in
                let keys = offsets.map { mappedKeys[$0] }
                for key in keys
                {
                    editor.inputMapping.set(nil, forControllerInput: key)
                }
            }
            
            Menu {
                ForEach(InputSection.keyboardSections, id: \.name) { section in
                    let availableKeys = section.inputs.filter { !mappedStrings.contains($0.stringValue) }
                    
                    if !availableKeys.isEmpty
                    {
                        Section(section.name) {
                            ForEach(availableKeys, id: \.stringValue) { key in
                                Button(key.localizedDisplayName) {
                                    if let defaultInput = editor.system.editorInputs.first
                                    {
                                        editor.inputMapping.set(defaultInput, forControllerInput: key)
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                Label("Add Key", systemImage: "plus")
            }
        }
    }
}

// MARK: - Components -

private struct InputSection
{
    let name: String
    let inputs: [Input]
    
    static let mfiSections: [InputSection] = [
        InputSection(name: String(localized: "Buttons"), inputs: [MFiGameController.Input.a, .b, .x, .y, .up, .down, .left, .right, .leftShoulder, .leftTrigger, .rightShoulder, .rightTrigger, .start, .select, .menu]),
        InputSection(name: String(localized: "Left Thumbstick"), inputs: [MFiGameController.Input.leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight]),
        InputSection(name: String(localized: "Right Thumbstick"), inputs: [MFiGameController.Input.rightThumbstickUp, .rightThumbstickDown, .rightThumbstickLeft, .rightThumbstickRight])
    ]
    
    static let keyboardSections: [InputSection] = [
        InputSection(name: String(localized: "Arrows"), inputs: [KeyboardGameController.Input.up, .down, .left, .right]),
        InputSection(name: String(localized: "Modifiers"), inputs: [KeyboardGameController.Input.shift, .control, .option, .command, .capsLock]),
        InputSection(name: String(localized: "Special Keys"), inputs: [KeyboardGameController.Input.space, .return, .tab, .escape]),
        InputSection(name: String(localized: "Letters"), inputs: "abcdefghijklmnopqrstuvwxyz".map { KeyboardGameController.Input(String($0)) }),
        InputSection(name: String(localized: "Numbers"), inputs: "0123456789".map { KeyboardGameController.Input(String($0)) }),
        InputSection(name: String(localized: "Symbols"), inputs: [",", ".", "/", ";", "'", "[", "]", "\\", "|", "-", "=", "`", "+", "*"].map { KeyboardGameController.Input($0) })
    ]
}

private struct InputMappingRow: View
{
    let editor: ControlsEditor
    let controllerInput: Input
    
    // AnyInput because the picker requires a Hashable type.
    static let actionInputs: [AnyInput] = [ActionInput.quickSave, .quickLoad, .fastForward, .screenshot].map(AnyInput.init)
    
    // The inputs that can be mapped to: this system's game inputs, plus Menu (pause).
    var mappableInputs: [AnyInput] {
        editor.system.editorInputs.map(AnyInput.init) + [AnyInput(StandardGameControllerInput.menu)]
    }
    
    var defaultInput: Input? {
        editor.defaultMapping.input(forControllerInput: controllerInput)
    }
    
    var body: some View {
        let isCustomized = editor.normalizedInput(editor.inputMapping.input(forControllerInput: controllerInput)) != editor.normalizedInput(defaultInput)
        
        Group {
            if #available(iOS 18, *)
            {
                Picker(selection: mappedInput) {
                    pickerOptions
                } label: {
                    Label(controllerInput.localizedDisplayName, systemImage: controllerInput.sfSymbolName)
                } currentValueLabel: {
                    Text(mappedInput.wrappedValue?.localizedDisplayName ?? String(localized: defaultInput == nil ? "Remove" : "Default"))
                }
            }
            else
            {
                Picker(selection: mappedInput) {
                    pickerOptions
                } label: {
                    Label(controllerInput.localizedDisplayName, systemImage: controllerInput.sfSymbolName)
                }
            }
        }
        .pickerStyle(.menu)
        .tint(isCustomized ? .accentColor : .secondary)
    }
    
    @ViewBuilder
    var pickerOptions: some View {
        Text(defaultInput == nil ? "Remove" : "Default")
            .tag(AnyInput?.none)
        
        Section {
            ForEach(mappableInputs, id: \.self) { input in
                Label(input.localizedDisplayName, systemImage: input.sfSymbolName)
                    .tint(Color(uiColor: .deltaPurple)) // Symbol should always be tinted
                    .tag(AnyInput?.some(input))
            }
        }
        
        Section("Game Actions") {
            ForEach(Self.actionInputs, id: \.self) { input in
                Label(input.localizedDisplayName, systemImage: input.sfSymbolName)
                    .tint(Color(uiColor: .deltaPurple)) 
                    .tag(AnyInput?.some(input))
            }
        }
    }
    
    var mappedInput: Binding<AnyInput?> {
        Binding(
            get: {
                let current = editor.normalizedInput(editor.inputMapping.input(forControllerInput: controllerInput))
                
                // Keyboard rows always show their mapped input; controller rows collapse to "Default" when unchanged.
                if controllerInput.type != .controller(.keyboard), current == editor.normalizedInput(defaultInput)
                {
                    return nil
                }
                
                return current
            },
            set: { newValue in
                editor.inputMapping.set(newValue ?? defaultInput, forControllerInput: controllerInput)
            }
        )
    }
}

// MARK: - Extensions -

private extension System
{
    // The game inputs a user can map controls to, per system, in display order.
    var editorInputs: [Input] {
        switch self
        {
        case .nes: return [.a, .b, .up, .down, .left, .right, .start, .select] as [NESGameInput]
        case .snes: return [.a, .b, .x, .y, .up, .down, .left, .right, .l, .r, .start, .select] as [SNESGameInput]
        case .gba: return [.a, .b, .up, .down, .left, .right, .l, .r, .start, .select] as [GBAGameInput]
        case .gbc: return [.a, .b, .up, .down, .left, .right, .start, .select] as [GBCGameInput]
        case .n64: return [.a, .b, .up, .down, .left, .right, .analogStickUp, .analogStickDown, .analogStickLeft, .analogStickRight, .cUp, .cDown, .cLeft, .cRight, .l, .r, .z, .start] as [N64GameInput]
        case .ds: return [.a, .b, .x, .y, .up, .down, .left, .right, .l, .r, .start, .select] as [MelonDSGameInput]
        case .genesis: return [.a, .b, .c, .x, .y, .z, .up, .down, .left, .right, .start, .mode] as [GPGXGameInput]
        }
    }
}
