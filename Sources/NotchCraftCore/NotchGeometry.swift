import Foundation
import CoreGraphics

public struct NotchGeometry: Sendable {
    public let screenFrame: CGRect
    public let visibleFrame: CGRect
    public let topInset: CGFloat
    public let cameraWidth: CGFloat
    public let centerX: CGFloat
    public var hasNotch: Bool { cameraWidth > 0 }
    public init(screenFrame: CGRect, visibleFrame: CGRect, topInset: CGFloat,
                leftAreaMaxX: CGFloat? = nil, rightAreaMinX: CGFloat? = nil) {
        self.screenFrame = screenFrame; self.visibleFrame = visibleFrame; self.topInset = topInset
        if topInset > 0, let left = leftAreaMaxX, let right = rightAreaMinX, right > left {
            cameraWidth = right - left; centerX = (right + left) / 2
        } else { cameraWidth = 0; centerX = screenFrame.midX }
    }
    public var collapsedFrame: CGRect {
        let width = max(280, cameraWidth + 176)
        return CGRect(x: centerX - width / 2, y: screenFrame.maxY - max(38, topInset + 7), width: width, height: max(38, topInset + 7))
    }
    public var expandedFrame: CGRect {
        let width = min(520, screenFrame.width - 40)
        return CGRect(x: centerX - width / 2, y: screenFrame.maxY - 230 - topInset, width: width, height: 230 + topInset)
    }
}
