import Foundation

extension Date {

    var bubbleFormat: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        dateFormatter.doesRelativeDateFormatting = true

        return dateFormatter.string(from: self)
    }

    func formatTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    func adding(seconds: Int) -> Date {
        Calendar.current.date(byAdding: .second, value: seconds, to: self)!
    }
}
