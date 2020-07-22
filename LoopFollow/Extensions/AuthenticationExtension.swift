//
//  AuthenticationDelegateExtension.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/20/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit
import ShareClient

extension MainViewController {

   // authentication delegate implementation
   /*
   func nightscoutDidConnect() -> Bool {
      return true
   }
   func dexcomDidConnect() -> Bool {
   
      var valid = false  // figure out valid
      let shareUserName = UserDefaultsRepository.shareUserName.value
      let sharePassword = UserDefaultsRepository.sharePassword.value
      let shareServer = UserDefaultsRepository.shareServer.value == "US" ?KnownShareServers.US.rawValue : KnownShareServers.NON_US.rawValue
      dexShare = ShareClient(username: shareUserName, password: sharePassword, shareServer: shareServer )
      
      let semaphore = DispatchSemaphore(value: 0)
      dexShare?.fetchData(1) { (err,result) in
         if(err == nil ) {           
            if result != nil {
               valid = true
            }
         }
         semaphore.signal()
      }
      
      // wait 30 seconds for share to complete
      let timeout: DispatchTimeoutResult = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(30))
      
      // timed out; This will probably never happen. Assuming share has its own timeout logic
      if(timeout == .timedOut) {
         let alert = UIAlertController(title:"Authentication Failure", message: "Dexcom Share service could not be reached. Please double check internet connection.", preferredStyle: .alert)
         alert.addAction(UIAlertAction(title:"Close", style: .default, handler: nil))
         self.present(alert, animated: true)
         return false
      }
      
      // returned before timeout
      if( !valid ) {
      
         // depending on how share implements timeout, internet conenction could still be at fault
         let alert = UIAlertController(title:"Authentication Failure", message: "Failed to authenticate to Dexcom. Please double check user name and password as well as internet connections.", preferredStyle: .alert)
         alert.addAction(UIAlertAction(title:"Close", style: .default, handler: nil))
         self.present(alert, animated: true)
         return false
      }
      
      // authenticated
      return true
   }
   */
   
   // notification authentication implementation
   func setupAuthNotification() {
      NotificationCenter.default.addObserver(self, selector: #selector(needDexcomAuthentication(_:)), name: .needDexcomAuthentication, object: nil)
      NotificationCenter.default.addObserver(self, selector: #selector(needNightscoutAuthentication(_:)), name: .needNightscoutAuthentication, object: nil)
      
   }
   @objc func needDexcomAuthentication(_ notification: Notification) {
   
      let shareUserName = UserDefaultsRepository.shareUserName.value
      let sharePassword = UserDefaultsRepository.sharePassword.value
      let shareServer = UserDefaultsRepository.shareServer.value == "US" ?KnownShareServers.US.rawValue : KnownShareServers.NON_US.rawValue
      dexShare = ShareClient(username: shareUserName, password: sharePassword, shareServer: shareServer )
      
      dexShare?.fetchData(1) { (err,result) in
         var valid = false
         if(err == nil ) {
            if result != nil {
               valid = true
            }
         }
         if( !valid ) {
            // error to the main thread
            DispatchQueue.main.async {
               // depending on how share implements timeout, internet conenction could still be at fault
               let alert = UIAlertController(title:"Authentication Failure", message: "Failed to authenticate to Dexcom. Please double check user name and password as well as internet connection.", preferredStyle: .alert)
               alert.addAction(UIAlertAction(title:"Close", style: .default, handler: nil))
               self.present(alert, animated: true)
            }
         }
         NotificationCenter.default.post(name:.didCompleteDexcomAuthentication, object:valid)
      }
   }
   @objc func needNightscoutAuthentication(_ notification: Notification) {
   
   }
}
