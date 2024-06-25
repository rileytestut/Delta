//
//  Patron.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

extension PatreonAPI
{
    typealias PatronResponse = DataResponse<PatronAttributes, PatronRelationships>
    
    struct PatronAttributes: Decodable
    {
        var full_name: String?
        var patron_status: String?
        var currently_entitled_amount_cents: Int32 // In campaign's currency
    }
    
    struct PatronRelationships: Decodable
    {
        var campaign: Response<AnyItemResponse>?
        var currently_entitled_tiers: Response<[AnyItemResponse]>?
    }
}

extension PatreonAPI
{
    public enum Status: String, Decodable
    {
        case active = "active_patron"
        case declined = "declined_patron"
        case former = "former_patron"
        case unknown = "unknown"
        case free = "free"
    }
    
    // Roughly equivalent to AltStoreCore.Pledge
    public class Patron
    {
        public var name: String?
        public var identifier: String
        public var pledgeAmount: Decimal?
        public var status: Status = .unknown
        
        // Relationships
        public var campaign: Campaign?
        public var tiers: Set<Tier> = []
        public var benefits: Set<Benefit> = []
        
        internal init(response: PatronResponse, including included: IncludedResponses?)
        {
            self.name = response.attributes.full_name
            self.identifier = response.id
            self.pledgeAmount = Decimal(response.attributes.currently_entitled_amount_cents) / 100
            
            guard let included, let relationships = response.relationships else { return }
            
            if let campaignID = relationships.campaign?.data.id, let response = included.campaigns[campaignID]
            {
                let campaign = Campaign(response: response)
                self.campaign = campaign
            }
                        
            let tiers = (relationships.currently_entitled_tiers?.data ?? []).compactMap { included.tiers[$0.id] }.map { Tier(response: $0, including: included) }
            self.tiers = Set(tiers)
            
            let benefits = tiers.flatMap { $0.benefits }
            self.benefits = Set(benefits)
            
            let status = Status(rawValue: response.attributes.patron_status ?? "") ?? .unknown
            if status == .active
            {
                // Active status is always active, regardless of current tiers.
                self.status = .active
            }
            else if tiers.contains(where: { $0.amount == 0 })
            {
                // Not active, but belongs to free tier, so treat as free member.
                self.status = .free
            }
            else
            {
                self.status = status
            }
        }
    }
}
