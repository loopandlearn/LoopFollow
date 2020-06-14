//
//  FirstViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/1/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import Charts
import EventKit


class MainViewController: UIViewController, UITableViewDataSource, ChartViewDelegate {
    
    @IBOutlet weak var BGText: UILabel!
    @IBOutlet weak var DeltaText: UILabel!
    @IBOutlet weak var DirectionText: UILabel!
    @IBOutlet weak var BGChart: LineChartView!
    @IBOutlet weak var BGChartFull: LineChartView!
    @IBOutlet weak var MinAgoText: UILabel!
    @IBOutlet weak var infoTable: UITableView!
    @IBOutlet weak var Console: UITableViewCell!
    @IBOutlet weak var DragBar: UIImageView!
    @IBOutlet weak var PredictionLabel: UILabel!
    @IBOutlet weak var LoopStatusLabel: UILabel!
    
    //NS BG Struct
    struct sgvData: Codable {
        var sgv: Int
        var date: TimeInterval
        var direction: String?
    }
    
    //NS Cage Struct
    struct cageData: Codable {
        var created_at: String
    }
    
    //NS Basal Profile Struct
    struct basalProfileStruct: Codable {
        var value: Double
        var time: String
        var timeAsSeconds: Double
    }
    
    //NS Basal Data  Struct
    struct basalDataStruct: Codable {
        var value: Double
        var date: TimeInterval
    }
    
    // Data Table Struct
    struct infoData {
        var name: String
        var value: String
    }

    // Variables for BG Charts
    public var numPoints: Int = 13
    public var linePlotData: [Double] = []
    public var linePlotDataTime: [Double] = []
    var firstStart: Bool = true
    
    // Vars for NS Pull
    var graphHours:Int=24
    var mmol = false as Bool
    var urlUser = UserDefaultsRepository.url.value as String
    var token = "" as String
    var defaults : UserDefaults?
    let consoleLogging = true
    var timeofLastBGUpdate = 0 as TimeInterval
    
    var backgroundTask = BackgroundTask()
    
    // Refresh NS Data
    var timer = Timer()
    // check every 30 Seconds whether new bgvalues should be retrieved
    let timeInterval: TimeInterval = 30.0
    
    // Check Alarms Timer
    // Don't check within 1 minute of alarm triggering to give the snoozer time to save data
    var checkAlarmTimer = Timer()
    var checkAlarmInterval: TimeInterval = 60.0
    
    // Info Table Setup
    var tableData = [
        infoData(name: "IOB", value: ""), //0
        infoData(name: "COB", value: ""), //1
        infoData(name: "Basal", value: ""), //2
        infoData(name: "Override", value: ""), //3
        infoData(name: "Battery", value: ""), //4
        infoData(name: "Pump", value: ""), //5
        infoData(name: "SAGE", value: ""), //6
        infoData(name: "CAGE", value: "") //7
    ]
    
    var bgData: [sgvData] = []
    var basalProfile: [basalProfileStruct] = []
    var basalData: [basalDataStruct] = []
    var predictionData: [Double] = []
    
    // calendar setup
    let store = EKEventStore()
    
    var snoozeTabItem: UITabBarItem = UITabBarItem()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
            self.tabBarController?.overrideUserInterfaceStyle = .dark
        }
        // Disable the snoozer tab unless an alarm is active
        let tabBarControllerItems = self.tabBarController?.tabBar.items
        if let arrayOfTabBarItems = tabBarControllerItems as AnyObject as? NSArray{
            snoozeTabItem = arrayOfTabBarItems[2] as! UITabBarItem
        }
        snoozeTabItem.isEnabled = false;
        
        
        // Trigger foreground and background functions
        let notificationCenter = NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        //Bind info data
        infoTable.rowHeight = 25
        infoTable.dataSource = self
        
        // Load Data
        appCameToForeground()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // set screen lock
        UIApplication.shared.isIdleTimerDisabled = UserDefaultsRepository.screenlockSwitchState.value;
        
        // Pull fresh data when view appears
        // moved this to didload, timer end, and foreground
        //nightscoutLoader()
    }
    
    
    // Info Table Functions
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
        let values = tableData[indexPath.row]
        cell.textLabel?.text = values.name
        cell.detailTextLabel?.text = values.value
        return cell
    }
    
    // NS Loader Timer
    fileprivate func startTimer(time: TimeInterval) {
        timer = Timer.scheduledTimer(timeInterval: time,
                                     target: self,
                                     selector: #selector(MainViewController.timerDidEnd(_:)),
                                     userInfo: nil,
                                     repeats: true)
    }
    
    // Check Alarm Timer
    func startCheckAlarmTimer(time: TimeInterval) {
        checkAlarmTimer = Timer.scheduledTimer(timeInterval: time,
                                     target: self,
                                     selector: #selector(MainViewController.checkAlarmTimerDidEnd(_:)),
                                     userInfo: nil,
                                     repeats: false)
    }
    
    // Nothing should be done when this timer ends because it just blocks the alarms from firing when it's active
    @objc func checkAlarmTimerDidEnd(_ timer:Timer) {
        print("check alarm timer ended")
    }
    
    @objc func appMovedToBackground() {
        // Allow screen to turn off
        UIApplication.shared.isIdleTimerDisabled = false;
        
        // We want to always come back to the home screen
        tabBarController?.selectedIndex = 0
        
        // Cancel the current timer and start a fresh background timer using the settings value only if background task is enabled
        timer.invalidate()
        if UserDefaultsRepository.backgroundRefresh.value {
            timer.invalidate()
            backgroundTask.startBackgroundTask()
            let refresh = UserDefaultsRepository.backgroundRefreshFrequency.value * 60
            startTimer(time: TimeInterval(refresh))
        }
    }

    @objc func appCameToForeground() {
        // reset screenlock state if needed
        UIApplication.shared.isIdleTimerDisabled = UserDefaultsRepository.screenlockSwitchState.value;
        
        // Cancel the background tasks, start a fresh timer, and immediately check for new data
        if UserDefaultsRepository.backgroundRefresh.value {
            backgroundTask.stopBackgroundTask()
            timer.invalidate()
        }
        startTimer(time: timeInterval)
        nightscoutLoader()

    }
    
    // Check for new data when timer ends
    @objc func timerDidEnd(_ timer:Timer) {
        print("timer ended")
        nightscoutLoader()
    }
    
    // Main loader for all data
    func nightscoutLoader(forceLoad: Bool = false) {
        
        var needsLoaded: Bool = false
        var onlyPullLastRecord = false
        
        // If we have existing data and it's within 5 minutes, we aren't going to do a network call
        if bgData.count > 0 {
            let now = NSDate().timeIntervalSince1970
            let lastReadingTime = bgData[bgData.count - 1].date
            let secondsAgo = now - lastReadingTime
            if secondsAgo >= 5*60 {
                needsLoaded = true
                if secondsAgo < 10*60 {
                    onlyPullLastRecord = true
                }
            }
        } else {
            needsLoaded = true
        }
        
        if forceLoad { needsLoaded = true}
        // Only do the network calls if we don't have a current reading
        if needsLoaded {
            loadDeviceStatus(urlUser: urlUser)
            loadBGData(urlUser: urlUser, onlyPullLastRecord: onlyPullLastRecord)
            clearLastInfoData()
            loadCage(urlUser: urlUser)
            loadSage(urlUser: urlUser)
            loadProfile(urlUser: urlUser)
           // loadBoluses(urlUser: urlUser)
           // loadTempBasals(urlUser: urlUser)
        } else {
            loadDeviceStatus(urlUser: urlUser)
            updateMinAgo()
            clearOldSnoozes()
            checkAlarms(bgs: bgData)
            loadProfile(urlUser: urlUser)
        }
        
    }
    
    // Main NS BG Data Pull
    func loadBGData(urlUser: String, onlyPullLastRecord: Bool = false) {

        // Set the count= in the url either to pull 24 hours or only the last record
        var points = "1"
        if !onlyPullLastRecord {
            points = String(self.graphHours * 12 + 1)
        }

        // URL processor
        var urlBGDataPath: String = urlUser + "/api/v1/entries/sgv.json?"
        if token == "" {
            urlBGDataPath = urlBGDataPath + "count=" + points
        } else {
            urlBGDataPath = urlBGDataPath + "token=" + token + "&count=" + points
        }
        guard let urlBGData = URL(string: urlBGDataPath) else { return }
        var request = URLRequest(url: urlBGData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData

        // Downloader
        let getBGTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if self.consoleLogging == true {print("start bg url")}
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }

            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([sgvData].self, from: data)
            if let entriesResponse = entriesResponse {
                DispatchQueue.main.async {
                    // trigger the processor for the data after downloading.
                    self.ProcessNSBGData(data: entriesResponse, onlyPullLastRecord: onlyPullLastRecord)
                }
            } else {
                return
            }
        }
        getBGTask.resume()
    }
       
    // Primary processor for what to do with the downloaded NS BG data
    func ProcessNSBGData(data: [sgvData], onlyPullLastRecord: Bool){
        var pullDate = data[data.count - 1].date / 1000
        pullDate.round(FloatingPointRoundingRule.toNearestOrEven)
        
        // If we already have data, we're going to pop it to the end and remove the first. If we have old or no data, we'll destroy the whole array and start over. This is simpler than determining how far back we need to get new data from in case Dex back-filled readings
        if !onlyPullLastRecord {
            bgData.removeAll()
        } else if bgData[bgData.count - 1].date != pullDate {
            bgData.removeFirst()
        } else {
            // Update the badge, bg, graph settings even if we don't have a new reading.
            self.updateBadge(entries: bgData)
            self.updateBG(entries: bgData)
            self.createGraph(entries: bgData)
            return
        }
        
        // loop through the data so we can reverse the order to oldest first for the graph and convert the NS timestamp to seconds instead of milliseconds. Makes date comparisons easier for everything else.
        for i in 0..<data.count{
            var dateString = data[data.count - 1 - i].date / 1000
            dateString.round(FloatingPointRoundingRule.toNearestOrEven)
            let reading = sgvData(sgv: data[data.count - 1 - i].sgv, date: dateString, direction: data[data.count - 1 - i].direction)
            bgData.append(reading)
        }
        self.updateBadge(entries: bgData)
        self.updateBG(entries: bgData)
        self.createGraph(entries: bgData)
        if UserDefaultsRepository.writeCalendarEvent.value {
            self.writeCalendar()
        }
       }
    
    //update Min Ago Text. We need to call this separately because it updates between readings
    func updateMinAgo(){
        let deltaTime = (TimeInterval(Date().timeIntervalSince1970)-bgData[bgData.count - 1].date) / 60
        MinAgoText.text = String(Int(deltaTime)) + " min ago"
    }
    
    //Clear the info data before next pull. This ensures we aren't displaying old data if something fails.
    func clearLastInfoData(){
        for i in 0..<tableData.count{
            tableData[i].value = ""
        }
    }
    
    // NS Device Status Pull from NS
    func loadDeviceStatus(urlUser: String) {
        var urlStringDeviceStatus = urlUser + "/api/v1/devicestatus.json?count=1"
        if token != "" {
            urlStringDeviceStatus = urlUser + "/api/v1/devicestatus.json?token=" + token + "&count=1"
        }
        let escapedAddress = urlStringDeviceStatus.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        guard let urlDeviceStatus = URL(string: escapedAddress!) else {
            return
        }
        if consoleLogging == true {print("entered device status task.")}
        var requestDeviceStatus = URLRequest(url: urlDeviceStatus)
        requestDeviceStatus.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let deviceStatusTask = URLSession.shared.dataTask(with: requestDeviceStatus) { data, response, error in
        if self.consoleLogging == true {print("in device status loop.")}
        guard error == nil else {
            return
        }
        guard let data = data else {
            return
        }
            
            let json = try? (JSONSerialization.jsonObject(with: data) as! [[String:AnyObject]])
        if let json = json {
            DispatchQueue.main.async {
                self.updateDeviceStatusDisplay(jsonDeviceStatus: json)
            }
        } else {
            return
        }
        if self.consoleLogging == true {print("finish pump update")}}
        deviceStatusTask.resume()
    }
    
    // Parse Device Status Data
    func updateDeviceStatusDisplay(jsonDeviceStatus: [[String:AnyObject]]) {
        if consoleLogging == true {print("in updatePump")}
        if jsonDeviceStatus.count == 0 {
            return
        }
        
        //only grabbing one record since ns sorts by {created_at : -1}
        let lastDeviceStatus = jsonDeviceStatus[0] as [String : AnyObject]?
        
        //pump and uploader
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                   .withTime,
                                   .withDashSeparatorInDate,
                                   .withColonSeparatorInTime]
        if let lastPumpRecord = lastDeviceStatus?["pump"] as! [String : AnyObject]? {
            if let lastPumpTime = formatter.date(from: (lastPumpRecord["clock"] as! String))?.timeIntervalSince1970  {
                if let reservoirData = lastPumpRecord["reservoir"] as? Double
                {
                    tableData[5].value = String(format:"%.0f", reservoirData) + "U"
                } else {
                    tableData[5].value = "50+U"
                }
                
                if let uploader = lastDeviceStatus?["uploader"] as? [String:AnyObject] {
                    let upbat = uploader["battery"] as! Double
                    tableData[4].value = String(format:"%.0f", upbat) + "%"
                }
            }
        }
            
        // Loop
        if let lastLoopRecord = lastDeviceStatus?["loop"] as! [String : AnyObject]? {
            if let lastLoopTime = formatter.date(from: (lastLoopRecord["timestamp"] as! String))?.timeIntervalSince1970  {

                UserDefaultsRepository.alertLastLoopTime.value = lastLoopTime
                
                if let failure = lastLoopRecord["failureReason"] {
                    LoopStatusLabel.text = "⚠"
                }
                else
                {
                    if let enacted = lastLoopRecord["enacted"] as? [String:AnyObject] {
                        if let lastTempBasal = enacted["rate"] as? Double {
                            tableData[2].value = String(format:"%.1f", lastTempBasal)
                        }
                    }
                    if let iobdata = lastLoopRecord["iob"] as? [String:AnyObject] {
                        tableData[0].value = String(format:"%.1f", (iobdata["iob"] as! Double))
                    }
                    if let cobdata = lastLoopRecord["cob"] as? [String:AnyObject] {
                        tableData[1].value = String(format:"%.0f", cobdata["cob"] as! Double)
                    }
                    if let predictdata = lastLoopRecord["predicted"] as? [String:AnyObject] {
                        let prediction = predictdata["values"] as! [Double]
                        PredictionLabel.text = String(Int(prediction.last!))
                        PredictionLabel.textColor = UIColor.systemPurple
                        predictionData.removeAll()
                        var i = 1
                        while i <= 12 {
                            predictionData.append(prediction[i])
                            i += 1
                        }
                        
                    }
                    
                    
                    
                    if let loopStatus = lastLoopRecord["recommendedTempBasal"] as? [String:AnyObject] {
                        if let tempBasalTime = formatter.date(from: (loopStatus["timestamp"] as! String))?.timeIntervalSince1970 {
                            if tempBasalTime > lastLoopTime {
                                LoopStatusLabel.text = "⏀"
                               } else {
                                LoopStatusLabel.text = "↻"
                            }
                        }
                       
                    } else {
                        LoopStatusLabel.text = "↻"
                    }
                    
                }
                if ((TimeInterval(Date().timeIntervalSince1970) - lastLoopTime) / 60) > 10 {
                    LoopStatusLabel.text = "⚠"
                }
            }
            
            
            
        }
        
        var oText = "" as String
               
               if let lastOverride = lastDeviceStatus?["override"] as! [String : AnyObject]? {
                   if let lastOverrideTime = formatter.date(from: (lastOverride["timestamp"] as! String))?.timeIntervalSince1970  {
                   }
                   if lastOverride["active"] as! Bool {
                       
                       let lastCorrection  = lastOverride["currentCorrectionRange"] as! [String: AnyObject]
                       if let multiplier = lastOverride["multiplier"] as? Double {
                                              oText += String(format:"%.1f", multiplier*100)
                                          }
                                          else
                                          {
                                              oText += String(format:"%.1f", 100)
                                          }
                       oText += "% ("
                       let minValue = lastCorrection["minValue"] as! Double
                       let maxValue = lastCorrection["maxValue"] as! Double
                       oText += bgOutputFormat(bg: minValue, mmol: mmol) + "-" + bgOutputFormat(bg: maxValue, mmol: mmol) + ")"
                      
                    tableData[3].value =  oText
                   }
               }
        
        infoTable.reloadData()
        }
    
    // Get last CAGE entry
    func loadCage(urlUser: String) {
        var urlString = urlUser + "/api/v1/treatments.json?find[eventType]=Site%20Change&count=1"
        if token != "" {
            urlString = urlUser + "/api/v1/treatments.json?token=" + token + "&find[eventType]=Site%20Change&count=1"
        }

        guard let urlData = URL(string: urlString) else {
            return
        }
        var request = URLRequest(url: urlData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if self.consoleLogging == true {print("start cage url")}
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }

            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([cageData].self, from: data)
            if let entriesResponse = entriesResponse {
                DispatchQueue.main.async {
                    self.updateCage(data: entriesResponse)
                }
            } else {
                return
            }
        }
        task.resume()
    }
     
    // Parse Cage Data
    func updateCage(data: [cageData]) {
        if consoleLogging == true {print("in updateCage")}
        if data.count == 0 {
            return
        }

        let lastCageString = data[0].created_at

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                                .withTime,
                                .withDashSeparatorInDate,
                                .withColonSeparatorInTime]
        UserDefaultsRepository.alertCageInsertTime.value = formatter.date(from: (lastCageString))?.timeIntervalSince1970 as! TimeInterval
        if let cageTime = formatter.date(from: (lastCageString))?.timeIntervalSince1970 {
            let now = NSDate().timeIntervalSince1970
            let secondsAgo = now - cageTime
            //let days = 24 * 60 * 60

            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
            formatter.allowedUnits = [ .hour, .minute ] // Units to display in the formatted string
            formatter.zeroFormattingBehavior = [ .pad ] // Pad with zeroes where appropriate for the locale

            let formattedDuration = formatter.string(from: secondsAgo)
            tableData[7].value = formattedDuration ?? ""
        }
        infoTable.reloadData()
    }
     
    // Get last SAGE entry
    func loadSage(urlUser: String) {
        var dayComponent    = DateComponents()
        dayComponent.day    = -10 // For removing 10 days
        let theCalendar     = Calendar.current

        let startDate    = theCalendar.date(byAdding: dayComponent, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        var startDateString = dateFormatter.string(from: startDate)


        var urlString = urlUser + "/api/v1/treatments.json?find[eventType]=Sensor%20Start&find[created_at][$gte]=2020-05-31&count=1"
        if token != "" {
            urlString = urlUser + "/api/v1/treatments.json?token=" + token + "&find[eventType]=Sensor%20Start&find[created_at][$gte]=2020-05-31&count=1"
        }

        guard let urlData = URL(string: urlString) else {
            return
        }
        var request = URLRequest(url: urlData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if self.consoleLogging == true {print("start cage url")}
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }

            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([cageData].self, from: data)
            if let entriesResponse = entriesResponse {
                DispatchQueue.main.async {
                    self.updateSage(data: entriesResponse)
                }
            } else {
                return
            }
        }
        task.resume()
    }
     
    // Parse Sage Data
    func updateSage(data: [cageData]) {
        if consoleLogging == true {print("in updateSage")}
        if data.count == 0 {
            return
        }

        var lastSageString = data[0].created_at

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate,
                             .withTime,
                             .withDashSeparatorInDate,
                             .withColonSeparatorInTime]
        UserDefaultsRepository.alertSageInsertTime.value = formatter.date(from: (lastSageString))?.timeIntervalSince1970 as! TimeInterval
        if let sageTime = formatter.date(from: (lastSageString as! String))?.timeIntervalSince1970 {
            let now = NSDate().timeIntervalSince1970
            let secondsAgo = now - sageTime
            let days = 24 * 60 * 60

            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .positional // Use the appropriate positioning for the current locale
            formatter.allowedUnits = [ .day, .hour] // Units to display in the formatted string
            formatter.zeroFormattingBehavior = [ .pad ] // Pad with zeroes where appropriate for the locale

            let formattedDuration = formatter.string(from: secondsAgo)
            tableData[6].value = formattedDuration ?? ""
        }
        infoTable.reloadData()
    }
     
    // Load Current Profile
    func loadProfile(urlUser: String) {
        let urlString = urlUser + "/api/v1/profile/current.json"
        let escapedAddress = urlString.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        guard let url = URL(string: escapedAddress!) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            
            let json = try? JSONSerialization.jsonObject(with: data) as! Dictionary<String, Any>
            
            if let json = json {
                DispatchQueue.main.async {
                    self.updateProfile(jsonDeviceStatus: json)
                }
            } else {
                return
            }
        }
        task.resume()
    }
    
    // Parse Basal schedule from the profile
    func updateProfile(jsonDeviceStatus: Dictionary<String, Any>) {
   
        if jsonDeviceStatus.count == 0 {
            return
        }
        let basal = jsonDeviceStatus[keyPath: "store.Default.basal"] as! NSArray
        for i in 0..<basal.count {
            let dict = basal[i] as! Dictionary<String, Any>
            let thisValue = dict[keyPath: "value"] as! Double
            let thisTime = dict[keyPath: "time"] as! String
            let thisTimeAsSeconds = dict[keyPath: "timeAsSeconds"] as! Double
            let entry = basalProfileStruct(value: thisValue, time: thisTime, timeAsSeconds: thisTimeAsSeconds)
            basalProfile.append(entry)
        }
        
    }
    
    func createBasalIncrements() {
        // remove old entries
        
        // Get the starting time for first BG entry
        
        // cycle through temp basals
        
        // if a temp basal doesn't exist, check for the scheduled basal based on time
    }
    
    // Need to figure out the date to pull only last 24 hours
    // NOT IMPLEMENTED YET
    func loadTempBasals(urlUser: String) {
        var dayComponent    = DateComponents()
        dayComponent.day    = -1 // For removing one day (yesterday): -1
        let theCalendar     = Calendar.current
    
        let yesterday       = theCalendar.date(byAdding: dayComponent, to: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-mm-ddTHH:mm:ss"
        //dateFormatter.timeZone = NSTimeZone(name: "UTC")
        //let date: NSDate? = dateFormatter.dateFromString("2016-02-29 12:24:26")
        //print(date)
        
        var urlStringBasal = urlUser + "/api/v1/treatments.json?find[eventType][$eq]=Temp%20Basal&find[created_at][$gte]=2020-06-02T22:46:26"
        if token != "" {
            urlStringBasal = urlUser + "/api/v1/treatments.json?token=" + token + "&find[eventType][$eq]=Temp%20Basal&find[created_at][$gte]=2020-06-02T22:46:26"
        }
        
        let escapedAddress = urlStringBasal.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        guard let urlBasal = URL(string: escapedAddress!) else {
            return
        }
        
        if consoleLogging == true {print("entered 2nd task.")}
        var requestBasal = URLRequest(url: urlBasal)
        requestBasal.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let basalTask = URLSession.shared.dataTask(with: requestBasal) { data, response, error in
            if self.consoleLogging == true {print("in update loop.")}
            guard error == nil else {
                return
            }
            guard let data = data else {
                
                return
            }
            
            let json = try? JSONSerialization.jsonObject(with: data) as! [[String:AnyObject]]
            
            if let json = json {
                DispatchQueue.main.async {
                    self.updateDeviceStatusDisplay(jsonDeviceStatus: json)
                }
            }
            else
            {
               
                return
            }
            if self.consoleLogging == true {print("finish pump update")}
        }
        basalTask.resume()
    }
  
    // NOT IMPLEMENTED YET
    func loadBoluses(urlUser: String){
        var calendar = Calendar.current
        let today = Date()
        let midnight = calendar.startOfDay(for: today)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let formattedDate = dateFormatter.string(from: yesterday)
        
        var searchString = "find[eventType]=Meal%20Bolus&find[created_at][$gte]=" + formattedDate
        var urlBGDataPath: String = urlUser + "/api/v1/treatments.json?"
        if token == "" {
            urlBGDataPath = urlBGDataPath + searchString
        }
        else
        {
            urlBGDataPath = urlBGDataPath + "token=" + token + searchString
        }
        guard let urlBGData = URL(string: urlBGDataPath) else {
            return
        }
        var request = URLRequest(url: urlBGData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
        let getTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if self.consoleLogging == true {print("start meal bolus url")}
            guard error == nil else {
                return
            }
            guard let data = data else {
                return
            }
            
            let decoder = JSONDecoder()
            let entriesResponse = try? decoder.decode([sgvData].self, from: data)
            if let entriesResponse = entriesResponse {
                DispatchQueue.main.async {
                   // self.ProcessNSData(data: entriesResponse, onlyPullLastRecord: onlyPullLastRecord)
                }
            }
            else
            {
                
                return
            }
        }
        getTask.resume()
    }

    func stringFromTimeInterval(interval: TimeInterval) -> String {
        let interval = Int(interval)
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d", hours, minutes)
    }

    func createGraph(entries: [sgvData]){
        var bgChartEntry = [ChartDataEntry]()
        var colors = [NSUIColor]()
        var maxBG: Int = 250
        for i in 0..<entries.count{
            var dateString = String(entries[i].date).prefix(10)
            let dateSecondsOnly = Double(String(dateString))!
            if entries[i].sgv > maxBG {
                maxBG = entries[i].sgv
            }
            let value = ChartDataEntry(x: Double(entries[i].date), y: Double(entries[i].sgv))
            bgChartEntry.append(value)
            
            if Double(entries[i].sgv) >= Double(UserDefaultsRepository.highLine.value) {
                colors.append(NSUIColor.systemYellow)
            } else if Double(entries[i].sgv) <= Double(UserDefaultsRepository.lowLine.value) {
                colors.append(NSUIColor.systemRed)
            } else {
                colors.append(NSUIColor.systemGreen)
            }
        }
        
        // Add Prediction Data
        if predictionData.count > 0 {
            var startingTime = bgChartEntry[bgChartEntry.count - 1].x + 300
            var i = 0
            // Add 1 hour of predictions
            while i < 12 {
                var predictionVal = Double(predictionData[i])
                // Below can be turned on to prevent out of range on the graph if desired.
                // It currently just drops them out of view
                if predictionVal > 400 {
               //     predictionVal = 400
                } else if predictionVal < 0 {
                //    predictionVal = 0
                }
                let value = ChartDataEntry(x: startingTime + 5, y: predictionVal)
                bgChartEntry.append(value)
                colors.append(NSUIColor.systemPurple)
                startingTime += 300
                i += 1
            }
        }
        
        let line1 = LineChartDataSet(entries:bgChartEntry, label: "")
        line1.circleRadius = 3
        line1.circleColors = [NSUIColor.systemGreen]
        line1.drawCircleHoleEnabled = false
        if UserDefaultsRepository.showLines.value {
            line1.lineWidth = 2
        } else {
            line1.lineWidth = 0
        }
        if UserDefaultsRepository.showDots.value {
            line1.drawCirclesEnabled = true
        } else {
            line1.drawCirclesEnabled = false
        }
        line1.setDrawHighlightIndicators(false)
        line1.valueFont.withSize(50)
        
        for i in 1..<colors.count{
            line1.addColor(colors[i])
            line1.circleColors.append(colors[i])
        }
        
        let data = LineChartData()
        data.addDataSet(line1)
        data.setValueFont(UIFont(name: UIFont.systemFont(ofSize: 10).fontName, size: 10)!)
        data.setDrawValues(false)
        
        //Add lower red line based on low alert value
        let ll = ChartLimitLine()
        ll.limit = Double(UserDefaultsRepository.lowLine.value)
        ll.lineColor = NSUIColor.systemRed
        BGChart.rightAxis.addLimitLine(ll)
        
        //Add upper yellow line based on low alert value
        let ul = ChartLimitLine()
        ul.limit = Double(UserDefaultsRepository.highLine.value)
        ul.lineColor = NSUIColor.systemYellow
        BGChart.rightAxis.addLimitLine(ul)
        
        BGChart.xAxis.valueFormatter = ChartXValueFormatter()
        BGChart.xAxis.granularity = 1800
        BGChart.xAxis.labelTextColor = NSUIColor.label
        BGChart.xAxis.labelPosition = XAxis.LabelPosition.bottom
        BGChart.rightAxis.labelTextColor = NSUIColor.label
        BGChart.rightAxis.labelPosition = YAxis.LabelPosition.insideChart
        BGChart.rightAxis.axisMinimum = 40
        BGChart.leftAxis.axisMinimum = 40
        BGChart.rightAxis.axisMaximum = Double(maxBG)
        BGChart.leftAxis.axisMaximum = Double(maxBG)
        BGChart.leftAxis.enabled = false
        BGChart.legend.enabled = false
        BGChart.scaleYEnabled = false
        BGChart.data = data
        BGChart.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 10)
        BGChart.setVisibleXRangeMinimum(10)
        BGChart.drawGridBackgroundEnabled = true
        BGChart.gridBackgroundColor = NSUIColor.secondarySystemBackground
        if firstStart {
            BGChart.zoom(scaleX: 18, scaleY: 1, x: 1, y: 1)
            firstStart = false
        }
        // 7000 only shows 30 minutes of the hour predictions, leaving the rest on the right of the screen requiring a scroll
        BGChart.moveViewToX(BGChart.chartXMax - 7000)
        
        //24 Hour Small Graph
        let line2 = LineChartDataSet(entries:bgChartEntry, label: "Number")
        line2.drawCirclesEnabled = false
        line2.setDrawHighlightIndicators(false)
        line2.lineWidth = 1
        for i in 1..<colors.count{
            line2.addColor(colors[i])
            line2.circleColors.append(colors[i])
        }
        
        let data2 = LineChartData()
        data2.addDataSet(line2)
        BGChartFull.leftAxis.enabled = false
        BGChartFull.rightAxis.enabled = false
        BGChartFull.xAxis.enabled = false
        BGChartFull.legend.enabled = false
        BGChartFull.scaleYEnabled = false
        BGChartFull.scaleXEnabled = false
        BGChartFull.drawGridBackgroundEnabled = false
        BGChartFull.data = data2
      
    }
    
    func updateBadge(entries: [sgvData]) {
        if entries.count > 0 && UserDefaultsRepository.appBadge.value {
            let latestBG = entries[entries.count - 1].sgv
            UIApplication.shared.applicationIconBadgeNumber = latestBG
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        print("updated badge")
    }
    
    func updateBG (entries: [sgvData]) {
        if consoleLogging == true {print("in update BG")}
        if entries.count > 0 {
            let latestEntryi = entries.count - 1
            let latestBG = entries[latestEntryi].sgv
            let priorBG = entries[latestEntryi - 1].sgv
            let deltaBG = latestBG - priorBG as Int
            let lastBGTime = entries[latestEntryi].date //NS has different units
            let deltaTime = (TimeInterval(Date().timeIntervalSince1970)-lastBGTime) / 60
            var userUnit = " mg/dL"
            if mmol {
                userUnit = " mmol/L"
            }
            if UserDefaultsRepository.appBadge.value {
                UIApplication.shared.applicationIconBadgeNumber = latestBG
            } else {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
            
            BGText.text = bgOutputFormat(bg: Double(latestBG), mmol: mmol)
            setBGTextColor()

            MinAgoText.text = String(Int(deltaTime)) + " min ago"
            print(String(Int(deltaTime)) + " min ago")
            if let directionBG = entries[latestEntryi].direction {
                DirectionText.text = bgDirectionGraphic(directionBG)
            }
            else
            {
                DirectionText.text = ""
            }
            
          if deltaBG < 0 {
            self.DeltaText.text = String(deltaBG)
            }
            else
            {
                self.DeltaText.text = "+" + String(deltaBG)
            }
        
        }
        else
        {
            
            return
        }
        
        checkAlarms(bgs: entries)
    }

    func setBGTextColor() {
        let latestBG = bgData[bgData.count - 1].sgv
        if UserDefaultsRepository.colorBGText.value {
            if latestBG >= UserDefaultsRepository.highLine.value {
                BGText.textColor = NSUIColor.systemYellow
            } else if latestBG <= UserDefaultsRepository.lowLine.value {
                BGText.textColor = NSUIColor.systemRed
            } else {
                BGText.textColor = NSUIColor.systemGreen
            }
        } else {
            BGText.textColor = NSUIColor.label
        }
        
    }
    
    func bgOutputFormat(bg: Double, mmol: Bool) -> String {
        if !mmol {
            return String(format:"%.0f", bg)
        }
        else
        {
            return String(format:"%.1f", bg / 18.0)
        }
    }
    
    func bgDirectionGraphic(_ value:String)->String
    {
        let //graphics:[String:String]=["Flat":"\u{2192}","DoubleUp":"\u{21C8}","SingleUp":"\u{2191}","FortyFiveUp":"\u{2197}\u{FE0E}","FortyFiveDown":"\u{2198}\u{FE0E}","SingleDown":"\u{2193}","DoubleDown":"\u{21CA}","None":"-","NOT COMPUTABLE":"-","RATE OUT OF RANGE":"-"]
        graphics:[String:String]=["Flat":"→","DoubleUp":"↑↑","SingleUp":"↑","FortyFiveUp":"↗","FortyFiveDown":"↘︎","SingleDown":"↓","DoubleDown":"↓↓","None":"-","NOT COMPUTABLE":"-","RATE OUT OF RANGE":"-"]
        
        
        return graphics[value]!
    }
    
    // Write calendar
    func writeCalendar() {
        store.requestAccess(to: .event) {(granted, error) in
        if !granted { return }
            
        // Create Event info
           // eventTitle = BGText.text + " " + DirectionText.text + " " + DeltaText.text + "\nC:" + tableData[1].value + "g I:" + tableData[0].value + "u"
            let deltaBG = self.bgData[self.bgData.count - 1].sgv -  self.bgData[self.bgData.count - 2].sgv as Int
            let deltaTime = (TimeInterval(Date().timeIntervalSince1970) - self.bgData[self.bgData.count - 1].date) / 60
            var deltaString = ""
            if deltaBG < 0 {
                deltaString = String(deltaBG)
            }
            else
            {
                deltaString = "+" + String(deltaBG)
            }
            let direction = self.bgDirectionGraphic(self.bgData[self.bgData.count - 1].direction ?? "")
            var eventStartDate = Date(timeIntervalSince1970: self.bgData[self.bgData.count - 1].date)
            var eventEndDate = eventStartDate.addingTimeInterval(60 * 10)
            var eventTitle = ""
            eventTitle += String(self.bgData[self.bgData.count - 1].sgv) + " "
            eventTitle += direction + " "
            eventTitle += deltaString + " "
            if deltaTime > 5 {
                // write old BG reading and continue pushing out end date to show last entry
                eventTitle += ": " + String(Int(deltaTime)) + " min"
                eventEndDate = eventStartDate.addingTimeInterval((60 * 10) + (deltaTime * 60))
            }
            
            eventTitle += "\n"
            if self.tableData[1].value != "" {
               eventTitle += "C:" + self.tableData[1].value + "g "
            }
            if self.tableData[0].value != "" {
                eventTitle += "I: " + self.tableData[0].value + "u"
            }
            
            
            
            
        // Delete Last Event
            let eventToRemove = self.store.event(withIdentifier: UserDefaultsRepository.savedEventID.value)
            if eventToRemove != nil {
                do {
                    try self.store.remove(eventToRemove!, span: .thisEvent, commit: true)
                } catch {
                    // Display error to user
                }
            }
        // Write New Event
            var event = EKEvent(eventStore: self.store)
            event.title = eventTitle
            event.startDate = eventStartDate
            event.endDate = eventEndDate
            event.calendar = self.store.calendar(withIdentifier: UserDefaultsRepository.calendarIdentifier.value)
            do {
                try self.store.save(event, span: .thisEvent, commit: true)
                UserDefaultsRepository.savedEventID.value = event.eventIdentifier //save event id to access this particular event later
            } catch {
                // Display error to user
            }
        }
    }
    
    func checkAlarms(bgs: [sgvData]) {
        
        // Don't check or fire alarms within 1 minute of prior alarm
        if checkAlarmTimer.isValid {  return }
        
        let date = Date()
        let now = date.timeIntervalSince1970
        let currentBG = bgs[bgs.count - 1].sgv
        let lastBG = bgs[bgs.count - 2].sgv
        guard let deltas: [Int] = [
            bgs[bgs.count - 1].sgv - bgs[bgs.count - 2].sgv,
            bgs[bgs.count - 2].sgv - bgs[bgs.count - 3].sgv,
            bgs[bgs.count - 3].sgv - bgs[bgs.count - 4].sgv
            ] else {}
        let currentBGTime = bgs[bgs.count - 1].date
        var alarmTriggered = false
        
        clearOldSnoozes()
        
        // Exit if all is snoozed
        if UserDefaultsRepository.alertSnoozeAllIsSnoozed.value {
            return
        }
        
        
        // BG Based Alarms
        // Check to make sure it is a current reading and has not already triggered alarm from this reading
        if now - currentBGTime <= (5*60) && currentBGTime > UserDefaultsRepository.snoozedBGReadingTime.value as! TimeInterval {
            
            // trigger temporary alert first
            if UserDefaultsRepository.alertTemporaryActive.value {
                if UserDefaultsRepository.alertTemporaryBelow.value {
                    if currentBG < UserDefaultsRepository.alertTemporaryBG.value {
                        UserDefaultsRepository.alertTemporaryActive.value = false
                        AlarmSound.whichAlarm = "Temporary Alert"
                        triggerAlarm(sound: UserDefaultsRepository.alertTemporarySound.value, snooozedBGReadingTime: currentBGTime)
                        return
                    }
                } else{
                    if currentBG > UserDefaultsRepository.alertTemporaryBG.value {
                      tabBarController?.selectedIndex = 2
                        AlarmSound.whichAlarm = "Temporary Alert"
                        triggerAlarm(sound: UserDefaultsRepository.alertTemporarySound.value, snooozedBGReadingTime: currentBGTime)
                        return
                   }
                }
            }
            
            // Check Urgent Low
            if UserDefaultsRepository.alertUrgentLowActive.value && !UserDefaultsRepository.alertUrgentLowIsSnoozed.value &&
            currentBG <= UserDefaultsRepository.alertUrgentLowBG.value {
                // Separating this makes it so the low or drop alerts won't trigger if they already snoozed the urgent low
                if !UserDefaultsRepository.alertUrgentLowIsSnoozed.value {
                    AlarmSound.whichAlarm = "Urgent Low Alert"
                    triggerAlarm(sound: UserDefaultsRepository.alertUrgentLowSound.value, snooozedBGReadingTime: currentBGTime)
                    return
                } else {
                    return
                }
            }
            
            // Check Low
            if UserDefaultsRepository.alertLowActive.value && !UserDefaultsRepository.alertUrgentLowIsSnoozed.value &&
            currentBG <= UserDefaultsRepository.alertLowBG.value && !UserDefaultsRepository.alertLowIsSnoozed.value {
                AlarmSound.whichAlarm = "Low Alert"
                triggerAlarm(sound: UserDefaultsRepository.alertLowSound.value, snooozedBGReadingTime: currentBGTime)
                return
            }
            
            // Check Urgent High
            if UserDefaultsRepository.alertUrgentHighActive.value && !UserDefaultsRepository.alertUrgentHighIsSnoozed.value &&
            currentBG >= UserDefaultsRepository.alertUrgentHighBG.value {
                // Separating this makes it so the high or rise alerts won't trigger if they already snoozed the urgent low
                if !UserDefaultsRepository.alertUrgentHighIsSnoozed.value {
                        AlarmSound.whichAlarm = "Urgent High Alert"
                        triggerAlarm(sound: UserDefaultsRepository.alertUrgentHighSound.value, snooozedBGReadingTime: currentBGTime)
                        return
                } else {
                    return
                }
                
            }
            
            // Check High
            if UserDefaultsRepository.alertHighActive.value && !UserDefaultsRepository.alertHighIsSnoozed.value &&
            currentBG >= UserDefaultsRepository.alertHighBG.value && !UserDefaultsRepository.alertHighIsSnoozed.value {
                AlarmSound.whichAlarm = "High Alert"
                triggerAlarm(sound: UserDefaultsRepository.alertHighSound.value, snooozedBGReadingTime: currentBGTime)
                return
            }
            
            
            
            // Check Fast Drop
            if UserDefaultsRepository.alertFastDropActive.value && !UserDefaultsRepository.alertFastDropIsSnoozed.value {
                // make sure limit is off or BG is below value
                if (!UserDefaultsRepository.alertFastDropUseLimit.value) || (UserDefaultsRepository.alertFastDropUseLimit.value && currentBG < UserDefaultsRepository.alertFastDropBelowBG.value) {
                    let compare = 0 - UserDefaultsRepository.alertFastDropDelta.value
                    
                    //check last 2/3/4 readings
                    if (UserDefaultsRepository.alertFastDropReadings.value == 2 && deltas[0] <= compare)
                    || (UserDefaultsRepository.alertFastDropReadings.value == 3 && deltas[0] <= compare && deltas[1] <= compare)
                    || (UserDefaultsRepository.alertFastDropReadings.value == 4 && deltas[0] <= compare && deltas[1] <= compare && deltas[2] <= compare) {
                        AlarmSound.whichAlarm = "Fast Drop Alert"
                        triggerAlarm(sound: UserDefaultsRepository.alertFastDropSound.value, snooozedBGReadingTime: currentBGTime)
                        return
                    }
                }
            }
            
            // Check Fast Rise
            if UserDefaultsRepository.alertFastRiseActive.value && !UserDefaultsRepository.alertFastRiseIsSnoozed.value {
                // make sure limit is off or BG is above value
                if (!UserDefaultsRepository.alertFastRiseUseLimit.value) || (UserDefaultsRepository.alertFastRiseUseLimit.value && currentBG > UserDefaultsRepository.alertFastRiseAboveBG.value) {
                    let compare = UserDefaultsRepository.alertFastDropDelta.value
                    
                    //check last 2/3/4 readings
                    if (UserDefaultsRepository.alertFastRiseReadings.value == 2 && deltas[0] >= compare)
                    || (UserDefaultsRepository.alertFastRiseReadings.value == 3 && deltas[0] >= compare && deltas[1] >= compare)
                    || (UserDefaultsRepository.alertFastRiseReadings.value == 4 && deltas[0] >= compare && deltas[1] >= compare && deltas[2] >= compare) {
                        AlarmSound.whichAlarm = "Fast Rise Alert"
                        triggerAlarm(sound: UserDefaultsRepository.alertFastRiseSound.value, snooozedBGReadingTime: currentBGTime)
                        return
                    }
                }
            }
            

            
        }
        
        // These only get checked and fire if a BG reading doesn't fire
        if UserDefaultsRepository.alertNotLoopingActive.value
            && !UserDefaultsRepository.alertNotLoopingIsSnoozed.value
            && (Double(now - UserDefaultsRepository.alertLastLoopTime.value) >= Double(UserDefaultsRepository.alertNotLooping.value * 60))
            && UserDefaultsRepository.alertLastLoopTime.value > 0 {
            
            var trigger = true
            if (UserDefaultsRepository.alertNotLoopingUseLimits.value
                && (
                    (currentBG <= UserDefaultsRepository.alertNotLoopingUpperLimit.value
                    && currentBG >= UserDefaultsRepository.alertNotLoopingLowerLimit.value) ||
                    // Ignore Limits if BG reading is older than non looping time
                    (Double(now - currentBGTime) >= Double(UserDefaultsRepository.alertNotLooping.value * 60))
                ) ||
                !UserDefaultsRepository.alertNotLoopingUseLimits.value) {
                    AlarmSound.whichAlarm = "Not Looping Alert"
                    triggerAlarm(sound: UserDefaultsRepository.alertNotLoopingSound.value, snooozedBGReadingTime: nil)
                    return
            }
        }
        
        //check for missed reading alert
        if UserDefaultsRepository.alertMissedReadingActive.value && !UserDefaultsRepository.alertMissedReadingIsSnoozed.value && (Double(now - currentBGTime) >= Double(UserDefaultsRepository.alertMissedReading.value * 60)) {
            AlarmSound.whichAlarm = "Missed Reading Alert"
                triggerAlarm(sound: UserDefaultsRepository.alertMissedReadingSound.value, snooozedBGReadingTime: nil)
                return
        }
        
        // Check Sage
        if UserDefaultsRepository.alertSAGEActive.value && !UserDefaultsRepository.alertSAGEIsSnoozed.value {
            let insertTime = Double(UserDefaultsRepository.alertSageInsertTime.value)
            let alertDistance = Double(UserDefaultsRepository.alertSAGE.value * 60 * 60)
            let delta = now - insertTime
            let tenDays = 10 * 24 * 60 * 60
            if Double(tenDays) - Double(delta) <= alertDistance {
                AlarmSound.whichAlarm = "Sensor Change Alert"
                triggerAlarm(sound: UserDefaultsRepository.alertSAGESound.value, snooozedBGReadingTime: nil)
                return
            }
        }
        
        // Check Cage
        if UserDefaultsRepository.alertCAGEActive.value && !UserDefaultsRepository.alertCAGEIsSnoozed.value {
            let insertTime = Double(UserDefaultsRepository.alertCageInsertTime.value)
            let alertDistance = Double(UserDefaultsRepository.alertCAGE.value * 60 * 60)
            let delta = now - insertTime
            let tenDays = 3 * 24 * 60 * 60
            if Double(tenDays) - Double(delta) <= alertDistance {
                AlarmSound.whichAlarm = "Pump Change Alert"
                triggerAlarm(sound: UserDefaultsRepository.alertCAGESound.value, snooozedBGReadingTime: nil)
                return
            }
        }
        
    }
    
    func triggerAlarm(sound: String, snooozedBGReadingTime: TimeInterval?)
    {
        guard let snoozer = self.tabBarController!.viewControllers?[2] as? SnoozeViewController else { return }
        snoozer.updateDisplayWhenTriggered(bgVal: BGText.text ?? "", directionVal: DirectionText.text ?? "", deltaVal: DeltaText.text ?? "", minAgoVal: MinAgoText.text ?? "", alertLabelVal: AlarmSound.whichAlarm)
        snoozeTabItem.isEnabled = true;
        tabBarController?.selectedIndex = 2
        if snooozedBGReadingTime != nil {
            UserDefaultsRepository.snoozedBGReadingTime.value = snooozedBGReadingTime
        }
        AlarmSound.setSoundFile(str: sound)
        AlarmSound.play()
    }
    
    func clearOldSnoozes(){
        let date = Date()
        let now = date.timeIntervalSince1970
        var needsReload: Bool = false
        guard let alarms = self.tabBarController!.viewControllers?[1] as? AlarmViewController else { return }
        
        if date > UserDefaultsRepository.alertSnoozeAllTime.value ?? date {
            UserDefaultsRepository.alertSnoozeAllTime.setNil(key: "alertSnoozeAllTime")
            UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertSnoozeAllTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertSnoozeAllIsSnoozed", value: false)
          
        }
        
        if date > UserDefaultsRepository.alertUrgentLowSnoozedTime.value ?? date {
            UserDefaultsRepository.alertUrgentLowSnoozedTime.setNil(key: "alertUrgentLowSnoozedTime")
            UserDefaultsRepository.alertUrgentLowIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertUrgentLowSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertUrgentLowIsSnoozed", value: false)
          
        }
        if date > UserDefaultsRepository.alertLowSnoozedTime.value ?? date {
            UserDefaultsRepository.alertLowSnoozedTime.setNil(key: "alertLowSnoozedTime")
            UserDefaultsRepository.alertLowIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertLowSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertLowIsSnoozed", value: false)
       
        }
        if date > UserDefaultsRepository.alertHighSnoozedTime.value ?? date {
            UserDefaultsRepository.alertHighSnoozedTime.setNil(key: "alertHighSnoozedTime")
            UserDefaultsRepository.alertHighIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertHighSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertHighIsSnoozed", value: false)
          
        }
        if date > UserDefaultsRepository.alertUrgentHighSnoozedTime.value ?? date {
            UserDefaultsRepository.alertUrgentHighSnoozedTime.setNil(key: "alertUrgentHighSnoozedTime")
            UserDefaultsRepository.alertUrgentHighIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertUrgentHighSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertUrgentHighIsSnoozed", value: false)
          
        }
        if date > UserDefaultsRepository.alertFastDropSnoozedTime.value ?? date {
            UserDefaultsRepository.alertFastDropSnoozedTime.setNil(key: "alertFastDropSnoozedTime")
            UserDefaultsRepository.alertFastDropIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertFastDropSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertFastDropIsSnoozed", value: false)
           
        }
        if date > UserDefaultsRepository.alertFastRiseSnoozedTime.value ?? date {
            UserDefaultsRepository.alertFastRiseSnoozedTime.setNil(key: "alertFastRiseSnoozedTime")
            UserDefaultsRepository.alertFastRiseIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertFastRiseSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertFastRiseIsSnoozed", value: false)
           
        }
        if date > UserDefaultsRepository.alertMissedReadingSnoozedTime.value ?? date {
            UserDefaultsRepository.alertMissedReadingSnoozedTime.setNil(key: "alertMissedReadingSnoozedTime")
            UserDefaultsRepository.alertMissedReadingIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertMissedReadingSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertMissedReadingIsSnoozed", value: false)
          
        }
        if date > UserDefaultsRepository.alertNotLoopingSnoozedTime.value ?? date {
            UserDefaultsRepository.alertNotLoopingSnoozedTime.setNil(key: "alertNotLoopingSnoozedTime")
            UserDefaultsRepository.alertNotLoopingIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertNotLoopingSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertNotLoopingIsSnoozed", value: false)
         
            
        }
        if date > UserDefaultsRepository.alertMissedBolusSnoozedTime.value ?? date {
            UserDefaultsRepository.alertMissedBolusSnoozedTime.setNil(key: "alertMissedBolusSnoozedTime")
            UserDefaultsRepository.alertMissedBolusIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertMissedBolusSnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertMissedBolusIsSnoozed", value: false)

        }
        if date > UserDefaultsRepository.alertSAGESnoozedTime.value ?? date {
            UserDefaultsRepository.alertSAGESnoozedTime.setNil(key: "alertSAGESnoozedTime")
            UserDefaultsRepository.alertSAGEIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertSAGESnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertSAGEIsSnoozed", value: false)
  
        }
        if date > UserDefaultsRepository.alertCAGESnoozedTime.value ?? date {
            UserDefaultsRepository.alertCAGESnoozedTime.setNil(key: "alertCAGESnoozedTime")
            UserDefaultsRepository.alertCAGEIsSnoozed.value = false
            alarms.reloadSnoozeTime(key: "alertCAGESnoozedTime", setNil: true)
            alarms.reloadIsSnoozed(key: "alertCAGEIsSnoozed", value: false)

        }

        
    }
}

