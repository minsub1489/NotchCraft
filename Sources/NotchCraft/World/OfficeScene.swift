import SpriteKit
import SwiftUI
import NotchCraftCore

@MainActor final class OfficeScene: SKScene {
    private let world = SKNode()
    private var characters: [String: WorkerNode] = [:]
    private var isBuilt = false
    private var mouseOrigin: CGPoint?
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
            label.fontName = NSFont.monospacedSystemFont(ofSize:11,weight:.medium).fontName; label.fontSize = 11; label.fontColor = NSColor(white:0.9,alpha:0.8)
            label.position = WorldArtwork.project(district.x,district.z,3.3)
            label.zPosition = 30; label.name = "district-\(index)"
            let plate = SKShapeNode(rectOf: CGSize(width:100,height:23),cornerRadius:4)
            plate.fillColor = NSColor(white:0,alpha:0.8); plate.strokeColor = NSColor(white:1,alpha:0.12)
            plate.position.y = 4; plate.zPosition = -1; label.addChild(plate)
            world.addChild(label)
        }
    }
    func sync(sessions:[ProviderSession], snapshots:[String:SessionSnapshot], selected:String?, reduceMotion:Bool) {
        motionReduced=reduceMotion
        let visible=Array(sessions.prefix(32)), ids=Set(sessions.prefix(32).map(\.id))
        for id in Array(characters.keys) where !ids.contains(id) { characters.removeValue(forKey:id)?.removeFromParent() }
        for (index,session) in visible.enumerated() {
            let worker:WorkerNode
            if let existing=characters[session.id] { worker=existing }
            else { worker=WorkerNode(index:index,session:session); characters[session.id]=worker; world.addChild(worker) }
            let snapshot=snapshots[session.id]
            let activity=snapshot?.activity ?? .resting
            worker.configure(activity:activity,status:snapshot?.status ?? .unknown,taskID:snapshot?.taskID,reduced:reduceMotion,selected:selected == session.id)
            let district=WorldDistrict.forActivity(activity)
            let offset=Double(index/6)*0.75
            worker.move(to:WorldArtwork.project(district.x-0.5+offset,district.z-0.7-offset,0.3))
            worker.zPosition=40+CGFloat(index)*0.01
        }
    }
    override func update(_ currentTime:TimeInterval) {
        for worker in characters.values { worker.tick(currentTime) }
    }
    func zoom(by factor:CGFloat) { scale = min(1.65,max(0.5,scale*factor)); cameraNode.setScale(scale) }
    func resetView() { scale = 0.8; cameraNode.setScale(0.8); cameraNode.position=CGPoint(x:640,y:395) }
    func focus(_ district:WorldDistrict) { cameraNode.position=WorldArtwork.project(district.x,district.z,1); scale=0.65; cameraNode.setScale(scale) }
    override func scrollWheel(with event:NSEvent) { zoom(by:1 + event.scrollingDeltaY * 0.01) }
    override func mouseDown(with event:NSEvent) { mouseOrigin=event.location(in:self) }
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
