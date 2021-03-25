//
//  DateExtension.swift
//  F1TV
//
//  Created by Noah Fetz on 25.10.20.
//

import Foundation

extension Date {
    func getDateAsString() -> String {
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy"
        return df.string(from: self)
    }
    
    func getDateAsStringWithLongMonth() -> String {
        let df = DateFormatter()
        df.dateFormat = "dd. MMMM yyyy"
        return df.string(from: self)
    }
    
    func getDateAsStringWithLongMonthWithoutYear() -> String {
        let df = DateFormatter()
        df.dateFormat = "dd. MMMM"
        return df.string(from: self)
    }
    
    func getDateAsStringWithoutYear() -> String {
        let df = DateFormatter()
        df.dateFormat = "dd.MM."
        return df.string(from: self)
    }
    
    func getDateAsStringWithWeekday() -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, dd.MM.yyyy"
        return df.string(from: self)
    }
    
    func getDateAsStringWithWeekdayAndTime() -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, dd. MMMM yyyy, HH:mm"
        return df.string(from: self)
    }
    
    func getDateAsStringWithWeekdayAndLongMonthWithYear() -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, dd. MMMM yyyy"
        return df.string(from: self)
    }
    
    func getShortDay() -> String {
        let df = DateFormatter()
        df.dateFormat = "EE"
        return df.string(from: self)
    }
    
    func getDateAsRelativeStringWithWeekday() -> String {
        let relDf = DateFormatter()
        let df = DateFormatter()
        
        relDf.doesRelativeDateFormatting = true
        relDf.timeStyle = .none
        relDf.dateStyle = .full
        
        df.dateFormat = "EEEE, dd. MMMM yyyy"
        
        if(self.isToday() || self.isTomorrow() || self.isYesterday()) {
            return relDf.string(from: self) + ", " + self.getDateAsStringWithLongMonth()
        }
        return df.string(from: self)
    }
    
    func getDateRelativeAsTimeOrDate() -> String {
        if(self.isToday()) {
            return self.getTimeAsString()
        }
        
        if(self.removeTime.distance(to: Date().removeTime) <= 2) {
            let relDf = DateFormatter()
            
            relDf.doesRelativeDateFormatting = true
            relDf.timeStyle = .none
            relDf.dateStyle = .long
            
            return relDf.string(from: self)
        }
        
        let df = DateFormatter()
        df.dateFormat = "dd.MM.yy"
        return df.string(from: self)
    }
    
    func getDateAsStringWithTime() -> String {
    let df = DateFormatter()
        df.dateFormat = "dd.MM.yyyy HH:mm:ss"
    return df.string(from: self)
    }
    
    func getDateAsStringForFileNames() -> String {
    let df = DateFormatter()
        df.dateFormat = "yyyy_MM_dd-HH_mm_ss"
        return df.string(from: self) + "_" + UUID().uuidString
    }
    
    func getWeekdayWithTime() -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, HH:mm"
        return df.string(from: self)
    }
    
    func getDayWithShortMonth() -> String {
        let df = DateFormatter()
        df.dateFormat = "d MMM"
        return df.string(from: self)
    }
    
    func getTimeAsString() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: self)
    }
    
    func getTimeAsStringWithSeconds() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df.string(from: self)
    }
    
    func dateAt(hours: Int, minutes: Int) -> Date {
        let calendar = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)!
        
        var date_components = calendar.components(
            [NSCalendar.Unit.year,
             NSCalendar.Unit.month,
             NSCalendar.Unit.day],
            from: self)
        
        date_components.hour = hours
        date_components.minute = minutes
        date_components.second = 0
        
        let newDate = calendar.date(from: date_components)!
        return newDate
    }
    
    func getYear() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy"
        return df.string(from: self)
    }
    
    func getMonth() -> String {
        let df = DateFormatter()
        df.dateFormat = "MM"
        return df.string(from: self)
    }
    
    func getLongMonth() -> String {
        let df = DateFormatter()
        df.dateFormat = "MMMM"
        return df.string(from: self)
    }
    
    func getMonthShort() -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM"
        let output = df.string(from: self).uppercased().replacingOccurrences(of: ".", with: "")
        return output
    }
    
    func getDay() -> String {
        let df = DateFormatter()
        df.dateFormat = "dd"
        return df.string(from: self)
    }
    
    func getHour() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH"
        return df.string(from: self)
    }
    
    func setHour(hour: Int) -> Date? {
        return Calendar.current.date(bySettingHour: hour, minute: Int(self.getMinute()) ?? 0, second: Int(self.getSecond()) ?? 0, of: self)
    }
    
    func getMinute() -> String {
        let df = DateFormatter()
        df.dateFormat = "mm"
        return df.string(from: self)
    }
    
    func setMinute(minute: Int) -> Date? {
        return Calendar.current.date(bySettingHour: Int(self.getHour()) ?? 0, minute: minute, second: Int(self.getSecond()) ?? 0, of: self)
    }
    
    func getSecond() -> String {
        let df = DateFormatter()
        df.dateFormat = "ss"
        return df.string(from: self)
    }
    
    func setSecond(second: Int) -> Date? {
        return Calendar.current.date(bySettingHour: Int(self.getHour()) ?? 0, minute: Int(self.getMinute()) ?? 0, second: second, of: self)
    }
    
    var zeroSeconds: Date? {
        get {
            let calender = Calendar.current
            let dateComponents = calender.dateComponents([.year, .month, .day, .hour, .minute], from: self)
            return calender.date(from: dateComponents)
        }
    }
    
    var removeTime: Date {
        get {
            let calender = Calendar.current
            let dateComponents = calender.dateComponents([.year, .month, .day], from: self)
            return calender.date(from: dateComponents) ?? self
        }
    }
    
    func getCurrentMillis()->Int64 {
        return Int64(Date().timeIntervalSince1970 * 1000)
    }
    
    func isBetween(_ date1: Date, and date2: Date) -> Bool {
        return (min(date1, date2) ... max(date1, date2)).contains(self)
    }
    
    func isToday() -> Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    func isYesterday() -> Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    func isTomorrow() -> Bool {
        return Calendar.current.isDateInTomorrow(self)
    }
    
    var iso8601: String {
        return Formatter.Date.iso8601.string(from: self)
    }
    
    var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}

extension Formatter {
    struct Date {
        static let iso8601: DateFormatter = {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .iso8601)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            return formatter
        }()
    }
}

extension String {
    var iso8601: Date? {
        return Formatter.Date.iso8601.date(from: self)
    }
}

extension TimeInterval{
    func stringFromTimeInterval() -> String {
        
        let time = NSInteger(self)
        
        let seconds = time % 60
        let minutes = (time / 60) % 60
        let hours = (time / 3600)
        
        return String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
    }
}
