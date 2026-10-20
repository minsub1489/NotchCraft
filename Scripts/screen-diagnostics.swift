import AppKit
import Foundation
let screens=NSScreen.screens.map { screen -> [String:Any] in
    ["width":screen.frame.width,"height":screen.frame.height,"topInset":screen.safeAreaInsets.top,
     "cameraGap":max(0,(screen.auxiliaryTopRightArea?.minX ?? 0)-(screen.auxiliaryTopLeftArea?.maxX ?? 0)),
     "visibleWidth":screen.visibleFrame.width,"visibleHeight":screen.visibleFrame.height]
}
let data=try JSONSerialization.data(withJSONObject:screens,options:[.sortedKeys])
print(String(decoding:data,as:UTF8.self))
