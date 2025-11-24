import Foundation

extension String {
    // Anonymizes credit card info using Luhn algorithm
    func maskingPrivateInfo() -> String {
        let pattern = #"\b(?:\d[ -]*?){13,19}\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return self }
        let range = NSRange(startIndex..<endIndex, in: self)
        let matches = regex.matches(in: self, options: [], range: range)
        var newString = self as NSString
        matches.reversed().forEach {
            let cardInfo = newString.substring(with: $0.range)
                .replacingOccurrences(of: "[ -]*", with: "", options: .regularExpression)
            if isLuhnChecksumValid(cardInfo) {
                let mask = String(repeating: "*", count: cardInfo.count)
                newString = newString.replacingCharacters(in: $0.range, with: mask) as NSString
            }
        }
        return newString as String
    }

    // Luhn algorithm implementation
    private func isLuhnChecksumValid(_ number: String) -> Bool {
        let digits = number.compactMap { $0.wholeNumberValue }
        guard !digits.isEmpty else { return false }

        let checksum = digits.reversed().enumerated().reduce(0) { sum, element in
            let (index, digit) = element
            let doubled = index % 2 == 1 ? digit * 2 : digit
            return sum + (doubled > 9 ? doubled - 9 : doubled)
        }

        return checksum % 10 == 0
    }
}
