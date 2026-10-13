//
//  Tier.swift
//  AltStore
//
//  Created by Riley Testut on 8/21/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

extension PatreonAPI
{
    typealias TierResponse = DataResponse<TierAttributes, TierRelationships>
    
    struct TierAttributes: Decodable
    {
        var title: String?
        var amount_cents: Int32 // In USD
        var patron_count: Int32?
        var url: String?
    }
    
    struct TierRelationships: Decodable
    {
        var benefits: Response<[AnyItemResponse]>?
    }
}

extension PatreonAPI.Tier
{
    static let earlyAdopterTierID: String = "4023021"
}

extension PatreonAPI
{
    public struct Tier: Hashable
    {
        public var name: String?
        public var identifier: String
        public var amount: Decimal
        public var url: URL?
        
        // Relationships
        public var benefits: [Benefit] = []
        
        internal init(response: TierResponse, including included: IncludedResponses?)
        {
            self.name = response.attributes.title
            self.identifier = response.id
            
            let amount = Decimal(response.attributes.amount_cents) / 100
            self.amount = amount
            
            let benefits = response.relationships?.benefits?.data.map(Benefit.init(response:))
            self.benefits = benefits ?? []
            
            if let url = response.attributes.url, let sanitizedURL = url.removingPercentEncoding
            {
                // API docs say "fully-qualified", but in practice it seems to be a relative URL.
                // Check for both just in case.
                if url.hasPrefix("/")
                {
                    // Relative URL
                    self.url = URL(string: "https://patreon.com")?.appending(path: sanitizedURL)
                }
                else
                {
                    // Absolute URL
                    self.url = URL(string: url)
                }
            }
        }
    }
}
