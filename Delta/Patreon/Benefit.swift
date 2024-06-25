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
    typealias BenefitResponse = DataResponse<BenefitAttributes, AnyRelationships>
    
    struct BenefitAttributes: Decodable
    {
        var title: String
    }
}

extension PatreonAPI
{
    public struct Benefit: Hashable
    {
        static let betaAccessID = "1186336"
        static let creditsID = "1186340"
        
        public var name: String
        public var identifier: String
        
        internal init(response: BenefitResponse)
        {
            self.name = response.attributes.title
            self.identifier = response.id
        }
    }
}
