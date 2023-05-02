//
//  Filter.swift
//  Nos
//
//  Created by Christopher Jorgensen on 2/17/23.
//

import Foundation

/// Describes a set of Nostr Events, usually so we can ask relay servers for them.
struct Filter: Hashable, Identifiable {
    
    let authorKeys: [HexadecimalString]
    let eventIDs: [HexadecimalString]
    let kinds: [EventKind]
    let eTags: [HexadecimalString]
    let pTags: [HexadecimalString]
    let limit: Int?
    let since: Date?
    
    var id: String {
        String(hashValue)
    }

    init(
        authorKeys: [HexadecimalString] = [],
        eventIDs: [HexadecimalString] = [],
        kinds: [EventKind] = [],
        eTags: [HexadecimalString] = [],
        pTags: [HexadecimalString] = [],
        limit: Int? = nil,
        since: Date? = nil
    ) {
        self.authorKeys = authorKeys.sorted(by: { $0 > $1 })
        self.eventIDs = eventIDs
        self.kinds = kinds.sorted(by: { $0.rawValue > $1.rawValue })
        self.eTags = eTags
        self.pTags = pTags
        self.limit = limit
        self.since = since
    }
    
    var dictionary: [String: Any] {
        var filterDict = [String: Any]()
        
        if let limit {
            filterDict["limit"] = limit
        }

        if !authorKeys.isEmpty {
            filterDict["authors"] = authorKeys
        }
        
        if !eventIDs.isEmpty {
            filterDict["ids"] = eventIDs
        }

        if !kinds.isEmpty {
            filterDict["kinds"] = kinds.map({ $0.rawValue })
        }
        
        if !eTags.isEmpty {
            filterDict["#e"] = eTags
        }
        
        if !pTags.isEmpty {
            filterDict["#p"] = pTags
        }
        
        if let since {
            filterDict["since"] = Int(since.timeIntervalSince1970)
        }

        return filterDict
    }

    static func == (lhs: Filter, rhs: Filter) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(authorKeys)
        hasher.combine(eventIDs)
        hasher.combine(kinds)
        hasher.combine(limit)
        hasher.combine(eTags)
        hasher.combine(since)
    }
    
    func isFulfilled(by event: Event) -> Bool {
        guard limit == 1 else {
            return false
        }
        
        if kinds.count == 1,
            event.kind == kinds.first?.rawValue,
            !authorKeys.isEmpty,
            let authorKey = event.author?.hexadecimalPublicKey {
            return authorKeys.contains(authorKey)
        }
        
        return false
    }
}
