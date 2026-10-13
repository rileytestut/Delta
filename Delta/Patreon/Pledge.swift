//
//  Pledge.swift
//  Delta
//
//  Created by Riley Testut on 10/1/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation

extension PatreonAPI
{
    typealias PledgeResponse = DataResponse<PledgeAttributes, AnyRelationships>
    
    struct PledgeAttributes: Decodable
    {
        var amount_cents: Int // In currency user paid in
        var currency_code: String // Currency user paid in
        var payment_status: PaymentStatus
    }
}

extension PatreonAPI
{
    public struct PaymentStatus: Hashable, Decodable, RawRepresentable
    {
        public static let paid = PaymentStatus(rawValue: "Paid")
        public static let pending = PaymentStatus(rawValue: "Pending")
        public static let freeTrial = PaymentStatus(rawValue: "Free Trial")
        
        public let rawValue: String
        
        public init(rawValue: RawValue)
        {
            self.rawValue = rawValue
        }
    }
    
    public struct Pledge: Hashable, Decodable
    {
        public var amount: Decimal
        public var currency: String
        public var status: PaymentStatus
        
        internal init(response: PledgeResponse, including included: IncludedResponses?)
        {
            let amount = Decimal(response.attributes.amount_cents) / 100
            self.amount = amount
            
            self.currency = response.attributes.currency_code
            self.status = response.attributes.payment_status
        }
    }
}
