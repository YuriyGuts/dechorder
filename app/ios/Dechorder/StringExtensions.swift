import Foundation

extension String {
    
    static func alternativeIfNilOrEmpty(_ string: String?, alternative: String) -> String {
        if string == nil || string?.isEmpty == true {
            return alternative
        }
        return string!
    }
    
}
