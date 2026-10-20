import AppKit
let output = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories:true)
for size in [16,32,64,128,256,512,1024] {
    let image = NSImage(size:NSSize(width:size,height:size))
    image.lockFocus()
    let scale = CGFloat(size)/128
    let transform = NSAffineTransform(); transform.scale(by:scale); transform.concat()
    NSColor(srgbRed:0.025,green:0.03,blue:0.025,alpha:1).setFill()
    NSBezierPath(roundedRect:NSRect(x:2,y:2,width:124,height:124),xRadius:27,yRadius:27).fill()
    func poly(_ points:[NSPoint], _ r:CGFloat,_ g:CGFloat,_ b:CGFloat) {
        let p=NSBezierPath(); p.move(to:points[0]); points.dropFirst().forEach{p.line(to:$0)}; p.close(); NSColor(srgbRed:r,green:g,blue:b,alpha:1).setFill(); p.fill()
    }
    poly([NSPoint(x:27,y:78),NSPoint(x:64,y:97),NSPoint(x:101,y:78),NSPoint(x:64,y:59)],0.64,0.76,0.48)
    poly([NSPoint(x:27,y:78),NSPoint(x:64,y:59),NSPoint(x:64,y:27),NSPoint(x:27,y:46)],0.34,0.42,0.27)
    poly([NSPoint(x:64,y:59),NSPoint(x:101,y:78),NSPoint(x:101,y:46),NSPoint(x:64,y:27)],0.49,0.57,0.36)
    poly([NSPoint(x:27,y:65),NSPoint(x:64,y:46),NSPoint(x:64,y:27),NSPoint(x:27,y:46)],0.38,0.29,0.20)
    poly([NSPoint(x:64,y:46),NSPoint(x:101,y:65),NSPoint(x:101,y:46),NSPoint(x:64,y:27)],0.49,0.37,0.25)
    image.unlockFocus()
    guard let tiff=image.tiffRepresentation,let rep=NSBitmapImageRep(data:tiff),let data=rep.representation(using:.png,properties:[:]) else { continue }
    let names:[String]
    switch size {
    case 16:names=["icon_16x16.png"]
    case 32:names=["icon_16x16@2x.png","icon_32x32.png"]
    case 64:names=["icon_32x32@2x.png"]
    case 128:names=["icon_128x128.png"]
    case 256:names=["icon_128x128@2x.png","icon_256x256.png"]
    case 512:names=["icon_256x256@2x.png","icon_512x512.png"]
    default:names=["icon_512x512@2x.png"]
    }
    for name in names { try data.write(to:URL(fileURLWithPath:output).appendingPathComponent(name)) }
}
