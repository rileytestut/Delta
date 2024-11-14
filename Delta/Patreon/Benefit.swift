//
//  Benefit.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

extension PatreonAPI
{
    // PatreonAPI stopped returning full benefit metadata as of July 2024, so treat it like AnyItemResponse.
    // struct BenefitAttributes: Decodable
    // {
    //     var title: String
    // }
    
    typealias BenefitResponse = AnyItemResponse
    
    public struct BenefitID: RawRepresentable, Decodable, Hashable
    {
        static let betaAccess = BenefitID(rawValue: "1186336")
        static let credits = BenefitID(rawValue: "1186340")
        
        public let rawValue: String
        
        public init(rawValue: String)
        {
            self.rawValue = rawValue
        }
    }
}

extension PatreonAPI
{
    public struct Benefit: Hashable
    {
        public var identifier: BenefitID
        
        internal init(response: BenefitResponse)
        {
            self.identifier = BenefitID(rawValue: response.id)
        }
    }
}
