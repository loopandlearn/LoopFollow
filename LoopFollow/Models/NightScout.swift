//
//  NightScout.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/5/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

class NightscoutService {
    
    static let singleton = NightscoutService()
    
    //NS BG Struct
    struct bgData: Codable {
        var sgv: Int
        var date: TimeInterval
        var direction: String?
        var hoursMinutes: String?
    }
    
    let DIRECTIONS = ["-", "↑↑", "↑", "↗", "→", "↘︎", "↓", "↓↓", "-", "-"]
    var url: String
    
    init(){
        url = UserDefaultsRepository.url.value
    }
    

    // Main NS Data Pull
    func loadBGData(hours: Int = UserDefaultsRepository.hoursToLoad.value) {
        let count = String(hours * 60/5)
        let token = UserDefaultsRepository.token.value
        var urlBGDataPath: String = url + "/api/v1/entries/sgv.json?"
        if token == "" {
            urlBGDataPath = urlBGDataPath + "count=" + String(count)
        }
        else
        {
            urlBGDataPath = urlBGDataPath + "token=" + token + "&count=" + String(count)
        }
        guard let urlBGData = URL(string: urlBGDataPath) else {
            return
        }
        var request = URLRequest(url: urlBGData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        let getBGTask = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([bgData].self, from: data)
            if let entriesResponse = entriesResponse {
                for i in 0..<entriesResponse.count {
                    
                }

            }
            
        }
        getBGTask.resume()
    }
    

    
}
