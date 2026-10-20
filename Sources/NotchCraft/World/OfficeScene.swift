import SpriteKit
import SwiftUI
import NotchCraftCore

@MainActor final class OfficeScene: SKScene {
    private let world = SKNode()
    private var characters: [String: SKNode] = [:]
    private var lastStates: [String: String] = [:]
    private var isBuilt = false
    private var mouseOrigin: CGPoint?
    private var cameraOrigin = CGPoint.zero
    var onSelect: ((String) -> Void)?
    var motionReduced = false
    private var scale: CGFloat = 0.8
    private let cameraNode = SKCameraNode()
    override init(size: CGSize) {
        super.init(size:size); scaleMode = .aspectFit; backgroundColor = .black
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func didMove(to view: SKView) {
        guard !isBuilt else { return }; isBuilt = true
        view.allowsTransparency = false; view.ignoresSiblingOrder = true
        let stars = SKNode(); stars.zPosition = -20
        for i in 0..<120 {
            let x = CGFloat(WorldArtwork.noise(i,4)) / 1000 * size.width
            let y = CGFloat(WorldArtwork.noise(i,7)) / 1000 * size.height
            let star = SKSpriteNode(color:NSColor(white:0.7,alpha:CGFloat(i%4+1)*0.045),size:CGSize(width:i%9==0 ? 2:1,height:i%9==0 ? 2:1))
            star.position = CGPoint(x:x,y:y); stars.addChild(star)
        }
        addChild(stars); addChild(world)
        let island = SKSpriteNode(texture:WorldArtwork.texture)
        island.anchorPoint = .zero; island.position = .zero; island.zPosition = 0; world.addChild(island)
        cameraNode.position = CGPoint(x:640,y:395); cameraNode.setScale(0.8); addChild(cameraNode); camera = cameraNode
        for (index,district) in WorldDistrict.all.enumerated() {
            let label = SKLabelNode(text:L("region."+district.id))
            label.fontName = "SFMono-Medium"; label.fontSize = 11; label.fontColor = NSColor(white:0.9,alpha:0.8)
            label.position = WorldArtwork.project(district.x,district.z,3.3)
            label.zPosition = 30; label.name = "district-\(index)"
            let plate = SKShapeNode(rectOf: CGSize(width:100,height:23),cornerRadius:4)
            plate.fillColor = NSColor(white:0,alpha:0.8); plate.strokeColor = NSColor(white:1,alpha:0.12)
            plate.position.y = 4; plate.zPosition = -1; label.addChild(plate)
            world.addChild(label)
        }
    }
    func sync(sessions:[ProviderSession], snapshots:[String:SessionSnapshot], selected:String?, reduceMotion:Bool) {
        motionReduced = reduceMotion
        let visible = Array(sessions.prefix(32))
        let ids = Set(visible.map(\.id))
        for id in Array(characters.keys) where !ids.contains(id) { characters.removeValue(forKey:id)?.removeFromParent(); lastStates.removeValue(forKey:id) }
        for (index,session) in visible.enumerated() {
            let snapshot = snapshots[session.id]
            let state = snapshot?.status ?? .unknown
            let activity = snapshot?.activity ?? .resting
            let key = "\(state.rawValue)-\(activity.rawValue)-\(selected == session.id)-\(reduceMotion)"
            let character: SKNode
            if let existing = characters[session.id] { character = existing }
            else {
                character = makeCharacter(index:index,session:session)
                characters[session.id] = character; world.addChild(character)
            }
            guard lastStates[session.id] != key else { continue }; lastStates[session.id] = key
            character.removeAllActions(); character.childNode(withName:"body")?.removeAllActions()
            character.childNode(withName:"tool")?.removeAllActions()
            let district = WorldDistrict.forActivity(activity)
            let offset = Double(index/6) * 0.6
            let location = WorldArtwork.project(district.x-0.5+offset,district.z-0.7-offset,0.3)
            if character.position == .zero || reduceMotion { character.position = location }
            else { character.run(.move(to:location,duration:0.9)) }
            character.zPosition = 40 + CGFloat(index) * 0.01
            character.alpha = state == .unknown ? 0.55:1
            character.childNode(withName:"selection")?.isHidden = selected != session.id
            let tool = character.childNode(withName:"tool") as? SKSpriteNode
            if let tool { configureTool(tool, activity: activity) }
            tool?.isHidden = state != .working
            if state == .working && !reduceMotion {
                character.childNode(withName:"body")?.run(.repeatForever(.sequence([.moveBy(x:0,y:2,duration:0.5),.moveBy(x:0,y:-2,duration:0.5)])))
                tool?.run(.repeatForever(.sequence([.rotate(byAngle:0.7,duration:0.3),.rotate(byAngle:-0.7,duration:0.3),.wait(forDuration:0.6)])))
            }
            let dot = character.childNode(withName:"dot") as? SKShapeNode
            dot?.fillColor = state == .working ? WorldArtwork.color(0xA5C582) : (state == .waitingApproval ? WorldArtwork.color(0xE2B36E):NSColor.gray)
        }
    }
    private func makeCharacter(index:Int,session:ProviderSession) -> SKNode {
        let root = SKNode(); root.name = session.id
        let shadow = SKShapeNode(ellipseOf:CGSize(width:32,height:12)); shadow.fillColor = NSColor(white:0,alpha:0.4); shadow.strokeColor = .clear; root.addChild(shadow)
        let selection = SKShapeNode(ellipseOf:CGSize(width:44,height:19)); selection.name = "selection"; selection.fillColor = .clear; selection.strokeColor = WorldArtwork.color(0xBDD39F); selection.lineWidth=1.5; root.addChild(selection)
        let body = SKSpriteNode(texture:WorldArtwork.character(index:index)); body.name = "body"; body.anchorPoint=CGPoint(x:0.5,y:0); body.setScale(1.4); root.addChild(body)
        let tool = SKSpriteNode(color:WorldArtwork.color(0xD7D6BE),size:CGSize(width:16,height:4)); tool.name="tool"; tool.position=CGPoint(x:20,y:20); tool.zRotation=0.8; root.addChild(tool)
        let handle = SKSpriteNode(color:WorldArtwork.color(0x9D7847),size:CGSize(width:3,height:16)); handle.position=CGPoint(x:-3,y:-5); tool.addChild(handle)
        let dot = SKShapeNode(rectOf:CGSize(width:4,height:4)); dot.name="dot"; dot.strokeColor = .clear; dot.position=CGPoint(x:0,y:53); root.addChild(dot)
        let label = SKLabelNode(text:String(session.name.prefix(16))); label.fontName="SFMono-Medium"; label.fontSize=9; label.fontColor=NSColor(white:0.88,alpha:1); label.position=CGPoint(x:0,y:-15); root.addChild(label)
        return root
    }
    private func configureTool(_ tool: SKSpriteNode, activity: ActivityType) {
        tool.removeAllChildren()
        tool.size = CGSize(width:16,height:4)
        tool.color = WorldArtwork.color(0xC7CEC5)
        tool.zRotation = 0.8
        func part(_ color: UInt32, _ size: CGSize, _ point: CGPoint) {
            let node = SKSpriteNode(color:WorldArtwork.color(color),size:size); node.position=point; tool.addChild(node)
        }
        switch activity {
        case .research, .meeting:
            tool.size=CGSize(width:18,height:12); tool.color=WorldArtwork.color(0xDCCBA7); tool.zRotation=0
            part(0x92734E,CGSize(width:2,height:12),.zero)
            part(0xA2987C,CGSize(width:5,height:1),CGPoint(x:4,y:2))
            part(0xA2987C,CGSize(width:5,height:1),CGPoint(x:-4,y:-1))
        case .testing, .monitoring:
            tool.size=CGSize(width:12,height:16); tool.color=WorldArtwork.color(0xBEAF8D); tool.zRotation=0
            part(0x839B63,CGSize(width:6,height:3),CGPoint(x:0,y:3))
            part(0x839B63,CGSize(width:6,height:2),CGPoint(x:0,y:-3))
        case .farming:
            tool.color=WorldArtwork.color(0x879F60)
            part(0xA58152,CGSize(width:3,height:18),CGPoint(x:-3,y:-7))
        case .building, .repairing, .crafting:
            tool.size=CGSize(width:10,height:9); tool.color=WorldArtwork.color(0xA6AAA2)
            part(0xA58152,CGSize(width:3,height:17),CGPoint(x:0,y:-10))
        default:
            part(0xA58152,CGSize(width:3,height:16),CGPoint(x:-3,y:-5))
        }
    }
    func zoom(by factor:CGFloat) { scale = min(1.65,max(0.5,scale*factor)); cameraNode.setScale(scale) }
    func resetView() { scale = 0.8; cameraNode.setScale(0.8); cameraNode.position=CGPoint(x:640,y:395) }
    func focus(_ district:WorldDistrict) { cameraNode.position=WorldArtwork.project(district.x,district.z,1); scale=0.65; cameraNode.setScale(scale) }
    override func scrollWheel(with event:NSEvent) { zoom(by:1 + event.scrollingDeltaY * 0.01) }
    override func mouseDown(with event:NSEvent) { mouseOrigin=event.location(in:self); cameraOrigin=cameraNode.position }
    override func mouseDragged(with event:NSEvent) {
        guard let origin=mouseOrigin else { return }
        let point=event.location(in:self)
        cameraNode.position.x = min(1050,max(230,cameraNode.position.x + origin.x-point.x))
        cameraNode.position.y = min(690,max(160,cameraNode.position.y + origin.y-point.y))
    }
    override func mouseUp(with event:NSEvent) {
        defer { mouseOrigin=nil }
        guard let origin=mouseOrigin else { return }
        let point=event.location(in:self)
        guard hypot(point.x-origin.x,point.y-origin.y) < 12 else { return }
        let local=convert(point,to:world)
        if let nearest=characters.min(by:{ hypot($0.value.position.x-local.x,$0.value.position.y+20-local.y) < hypot($1.value.position.x-local.x,$1.value.position.y+20-local.y) }),
           hypot(nearest.value.position.x-local.x,nearest.value.position.y+20-local.y) < 45 { onSelect?(nearest.key) }
    }
}

// Own the AppKit surface explicitly so rebuilding SwiftUI controls never loses the presented scene.
struct OfficeSurface: NSViewRepresentable {
    let scene: OfficeScene
    let framesPerSecond: Int
    func makeNSView(context: Context) -> SKView {
        let view = SKView(frame: CGRect(origin:.zero,size:WorldArtwork.size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        view.allowsTransparency = false
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = framesPerSecond
        view.presentScene(scene)
        view.isPaused = false
        return view
    }
    func updateNSView(_ view: SKView, context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
        scene.isPaused = false
        view.isPaused = false
        view.preferredFramesPerSecond = framesPerSecond
    }
    static func dismantleNSView(_ view: SKView, coordinator: ()) {
        view.isPaused = true
        view.presentScene(nil)
    }
}
