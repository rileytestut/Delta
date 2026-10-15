//
//  CommissionManager.swift
//  AltStore
//
//  Created by Riley Testut on 12/18/25.
//  Copyright © 2025 Riley Testut. All rights reserved.
//

import Foundation
import MarketplaceKit
import StoreKit

extension CommissionManager
{
    enum CommissionError: CustomNSError
    {
        case unknown(failure: String, failureReason: String)
        
        var errorFailure: String? {
            switch self
            {
            case .unknown(let failure, _): return failure
            }
        }
        
        var failureReason: String? {
            switch self
            {
            case .unknown(_, let failureReason): return failureReason
            }
        }
        
        var errorUserInfo: [String : Any] {
            return [
                NSLocalizedFailureReasonErrorKey: self.failureReason,
                NSLocalizedFailureErrorKey: self.errorFailure
            ].compactMapValues( { $0 } )
        }
    }
}

public class CommissionManager
{
    static let shared = CommissionManager()
    
    #if STAGING
    private let baseURL = URL(string: "https://dev.altstore.io")!
    #else
    private let baseURL = URL(string: "https://api.altstore.io")!
    #endif
    
    private let session = URLSession(configuration: .ephemeral)
    
    private init()
    {
    }
}

extension CommissionManager
{
    func requestCommissionToken() async throws -> String?
    {
        guard
            let commissionRegion = await PurchaseManager.shared.commissionRegion,
            let region = ExternalPurchaseRegion(region: commissionRegion), region.requiresTransactionReporting
        else { return nil }
        
        let encodedToken: String
        
        let distributor = await PurchaseManager.shared.distributor
        switch distributor
        {
        case .appStore, .testFlight, .other, .web:
            // Installed via App Store/TestFlight (or App Review for `other`), so request token via ExternalPurchaseCustomLink.
            
            if #available(iOS 18.1, *)
            {
                guard let token = try await ExternalPurchaseCustomLink.token(for: "IN_APP") else { return nil }
                encodedToken = token.value
            }
            else
            {
                // Can't generate External Purchase token pre-iOS 18.1, so we can't report commissions to Apple.
                return nil
            }
            
        case .altStore:
            // Installed via AltStore or web, so request token via TransactionReporting.
            
            if #available(iOS 26.2, *)
            {
                encodedToken = try await TransactionReporting.token(for: .coreTechnology)
            }
            else
            {
                // Can't generate CTC token pre-iOS 26.2, so we can't report commissions to Apple.
                return nil
            }
        }
        
        struct Request: Encodable
        {
            var externalPurchaseToken: String
            var region: String
        }
        
        let body = Request(externalPurchaseToken: encodedToken, region: commissionRegion)
        let bodyData = try JSONEncoder().encode(body)
        
        let requestURL = self.baseURL.appending(path: "delta-external-purchases")
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (_, response) = try await self.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            let failure = String(format: NSLocalizedString("Failed to retrieve commission token from Apple. Error Code: %@", comment: ""), httpResponse.statusCode as NSNumber)
            let failureReason = String(localized: "The server returned an error (HTTP \(httpResponse.statusCode)).", )
            throw CommissionError.unknown(failure: failure, failureReason: failureReason)
        }
        
        Logger.main.info("Registered token \(encodedToken, privacy: .public) for potential Patreon purchase.")
        
        return encodedToken
    }
    
    func link(token: String, withAccountID accountID: String, membershipID: String?) async throws
    {
        struct Request: Encodable
        {
            var externalPurchaseToken: String
            var accountID: String
            var membershipID: String?
        }
        
        let body = Request(externalPurchaseToken: token, accountID: accountID, membershipID: membershipID)
        let bodyData = try JSONEncoder().encode(body)
        
        let requestURL = self.baseURL.appending(path: "link-delta-purchase")
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let (_, response) = try await self.session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        guard httpResponse.statusCode == 200 else {
            let failure = String(localized: "Failed to link commission token with Patreon account.", comment: "")
            let failureReason = String(localized: "The server returned an error (HTTP \(httpResponse.statusCode)).", )
            throw CommissionError.unknown(failure: failure, failureReason: failureReason)
        }
        
        Logger.main.info("Linked token \(token, privacy: .public) with Patreon account \(accountID, privacy: .public) with membership \(membershipID ?? "nil", privacy: .public)")
    }
}
