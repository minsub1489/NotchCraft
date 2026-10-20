import AppKit
import SpriteKit
import ImageIO
import UniformTypeIdentifiers
import Testing
import NotchCraftCore
@testable import NotchCraft

/// Optional original-art diagnostic, rendered from the same resident rig used by the app.
@MainActor @Test func renderActivityMotionPreview() throws {
    guard let path=ProcessInfo.processInfo.environment["NOTCHCRAFT_MOTION_GIF"] else { return }
    let url=URL(fileURLWithPath:path)
    try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
    let scene=SKScene(size:CGSize(width:960,height:260)); scene.backgroundColor = .black
    let view=SKView(frame:CGRect(origin:.zero,size:scene.size)); view.presentScene(scene)
    let entries:[(String,ActivityType)]=[("PLANTING",.farming),("MINING",.mining),("PATROL",.monitoring),("READING",.research),("BUILDING",.building),("TESTING",.testing)]
    var residents:[WorkerNode]=[]
    for (index,entry) in entries.enumerated() {
        let session=ProviderSession(id:"demo-\(index)",name:"",cwd:"",updatedAt:Date())
        let worker=WorkerNode(index:index,session:session)
        worker.configure(activity:entry.1,status:.working,taskID:"demo",reduced:false,selected:false)
        worker.position=CGPoint(x:80+index*160,y:85); worker.setScale(2.4); scene.addChild(worker); residents.append(worker)
        let label=SKLabelNode(text:entry.0); label.fontName="SFMono-Medium"; label.fontSize=11
        label.fontColor=WorldArtwork.color(0xA5C582); label.position=CGPoint(x:80+index*160,y:24); scene.addChild(label)
    }
    let title=SKLabelNode(text:"NOTCHCRAFT / ACTIVITY MOTIONS / DEMO PREVIEW")
    title.fontName="SFMono-Medium"; title.fontSize=10; title.fontColor=NSColor(white:0.5,alpha:1); title.position=CGPoint(x:480,y:239); scene.addChild(title)
    let frameCount=84
    let destination=try #require(CGImageDestinationCreateWithURL(url as CFURL,UTType.gif.identifier as CFString,frameCount,nil))
    CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
    for frame in 0..<frameCount {
        try autoreleasepool {
            for worker in residents { worker.render(elapsed:Double(frame)/12) }
            let texture=try #require(view.texture(from:scene))
            let frameImage=texture.cgImage()
            CGImageDestinationAddImage(destination,frameImage,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/12]] as CFDictionary)
            if frame == 21, let png=NSBitmapImageRep(cgImage:frameImage).representation(using:.png,properties:[:]) {
                try png.write(to:url.deletingPathExtension().appendingPathExtension("png"))
            }
        }
    }
    #expect(CGImageDestinationFinalize(destination))
    #expect((try Data(contentsOf:url)).count > 1000)
    view.presentScene(nil)
}
