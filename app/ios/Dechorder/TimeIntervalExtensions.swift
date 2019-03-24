import Foundation

extension TimeInterval {

    func formattedForPlayer() -> String {
        let rawSeconds = Int(self)
        let minutes = rawSeconds / 60
        let seconds = rawSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

}
