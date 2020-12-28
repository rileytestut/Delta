//
//  GameControllerInputMapping.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import Foundation

public struct GameControllerInputMapping: GameControllerInputMappingProtocol, Codable
{
    public var name: String?
    public var gameControllerInputType: GameControllerInputType
    
    public var supportedControllerInputs: [Input] {
        return self.inputMappings.keys.map { AnyInput(stringValue: $0, intValue: nil, type: .controller(self.gameControllerInputType)) }
    }
    
    private var inputMappings: [String: AnyInput]
    
    public init(gameControllerInputType: GameControllerInputType)
    {
        self.gameControllerInputType = gameControllerInputType
        
        self.inputMappings = [:]
    }
    
    public func input(forControllerInput controllerInput: Input) -> Input?
    {
        precondition(controllerInput.type == .controller(self.gameControllerInputType), "controllerInput.type must match GameControllerInputMapping.gameControllerInputType")
        
        let input = self.inputMappings[controllerInput.stringValue]
        return input
    }
}

public extension GameControllerInputMapping
{
    init(fileURL: URL) throws
    {
        let data = try Data(contentsOf: fileURL)
        
        let decoder = PropertyListDecoder()
        self = try decoder.decode(GameControllerInputMapping.self, from: data)
    }
    
    func write(to url: URL) throws
    {
        let encoder = PropertyListEncoder()
        
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
}

public extension GameControllerInputMapping
{
    mutating func set(_ input: Input?, forControllerInput controllerInput: Input)
    {
        precondition(controllerInput.type == .controller(self.gameControllerInputType), "controllerInput.type must match GameControllerInputMapping.gameControllerInputType")
        
        if let input = input
        {
            self.inputMappings[controllerInput.stringValue] = AnyInput(input)
        }
        else
        {
            self.inputMappings[controllerInput.stringValue] = nil
        }
    }
}
