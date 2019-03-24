import UIKit

class ChordChartView: UIView {
    
    @IBOutlet weak var chordChartImage: UIImageView?
    @IBOutlet weak var chordNameLabel: UILabel?
    @IBOutlet weak var timeOffsetLabel: UILabel?
    @IBOutlet weak var contentView: UIView!
    
    override init(frame: CGRect) { // for using CustomView in code
        super.init(frame: frame)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) { // for using CustomView in IB
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    private func commonInit() {
        Bundle.main.loadNibNamed("ChordChartView", owner: self, options: nil)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.addSubview(contentView)
    }
    
    func loadChord(_ chord: Chord) {
        guard let chordChartImage = chordChartImage,
            let chordNameLabel = chordNameLabel,
            let timeOffsetLabel = timeOffsetLabel,
            let chordName = chord.name else {
            return
        }
        chordChartImage.image = chartImage(forChord: chord)
        chordNameLabel.text = chordName
        timeOffsetLabel.text = formatTimeOffset(chord.timeOffset)
    }
    
    func chartImage(forChord chord: Chord) -> UIImage? {
        guard let chordName = chord.name else {
            return nil
        }
        if let matchingImage = UIImage(named: "chord_chart_" + chordName) {
            return matchingImage
        }
        return UIImage(named: "chord_chart_unknown")
    }
    
    func formatTimeOffset(_ timeOffset: NSNumber?) -> String {
        guard let timeOffset = timeOffset else {
            return "00:00"
        }
        let rawSeconds = Int(truncating: timeOffset)
        let minutes = rawSeconds / 60
        let seconds = rawSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
