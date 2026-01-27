// LoopFollow
// ChartContainerView.swift

import Charts
import UIKit

class NonInteractiveContainerView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isUserInteractionEnabled = false
    }

    override func hitTest(_: CGPoint, with _: UIEvent?) -> UIView? {
        return nil
    }
}
