//
//  FirstViewController.swift
//  LoopFollow
//
//  Created by Jon Fawcett on 6/1/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import UIKit
import Charts

class MainViewController: UIViewController, UITableViewDataSource {
    
    @IBOutlet weak var BGText: UILabel!
    @IBOutlet weak var DeltaText: UILabel!
    @IBOutlet weak var DirectionText: UILabel!
    @IBOutlet weak var BGChart: LineChartView!
    @IBOutlet weak var BGChartFull: LineChartView!
    @IBOutlet weak var MinAgoText: UILabel!
    @IBOutlet weak var infoTable: UITableView!
    
    //NS BG Struct
    struct sgvData: Codable {
        var sgv: Int
        var date: TimeInterval
        var direction: String?
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
    
    // Info Table Setup
    var tableData = [
        infoData(name: "IOB", value: ""), //0
        infoData(name: "COB", value: ""), //1
        infoData(name: "Basal", value: ""), //2
        infoData(name: "Override", value: ""), //3
        infoData(name: "Battery", value: ""), //4
        infoData(name: "Pump", value: ""), //5
        infoData(name: "Loop", value: ""), //6
        infoData(name: "SAGE", value: ""), //7
        infoData(name: "CAGE", value: "") //8
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        UNUserNotificationCenter.current().requestAuthorization(options: .badge) { (granted, error) in
            if error != nil {
                // success!
            }
        }
        
        // ToDo: Should continue running in background
        // stop timer when app enters in background, start is again when becomes active
        let notificationCenter = NotificationCenter.default
            notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(appCameToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        //Bind info data
        infoTable.rowHeight = 25
        infoTable.dataSource = self
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        Reload()
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
    
    // Timer
    fileprivate func startTimer(time: TimeInterval) {
        timer = Timer.scheduledTimer(timeInterval: time,
                                     target: self,
                                     selector: #selector(MainViewController.timerDidEnd(_:)),
                                     userInfo: nil,
                                     repeats: true)
    }
    
    @objc func appMovedToBackground() {
        timer.invalidate()
        if UserDefaultsRepository.backgroundRefresh.value {
            backgroundTask.startBackgroundTask()
            startTimer(time: TimeInterval(UserDefaultsRepository.backgroundRefreshFrequency.value))
        }
    }

   @objc func appCameToForeground() {
       if UserDefaultsRepository.backgroundRefresh.value {
            backgroundTask.stopBackgroundTask()
            timer.invalidate()
        }
        startTimer(time: timeInterval)
        loadBGData(urlUser: urlUser)
        loadDeviceStatus(urlUser: urlUser)
    
   }
    
    // check whether new Values should be retrieved
    @objc func timerDidEnd(_ timer:Timer) {
        print("timer ended")
        Reload()
    }
    
    func Reload() {
        loadBGData(urlUser: urlUser)
        clearLastInfoData()
        loadDeviceStatus(urlUser: urlUser)
        loadTempBasals(urlUser: urlUser)
    }
    

    // Main NS Data Pull
    func loadBGData(urlUser: String) {
        let points = String(self.graphHours * 12 + 1)
        var urlBGDataPath: String = urlUser + "/api/v1/entries/sgv.json?"
        if token == "" {
            urlBGDataPath = urlBGDataPath + "count=" + points
        }
        else
        {
            urlBGDataPath = urlBGDataPath + "token=" + token + "&count=" + points
        }
        guard let urlBGData = URL(string: urlBGDataPath) else {
            return
        }
        var request = URLRequest(url: urlBGData)
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        
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
                    if self.backgroundTask.player.isPlaying {
                        self.updateBadge(entries: entriesResponse)
                    } else {
                        self.updateBG(entries: entriesResponse)
                        self.createGraph(entries: entriesResponse)
                    }
                   
                    
                }
            }
            else
            {
                
                return
            }
        }
        getBGTask.resume()
    }
    
    //Clear the info data before next pull
    func clearLastInfoData(){
       for i in 0..<tableData.count{
        tableData[i].value = ""
        }
    }
    
    
    
    // NS Device Status Pull
    func loadDeviceStatus(urlUser: String) {
        var urlStringDeviceStatus = urlUser + "/api/v1/devicestatus.json?count=1"
        if token != "" {
            urlStringDeviceStatus = urlUser + "/api/v1/devicestatus.json?token=" + token + "&count=1"
        }
        
        let escapedAddress = urlStringDeviceStatus.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        guard let urlDeviceStatus = URL(string: escapedAddress!) else {
            return
        }
        
        if consoleLogging == true {print("entered 2nd task.")}
        var requestDeviceStatus = URLRequest(url: urlDeviceStatus)
        requestDeviceStatus.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        let deviceStatusTask = URLSession.shared.dataTask(with: requestDeviceStatus) { data, response, error in
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
        deviceStatusTask.resume()
    }
    
    // Need to figure out the date to pull only last 24 hours
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
                  //  BatteryText.text! += " " + String(format:"%.0f", upbat) + "%"
                    tableData[4].value = String(format:"%.0f", upbat) + "%"
                }
                
            }
        }
                
        if let lastLoopRecord = lastDeviceStatus?["loop"] as! [String : AnyObject]? {
            if let lastLoopTime = formatter.date(from: (lastLoopRecord["timestamp"] as! String))?.timeIntervalSince1970  {
                if let failure = lastLoopRecord["failureReason"] {
                    
                    //LoopStatusText.text! += " Failure "
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
                       // let prediction = predictdata["values"] as! [Double]
                       // loopStatusText += " EBG " + bgOutputFormat(bg: prediction.last!, mmol: mmol)
                    }
                    
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
        
    func stringFromTimeInterval(interval: TimeInterval) -> String {
        let interval = Int(interval)
        let minutes = (interval / 60) % 60
        let hours = (interval / 3600)
        return String(format: "%02d:%02d", hours, minutes)
    }

    func createGraph(entries: [sgvData]){
        var bgChartEntry = [ChartDataEntry]()
        var colors = [NSUIColor]()
        for i in 0..<entries.count{
            var dateString = String(entries[entries.count - 1 - i].date).prefix(10)
            let dateSecondsOnly = Double(String(dateString))!
            
            let value = ChartDataEntry(x: Double(dateSecondsOnly), y: Double(entries[entries.count - 1 - i].sgv))
            bgChartEntry.append(value)
            
            if Double(entries[entries.count - 1 - i].sgv) > 180 {
                colors.append(NSUIColor.yellow)
            } else if Double(entries[entries.count - 1 - i].sgv) < 70 {
                colors.append(NSUIColor.red)
            } else {
                colors.append(NSUIColor.green)
            }
        }
        let line1 = LineChartDataSet(entries:bgChartEntry, label: "")
        line1.circleRadius = 3
        line1.circleColors = [NSUIColor.green]
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
        BGChart.xAxis.valueFormatter = ChartXValueFormatter()
        BGChart.xAxis.granularity = 1800
        BGChart.xAxis.labelTextColor = NSUIColor.white
        BGChart.rightAxis.labelTextColor = NSUIColor.white
        BGChart.leftAxis.enabled = false
        BGChart.legend.enabled = false
        BGChart.scaleYEnabled = false
        BGChart.data = data
        BGChart.setExtraOffsets(left: 10, top: 10, right: 10, bottom: 10)
        BGChart.setVisibleXRangeMinimum(10)
        if firstStart {
            BGChart.zoom(scaleX: 20, scaleY: 1, x: 1, y: 1)
            firstStart = false
        }
        BGChart.moveViewToX(BGChart.chartXMax)
        
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
        UIApplication.shared.applicationIconBadgeNumber = 0
        if entries.count > 0 && UserDefaultsRepository.appBadge.value {
            let latestBG = entries[0].sgv
            UIApplication.shared.applicationIconBadgeNumber = latestBG
        }
        print("updated badge")
    }
    
    func updateBG (entries: [sgvData]) {
        if consoleLogging == true {print("in update BG")}
        UIApplication.shared.applicationIconBadgeNumber = 0
        if entries.count > 0 {
            let latestBG = entries[0].sgv
            let priorBG = entries[1].sgv
            let deltaBG = latestBG - priorBG as Int
            let lastBGTime = entries[0].date / 1000 //NS has different units
            let deltaTime = (TimeInterval(Date().timeIntervalSince1970)-lastBGTime) / 60
            var userUnit = " mg/dL"
            if mmol {
                userUnit = " mmol/L"
            }
            if UserDefaultsRepository.appBadge.value {
                UIApplication.shared.applicationIconBadgeNumber = latestBG
            }
            
            BGText.text = bgOutputFormat(bg: Double(latestBG), mmol: mmol)
            MinAgoText.text = String(Int(deltaTime)) + " min ago"
            print(String(Int(deltaTime)) + " min ago")
            if let directionBG = entries[0].direction {
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
        
        
        if consoleLogging == true {print("end update bg")}
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
    
    func bgDirectionGraphic(_ value:String)->String {
        let graphics:[String:String]=["Flat":"\u{2192}","DoubleUp":"\u{21C8}","SingleUp":"\u{2191}","FortyFiveUp":"\u{2197}\u{FE0E}","FortyFiveDown":"\u{2198}\u{FE0E}","SingleDown":"\u{2193}","DoubleDown":"\u{21CA}","None":"-","NOT COMPUTABLE":"-","RATE OUT OF RANGE":"-"]
        
        
        return graphics[value]!
    }
    
}

