import AppKit
import SpriteKit
import NotchCraftCore

struct WorldDistrict: Identifiable {
    let id: String
    let x: Double
    let z: Double
    let activity: ActivityType
    static let all = [
        Self(id: "farm", x: -7, z: 2, activity: .farming),
        Self(id: "mine", x: -6, z: -5, activity: .mining),
        Self(id: "build", x: 6, z: -3, activity: .building),
        Self(id: "library", x: 2, z: 6, activity: .research),
        Self(id: "forge", x: 0, z: -6, activity: .crafting),
        Self(id: "tower", x: 7, z: 3, activity: .monitoring)
    ]
    static func forActivity(_ activity: ActivityType) -> Self {
        switch activity {
        case .farming: all[0]
        case .mining: all[1]
        case .building, .repairing: all[2]
        case .research, .meeting, .resting, .approval: all[3]
        case .crafting, .testing, .storage: all[4]
        case .automation, .monitoring: all[5]
        }
    }
}
/// Original geometry and palettes. No game files, textures, skins or external assets.
@MainActor enum WorldArtwork {
    static let size = CGSize(width: 1280, height: 820)
    static func project(_ x: Double, _ z: Double, _ y: Double = 0) -> CGPoint {
        CGPoint(x: 640 + (x - z) * 24, y: 380 + (x + z) * 12 + y * 22)
    }
    static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
    }
    struct Block {
        var x: Double; var z: Double; var y: Double
        var w: Double = 1; var d: Double = 1; var h: Double = 1
        var color: UInt32; var top: UInt32?
    }
    static let image: NSImage = render()
    static let texture: SKTexture = {
        let texture = SKTexture(image: image); texture.filteringMode = .nearest; return texture
    }()
    static func noise(_ x: Int, _ z: Int, _ salt: Int = 0) -> Int {
        abs((x &* 73856093) ^ (z &* 19349663) ^ (salt &* 83492791)) % 1000
    }
    private static func polygon(_ points: [CGPoint], color: NSColor) {
        let path = NSBezierPath(); path.move(to: points[0]); points.dropFirst().forEach { path.line(to: $0) }; path.close()
        color.setFill(); path.fill()
    }
    private static func draw(_ b: Block) {
        let a = project(b.x, b.z, b.y + b.h), r = project(b.x + b.w, b.z, b.y + b.h)
        let t = project(b.x + b.w, b.z + b.d, b.y + b.h), l = project(b.x, b.z + b.d, b.y + b.h)
        let a0 = project(b.x, b.z, b.y), r0 = project(b.x + b.w, b.z, b.y), l0 = project(b.x, b.z + b.d, b.y)
        let base = color(b.color)
        polygon([a, l, l0, a0], color: base.blended(withFraction: 0.26, of: .black) ?? base)
        polygon([a, r, r0, a0], color: base.blended(withFraction: 0.12, of: .black) ?? base)
        polygon([a, r, t, l], color: b.top.map(color) ?? (base.blended(withFraction: 0.08, of: .white) ?? base))
        // Small deterministic texels make the original surfaces read as voxel materials.
        let seed = noise(Int(b.x * 13), Int(b.z * 17), Int(b.y * 11))
        for n in 0..<5 {
            let u = Double((seed + n * 173) % 800 + 100) / 1000
            let v = Double((seed * 3 + n * 227) % 800 + 100) / 1000
            let px = b.x + b.w * u, pz = b.z + b.d * v
            let q = min(0.11, min(b.w, b.d) * 0.18)
            let tint = n % 2 == 0 ? NSColor.black.withAlphaComponent(0.07):NSColor.white.withAlphaComponent(0.07)
            polygon([project(px,pz,b.y+b.h+0.002),project(px+q,pz,b.y+b.h+0.002),project(px+q,pz+q,b.y+b.h+0.002),project(px,pz+q,b.y+b.h+0.002)],color:tint)
        }
        if b.h > 0.5, b.w <= 1.1 {
            for n in 0..<3 {
                let y = b.y + b.h * Double(n + 1) / 4
                polygon([project(b.x+0.08,b.z,y),project(b.x+b.w*0.6,b.z,y),project(b.x+b.w*0.6,b.z,y+0.055),project(b.x+0.08,b.z,y+0.055)],color:NSColor.black.withAlphaComponent(0.09))
            }
        }
    }
    private static func render() -> NSImage {
        var blocks: [Block] = []
        func block(_ x: Double, _ z: Double, _ y: Double, _ w: Double, _ d: Double, _ h: Double, _ color: UInt32, top: UInt32? = nil) {
            blocks.append(Block(x: x, z: z, y: y, w: w, d: d, h: h, color: color, top: top))
        }
        let grasses: [UInt32] = [0x5E793D, 0x657D40, 0x71884A, 0x5B753A, 0x6C8146]
        let rocks: [UInt32] = [0x555956, 0x62615B, 0x4A4D4A, 0x6D6860]
        for x in -12...11 { for z in -10...10 {
            let radius = pow(Double(x) / 12, 2) + pow(Double(z) / 10, 2)
            guard radius < 0.94 + Double(noise(x, z)) / 9000 else { continue }
            let depth = 1.2 + (1 - min(1, radius)) * 3.4 + Double(noise(x, z, 1) % 5) * 0.28
            block(Double(x), Double(z), -depth, 1, 1, depth - 0.7, rocks[noise(x,z) % rocks.count])
            block(Double(x), Double(z), -0.7, 1, 1, 0.7, 0x70543A, top: grasses[noise(x,z) % grasses.count])
            block(Double(x), Double(z), 0, 1, 1, 0.12, 0x4B6736, top: grasses[noise(x,z,2) % grasses.count])
            if abs(x) <= 1 || abs(z) <= 0 {
                block(Double(x), Double(z), 0.13, 0.95, 0.95, 0.06, noise(x,z) % 2 == 0 ? 0xA69A7C : 0x908A76)
            } else if noise(x, z, 4) < 40 {
                block(Double(x) + 0.3, Double(z) + 0.3, 0.12, 0.12, 0.12, 0.23, 0x95A563)
            }
        }}
        // Timber and stone office at the heart of the island.
        func house(x: Double, z: Double, width: Int, depth: Int, height: Int, roof: UInt32, library: Bool = false) {
            for ix in 0..<width { for iz in 0..<depth {
                block(x + Double(ix), z + Double(iz), 0.15, 1, 1, 0.45, 0x77766B)
                if ix == 0 || iz == 0 || ix == width - 1 || iz == depth - 1 {
                    for iy in 0..<height {
                        let corner = (ix == 0 || ix == width-1) && (iz == 0 || iz == depth-1)
                        let isDoor = ix == width/2 && iz == 0 && iy < 2
                        if isDoor { continue }
                        let window = !corner && iy == 1
                        let value: UInt32 = corner ? 0x62482E : (window ? 0xE5BF70 : (library ? 0x9B8057 : 0xB3A082))
                        block(x + Double(ix), z + Double(iz), 0.6 + Double(iy) * 0.65, 1, 1, 0.65, value)
                        if window { block(x + Double(ix) + 0.4, z + Double(iz) - 0.02, 1.3, 0.09, 0.08, 0.55, 0x5C4730) }
                    }
                }
            }}
            for step in 0...width/2 {
                block(x - 0.35 + Double(step), z - 0.45, 0.6 + Double(height) * 0.65 + Double(step) * 0.8,
                      Double(width) + 0.7 - Double(step) * 2, Double(depth) + 0.9, 0.45, roof)
            }
            block(x + Double(width) - 1.2, z + Double(depth) - 1.5, 3.2, 0.6, 0.6, 1.4, 0x77746B)
        }
        house(x: -2.2, z: 1.7, width: 5, depth: 4, height: 4, roof: 0x4B6659)
        house(x: 0.8, z: 6, width: 4, depth: 3, height: 3, roof: 0x71604F, library: true)
        house(x: -1.8, z: -7, width: 3, depth: 3, height: 3, roof: 0x6A655B)
        // Farm plots, seedlings and water channels.
        for ix in -9 ... -5 { for iz in 1...5 {
            block(Double(ix), Double(iz), 0.2, 0.9, 0.9, 0.12, iz % 3 == 0 ? 0x417D8A : 0x685236)
            if iz % 3 != 0 { for j in 0..<3 {
                block(Double(ix) + Double(j) * 0.26, Double(iz) + 0.2, 0.32, 0.13, 0.13, 0.45 + Double(noise(ix,iz,j)%4) * 0.08, j % 2 == 0 ? 0xC3B15E : 0x8F9F4E)
            }}
        }}
        // Mine mouth with exposed original crystal geometry.
        for ix in -8 ... -4 { for iz in -7 ... -4 where ix == -8 || ix == -4 || iz == -7 {
            block(Double(ix), Double(iz), 0.1, 1, 1, Double(noise(ix,iz)%3) * 0.4 + 1.2, 0x686B66)
        }}
        for i in 0..<9 {
            let x = -7.7 + Double(i % 4) * 0.8, z = -6.8 + Double(i / 4) * 0.7
            block(x, z, 0.2, 0.23, 0.23, 0.45 + Double(i % 3) * 0.2, i % 2 == 0 ? 0x6BAFAF : 0xA89AC0)
        }
        for i in 0..<7 {
            block(-7.6 + Double(i)*0.55, -4.7, 0.22, 0.14, 0.8, 0.06, 0x9B7A4F)
            block(-7.6 + Double(i)*0.55, -4.65, 0.3, 0.58, 0.08, 0.07, 0x747D79)
            block(-7.6 + Double(i)*0.55, -4.0, 0.3, 0.58, 0.08, 0.07, 0x747D79)
        }
        // Crane, unfinished stone wall and material crates.
        block(6.5, -2.5, 0.12, 0.35, 0.35, 4.6, 0xA78349)
        block(3.7, -2.5, 4.5, 4.2, 0.35, 0.3, 0xB79757)
        block(4, -2.4, 2.8, 0.06, 0.06, 1.6, 0xA3A39A)
        block(3.8, -2.6, 2.5, 0.5, 0.5, 0.3, 0x7D817A)
        for i in 0..<4 {
            block(4 + Double(i), -5, 0.14, 0.9, 0.9, Double(i % 3 + 1) * 0.5, 0x85857B)
            block(7.3, -4 + Double(i) * 0.6, 0.12, 0.55, 0.55, 0.55, 0xA18150)
        }
        // Lookout on wooden stilts.
        for x in [6.5,8.5] { for z in [2.0,4.0] { block(x,z,0.15,0.28,0.28,3.0,0x6B5032) } }
        block(6.2,1.7,3.1,2.9,2.9,0.25,0xAC8D5E)
        block(6.0,1.5,4.9,3.3,3.3,0.3,0x4D6855)
        for x in [6.5,8.5] { for z in [2.0,4.0] { block(x,z,3.3,0.18,0.18,1.6,0x6B5032) } }
        // Workbench, forge and campfire.
        block(-0.5,-5.5,0.13,0.9,0.8,0.8,0x686D6B); block(-0.4,-5.52,0.25,0.7,0.1,0.35,0xEAB867)
        block(1.3,-5.3,0.13,1,0.7,0.8,0x927345)
        // Low fences and lantern posts.
        for i in -9 ... -4 {
            block(Double(i), 0.5, 0.2, 0.12, 0.12, 0.7, 0x947246)
            block(Double(i), 0.5, 0.5, 1, 0.1, 0.1, 0xA08250)
        }
        for (x,z) in [(-3.5,0.2),(3.5,0.2),(-2.5,-3.3),(2.5,-3.3),(-6.5,5.5),(6.5,-5.5),(5.2,4.3)] {
            block(x,z,0.15,0.15,0.15,1.5,0x675039)
            block(x-0.12,z-0.12,1.65,0.4,0.4,0.45,0xE6B568)
            block(x-0.18,z-0.18,2.1,0.52,0.52,0.1,0x493D2A)
        }
        func tree(_ x: Double, _ z: Double, _ scale: Double = 1) {
            block(x,z,0.1,0.45,0.45,2.8*scale,0x6B5134)
            for level in 0..<3 {
                let width = (2.5 - Double(level)*0.6)*scale
                block(x-width/2+0.2,z-width/2+0.2,1.6*scale+Double(level)*0.7*scale,width,width,0.9*scale,
                      [UInt32(0x425D36),0x536E3E,0x647D49][level])
            }
        }
        for (x,z,s) in [(-8.0,6.4,1.1),(-5.0,7.5,1.0),(-10.0,-0.5,0.8),(5.0,6.5,0.95),(9.0,-0.5,0.8),(2.0,8.8,0.7),(-9.5,-4.5,0.7),(4.0,-7.0,0.65)] { tree(x,z,s) }
        // Tiny detached islands.
        for (x,z) in [(-16.0,1.5),(14.0,4.5),(-1.0,14.0)] {
            block(x,z,-2,2,2,1.3,0x64645B); block(x,z,-0.7,2,2,0.6,0x71573B,top:0x5A753D)
            block(x+0.6,z+0.6,-0.1,0.3,0.3,1.4,0x6B5134)
            block(x+0.1,z+0.1,1.0,1.3,1.3,0.8,0x526F3D)
        }
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .none
        NSGraphicsContext.current?.shouldAntialias = false
        // Draw back to front. Height resolves blocks at the same footprint.
        blocks.sort {
            let a = $0.x + $0.z - $0.y * 2.5, b = $1.x + $1.z - $1.y * 2.5
            return abs(a-b) < 0.001 ? $0.y < $1.y : a > b
        }
        blocks.forEach(draw)
        // A few warm light pools, kept subtle against the black canvas.
        NSGraphicsContext.current?.shouldAntialias = true
        for (x,z) in [(-3.5,0.2),(3.5,0.2),(-2.5,-3.3),(2.5,-3.3),(-6.5,5.5),(6.5,-5.5)] {
            let p = project(x,z,1.85)
            let gradient = NSGradient(starting: color(0xF5C175).withAlphaComponent(0.23), ending: .clear)
            gradient?.draw(in: NSBezierPath(ovalIn: CGRect(x:p.x-28,y:p.y-28,width:56,height:56)), relativeCenterPosition: .zero)
        }
        image.unlockFocus()
        return image
    }
    static let thumbnails: [String:NSImage] = Dictionary(uniqueKeysWithValues: WorldDistrict.all.map { ($0.id, makeThumbnail($0)) })
    static func thumbnail(_ district: WorldDistrict) -> NSImage { thumbnails[district.id] ?? image }
    private static func makeThumbnail(_ district: WorldDistrict) -> NSImage {
        let result = NSImage(size: CGSize(width: 220, height: 110))
        let point = project(district.x,district.z,1)
        result.lockFocus()
        NSColor.black.setFill(); NSBezierPath(rect:CGRect(x:0,y:0,width:220,height:110)).fill()
        image.draw(in: CGRect(x:0,y:0,width:220,height:110), from: CGRect(x:point.x-110,y:point.y-35,width:220,height:110), operation:.sourceOver, fraction:1)
        result.unlockFocus()
        return result
    }
    static func snapshot(sessions:[ProviderSession], states:[String:SessionSnapshot]) -> NSImage {
        let result = NSImage(size:size)
        result.lockFocus()
        NSColor.black.setFill(); NSBezierPath(rect:CGRect(origin:.zero,size:size)).fill()
        image.draw(at:.zero,from:.zero,operation:.sourceOver,fraction:1)
        NSGraphicsContext.current?.imageInterpolation = .none
        for (index,session) in sessions.prefix(32).enumerated() {
            let state=states[session.id]
            let district=WorldDistrict.forActivity(state?.activity ?? .resting)
            let offset=Double(index/6)*0.6
            let point=project(district.x-0.5+offset,district.z-0.7-offset,0.3)
            characterImages[index % characterImages.count].draw(in:CGRect(x:point.x-16.8,y:point.y,width:33.6,height:44.8),from:.zero,operation:.sourceOver,fraction:state?.status == .unknown ? 0.55:1)
        }
        result.unlockFocus()
        return result
    }
    static let characterImages = (0..<6).map { makeCharacterImage(index: $0) }
    static func character(index: Int) -> SKTexture {
        let texture=SKTexture(image:characterImages[index % characterImages.count]); texture.filteringMode = .nearest; return texture
    }
    private static func makeCharacterImage(index: Int) -> NSImage {
        let image = NSImage(size: CGSize(width: 24,height:32))
        image.lockFocus(); NSGraphicsContext.current?.shouldAntialias = false
        let shirts: [UInt32] = [0x7CA9B0,0xB58EB6,0xA5B26A,0xC69763,0x89B6A2,0xB9AE87]
        func rect(_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ c:UInt32) { color(c).setFill(); NSBezierPath(rect:CGRect(x:x,y:y,width:w,height:h)).fill() }
        rect(6,1,5,8,0x525E68); rect(13,1,5,8,0x525E68)
        rect(5,0,6,3,0x3B3936); rect(13,0,6,3,0x3B3936)
        rect(5,9,14,10,shirts[index%shirts.count]); rect(10,12,4,7,0xD8D5BB)
        rect(2,9,3,9,0xE4B88F); rect(19,9,3,9,0xD3A37A)
        rect(5,19,14,12,0xE8C29A); rect(5,29,14,3,0x6B523E)
        rect(5,25,2,5,0x6B523E); rect(9,24,2,2,0x292A24); rect(15,24,2,2,0x292A24)
        rect(11,20,4,2,0xA97C5A); rect(3,28,18,3,shirts[index%shirts.count])
        image.unlockFocus()
        return image
    }
}
