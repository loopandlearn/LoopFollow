// LoopFollow
// UIViewExtension.swift

import Foundation
import UIKit

extension UIView {
    enum ViewSide {
        case Left, Right, Top, Bottom
    }

    func addBorder(toSide side: ViewSide, withColor color: CGColor, andThickness thickness: CGFloat) {
        let border = CALayer()
        border.backgroundColor = color

        switch side {
        case .Left: border.frame = CGRect(x: 0, y: 0, width: thickness, height: frame.height)
        case .Right: border.frame = CGRect(x: frame.width - thickness, y: 0, width: thickness, height: frame.height)
        case .Top: border.frame = CGRect(x: 0, y: 0, width: frame.width, height: thickness)
        case .Bottom: border.frame = CGRect(x: 0, y: frame.height - thickness, width: frame.width, height: thickness)
        }
        layer.addSublayer(border)
    }
}
