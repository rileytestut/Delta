//
//  Campaign.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

extension PatreonAPI
{
    typealias CampaignResponse = DataResponse<CampaignAttributes, CampaignRelationships>
    
    struct CampaignAttributes: Decodable
    {
        var url: URL
    }
    
    struct CampaignRelationships: Decodable
    {
        var tiers: Response<[AnyItemResponse]>?
    }
}

extension PatreonAPI.Campaign
{
    static let rileyShaneID: String = "2863968"
}

extension PatreonAPI
{
    public struct Campaign
    {
        public var identifier: String
        public var url: URL
        
        public var tiers: [Tier]?
        
        internal init(response: PatreonAPI.CampaignResponse, including included: IncludedResponses?)
        {
            self.identifier = response.id
            self.url = response.attributes.url
            
            guard let included, let relationships = response.relationships, let tiers = relationships.tiers?.data else { return }
            
            var allTiers: [PatreonAPI.Tier] = []
            for tier in tiers
            {
                if let response = included.tiers[tier.id]
                {
                    let tier = PatreonAPI.Tier(response: response, including: included)
                    allTiers.append(tier)
                }
            }
            
            self.tiers = allTiers
        }
    }
}
