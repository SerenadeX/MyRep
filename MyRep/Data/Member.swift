//
//  Member.swift
//  MyRep
//
//  Created by Rhett Rogers on 6/5/20.
//  Copyright © 2020 Rhett Rogers. All rights reserved.
//

import Foundation

struct Member: Codable {
    /*
    name": "Karen Bass",
    "party": "Democrat",
    "state": "CA",
    "district": "37",
    "phone": "202-225-7084",
    "office": "2059 Rayburn House Office Building; Washington DC 20515-0537",
    "link": "https://bass.house.gov"
 */
    
    let name: String
    let party: String
    let state: String
    let district: String
    let phone: String
    let office: String
    let link: String
    
    var url: URL? {
        return URL(string: link)
    }
    
    var isSenator: Bool {
        return district.isEmpty
    }
    
    
}

struct RootMember: Codable {
    
    let results: [Member]
    
}
