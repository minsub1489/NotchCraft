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
    /// Visible controls begin below both the menu bar and the physical camera housing.
    public var contentTopY: CGFloat { min(visibleFrame.maxY, screenFrame.maxY - max(0,topInset)) }
    public var collapsedFrame: CGRect {
        let width = min(max(248, cameraWidth + 72), max(120,visibleFrame.width - 24))
        let x = min(max(centerX - width / 2, visibleFrame.minX + 12), visibleFrame.maxX - width - 12)
        return CGRect(x:x,y:contentTopY-36,width:width,height:36)
    }
    public var expandedFrame: CGRect {
        let width = min(484, max(120,visibleFrame.width - 24))
        let height = min(224,max(120,visibleFrame.height - 24))
        let x = min(max(centerX - width / 2, visibleFrame.minX + 12), visibleFrame.maxX - width - 12)
        return CGRect(x:x,y:contentTopY-height,width:width,height:height)
    }
}
