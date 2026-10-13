//
//  ExternalPurchaseRegion.swift
//  Delta
//
//  Created by Riley Testut on 10/1/26.
//  Copyright © 2026 Riley Testut. All rights reserved.
//

import Foundation

// Exhaustive list of all regions where external purchases are allowed (and supported by us).
enum ExternalPurchaseRegion
{
    case usa
    case japan
    case brazil
    
    // European Union
    case austria
    case belgium
    case bulgaria
    case croatia
    case cyprus
    case czechia
    case denmark
    case estonia
    case finland
    case france
    case germany
    case greece
    case hungary
    case ireland
    case italy
    case latvia
    case lithuania
    case luxembourg
    case malta
    case netherlands
    case poland
    case portugal
    case romania
    case slovakia
    case slovenia
    case spain
    case sweden

    var isEUCountry: Bool {
        switch self
        {
        case .usa, .japan, .brazil: return false
        case .belgium, .bulgaria, .czechia, .denmark, .germany, .estonia, .ireland,
             .greece, .spain, .france, .croatia, .italy, .cyprus, .latvia,
             .lithuania, .luxembourg, .hungary, .malta, .netherlands, .austria,
             .poland, .portugal, .romania, .slovenia, .slovakia, .finland, .sweden: return true
        }
    }
    
    var requiresTransactionReporting: Bool {
        switch self
        {
        case .usa: return false
        case .japan, .brazil: return true
        case .belgium, .bulgaria, .czechia, .denmark, .germany, .estonia, .ireland,
             .greece, .spain, .france, .croatia, .italy, .cyprus, .latvia,
             .lithuania, .luxembourg, .hungary, .malta, .netherlands, .austria,
             .poland, .portugal, .romania, .slovenia, .slovakia, .finland, .sweden: return true
        }
    }
    
    var requiresExternalPurchasesOrOffersEntitlement: Bool {
        switch self
        {
        case .usa: return false
        case .japan, .brazil: return true
        case .belgium, .bulgaria, .czechia, .denmark, .germany, .estonia, .ireland,
             .greece, .spain, .france, .croatia, .italy, .cyprus, .latvia,
             .lithuania, .luxembourg, .hungary, .malta, .netherlands, .austria,
             .poland, .portugal, .romania, .slovenia, .slovakia, .finland, .sweden: return true
        }
    }
    
    // ISO 3166-1 alpha-3
    var countryCode: String {
        switch self
        {
        case .usa: "USA"
        case .japan: "JPN"
        case .brazil: "BRA"

        // European Union
        case .belgium: "BEL"
        case .bulgaria: "BGR"
        case .czechia: "CZE"
        case .denmark: "DNK"
        case .germany: "DEU"
        case .estonia: "EST"
        case .ireland: "IRL"
        case .greece: "GRC"
        case .spain: "ESP"
        case .france: "FRA"
        case .croatia: "HRV"
        case .italy: "ITA"
        case .cyprus: "CYP"
        case .latvia: "LVA"
        case .lithuania: "LTU"
        case .luxembourg: "LUX"
        case .hungary: "HUN"
        case .malta: "MLT"
        case .netherlands: "NLD"
        case .austria: "AUT"
        case .poland: "POL"
        case .portugal: "PRT"
        case .romania: "ROU"
        case .slovenia: "SVN"
        case .slovakia: "SVK"
        case .finland: "FIN"
        case .sweden: "SWE"
        }
    }
    
    // ISO 3166-1 alpha-2
    var region: String {
        switch self
        {
        case .usa: "us"
        case .japan: "jp"
        case .brazil: "br"

        // European Union
        case .belgium: "be"
        case .bulgaria: "bg"
        case .czechia: "cz"
        case .denmark: "dk"
        case .germany: "de"
        case .estonia: "ee"
        case .ireland: "ie"
        case .greece: "gr"
        case .spain: "es"
        case .france: "fr"
        case .croatia: "hr"
        case .italy: "it"
        case .cyprus: "cy"
        case .latvia: "lv"
        case .lithuania: "lt"
        case .luxembourg: "lu"
        case .hungary: "hu"
        case .malta: "mt"
        case .netherlands: "nl"
        case .austria: "at"
        case .poland: "pl"
        case .portugal: "pt"
        case .romania: "ro"
        case .slovenia: "si"
        case .slovakia: "sk"
        case .finland: "fi"
        case .sweden: "se"
        }
    }
    
    init?(countryCode: String) {
        switch countryCode.uppercased()
        {
        case Self.usa.countryCode: self = .usa
        case Self.japan.countryCode: self = .japan
        case Self.brazil.countryCode: self = .brazil

        // European Union
        case Self.belgium.countryCode: self = .belgium
        case Self.bulgaria.countryCode: self = .bulgaria
        case Self.czechia.countryCode: self = .czechia
        case Self.denmark.countryCode: self = .denmark
        case Self.germany.countryCode: self = .germany
        case Self.estonia.countryCode: self = .estonia
        case Self.ireland.countryCode: self = .ireland
        case Self.greece.countryCode: self = .greece
        case Self.spain.countryCode: self = .spain
        case Self.france.countryCode: self = .france
        case Self.croatia.countryCode: self = .croatia
        case Self.italy.countryCode: self = .italy
        case Self.cyprus.countryCode: self = .cyprus
        case Self.latvia.countryCode: self = .latvia
        case Self.lithuania.countryCode: self = .lithuania
        case Self.luxembourg.countryCode: self = .luxembourg
        case Self.hungary.countryCode: self = .hungary
        case Self.malta.countryCode: self = .malta
        case Self.netherlands.countryCode: self = .netherlands
        case Self.austria.countryCode: self = .austria
        case Self.poland.countryCode: self = .poland
        case Self.portugal.countryCode: self = .portugal
        case Self.romania.countryCode: self = .romania
        case Self.slovenia.countryCode: self = .slovenia
        case Self.slovakia.countryCode: self = .slovakia
        case Self.finland.countryCode: self = .finland
        case Self.sweden.countryCode: self = .sweden

        default: return nil
        }
    }
    
    init?(region: String) {
        switch region.lowercased()
        {
        case Self.usa.region: self = .usa
        case Self.japan.region: self = .japan
        case Self.brazil.region: self = .brazil

        // European Union
        case Self.belgium.region: self = .belgium
        case Self.bulgaria.region: self = .bulgaria
        case Self.czechia.region: self = .czechia
        case Self.denmark.region: self = .denmark
        case Self.germany.region: self = .germany
        case Self.estonia.region: self = .estonia
        case Self.ireland.region: self = .ireland
        case Self.greece.region: self = .greece
        case Self.spain.region: self = .spain
        case Self.france.region: self = .france
        case Self.croatia.region: self = .croatia
        case Self.italy.region: self = .italy
        case Self.cyprus.region: self = .cyprus
        case Self.latvia.region: self = .latvia
        case Self.lithuania.region: self = .lithuania
        case Self.luxembourg.region: self = .luxembourg
        case Self.hungary.region: self = .hungary
        case Self.malta.region: self = .malta
        case Self.netherlands.region: self = .netherlands
        case Self.austria.region: self = .austria
        case Self.poland.region: self = .poland
        case Self.portugal.region: self = .portugal
        case Self.romania.region: self = .romania
        case Self.slovenia.region: self = .slovenia
        case Self.slovakia.region: self = .slovakia
        case Self.finland.region: self = .finland
        case Self.sweden.region: self = .sweden

        default: return nil
        }
    }
}
