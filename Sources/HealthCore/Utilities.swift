// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum LocalDate {public static func string(from date:Date,timeZone:TimeZone = .current)->String{let formatter=DateFormatter();formatter.calendar=Calendar(identifier:.gregorian);formatter.locale=Locale(identifier:"en_US_POSIX");formatter.timeZone=timeZone;formatter.dateFormat="yyyy-MM-dd";return formatter.string(from:date)}}
public struct LocalDayRange: Sendable {
    public let start: Date
    public let end: Date

    public init(date: Date, calendar: Calendar = .current) {
        start = calendar.startOfDay(for: date)
        end = calendar.date(byAdding: .day, value: 1, to: start)!
    }

    public var rfc3339: (String, String) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
        return (formatter.string(from: start), formatter.string(from: end))
    }
}

public enum FormEncoding {
    public static func field(_ name: String, value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: allowed)!
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed)!
        return "\(encodedName)=\(encodedValue)"
    }
}
