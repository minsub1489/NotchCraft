import SpriteKit
import NotchCraftCore

/// Small articulated voxel resident. Its work clip changes only with observed agent state.
@MainActor final class WorkerNode: SKNode {
    private let actor=SKNode(), rig=SKNode(), torso=SKNode(), head=SKNode()
    private let leftArm=SKNode(), rightArm=SKNode(), leftLeg=SKNode(), rightLeg=SKNode()
    private let handTool=SKNode(), book=SKNode(), turningPage=SKNode(), workpiece=SKNode()
    private let statusDot=SKShapeNode(rectOf:CGSize(width:4,height:4))
    private let selection=SKShapeNode(ellipseOf:CGSize(width:43,height:18))
    private var seeds:[SKSpriteNode]=[], chips:[SKSpriteNode]=[]
    private var kind=WorkerMotionKind.resting
    private var reduced=false
    private var epoch:TimeInterval?
    private var taskID:String?
    private var activity=ActivityType.resting
    private var status=AgentStatus.unknown
    private var destination=CGPoint.zero
    private var travelOrigin=CGPoint.zero
    private var travelEpoch:TimeInterval?
    private var travelDuration=0.0
    private let phaseOffset:Double
    init(index:Int,session:ProviderSession) {
        phaseOffset=Double(index % 7)*0.17
        super.init(); name=session.id
        addChild(actor)
        let shadow=SKShapeNode(ellipseOf:CGSize(width:30,height:10))
        shadow.fillColor=NSColor.black.withAlphaComponent(0.4); shadow.strokeColor = .clear; shadow.zPosition = -2
        actor.addChild(shadow)
        selection.name="selection"; selection.fillColor = .clear; selection.strokeColor=WorldArtwork.color(0xBDD39F); selection.lineWidth=1.2; selection.zPosition = -1
        actor.addChild(selection); actor.addChild(rig)
        let shirts:[UInt32]=[0x7CA9B0,0xB58EB6,0xA5B26A,0xC69763,0x89B6A2,0xB9AE87]
        let shirt=shirts[index % shirts.count]
        actor.addChild(workpiece); workpiece.zPosition = -0.5; workpiece.position=CGPoint(x:27,y:0)
        rig.addChild(leftLeg); rig.addChild(rightLeg)
        leftLeg.name="leg-left"; rightLeg.name="leg-right"; leftLeg.position=CGPoint(x:-4.2,y:12); rightLeg.position=CGPoint(x:4.2,y:12)
        leftLeg.zPosition=1; rightLeg.zPosition=2
        for leg in [leftLeg,rightLeg] {
            pixel(leg,0,-6,6,12,0x586776); pixel(leg,0,-10.5,7,3,0x3D3D38)
        }
        torso.name="torso"; torso.position=CGPoint(x:0,y:12); torso.zPosition=3; rig.addChild(torso)
        pixel(torso,0,7,16,14,shirt); pixel(torso,0,10,4,7,0xDBD5BF)
        pixel(torso,0,1,16,2,0x675545); pixel(torso,3,1,3,2,0xD9BD78)
        head.name="head"; head.position=CGPoint(x:0,y:15); head.zPosition=6; torso.addChild(head)
        pixel(head,0,8,18,16,0xE6BF95); pixel(head,7,7,4,13,0xCAA17D)
        pixel(head,0,15,18,3,0x6A503A); pixel(head,-7,11,3,7,0x6A503A)
        pixel(head,-3,9,2,2,0x262B25); pixel(head,3,9,2,2,0x262B25)
        pixel(head,0,4,4,2,0xAA7655); pixel(head,0,17,21,3,shirt)
        leftArm.name="arm-left"; rightArm.name="arm-right"
        for (arm,x,z) in [(leftArm,-10.0,4.0),(rightArm,10.0,8.0)] {
            torso.addChild(arm); arm.position=CGPoint(x:x,y:13); arm.zPosition=z
            pixel(arm,0,-2,5,5,shirt); pixel(arm,0,-8.5,4,9,0xE0B58B)
        }
        handTool.name="tool"; handTool.position=CGPoint(x:0,y:-13); handTool.zPosition=10; rightArm.addChild(handTool)
        book.name="book"; book.position=CGPoint(x:0,y:19); book.zPosition=12; rig.addChild(book)
        turningPage.name="page"; turningPage.position=CGPoint(x:0,y:0); turningPage.zPosition=3
        for i in 0..<3 {
            let seed=SKSpriteNode(color:WorldArtwork.color(0xDDC48B),size:CGSize(width:2,height:2)); seed.zPosition=15; actor.addChild(seed); seeds.append(seed)
            let chip=SKSpriteNode(color:WorldArtwork.color(i == 0 ? 0x9BD0CD:0xC2C5B5),size:CGSize(width:2,height:2)); chip.zPosition=14; actor.addChild(chip); chips.append(chip)
        }
        statusDot.name="dot"; statusDot.strokeColor = .clear; statusDot.position=CGPoint(x:0,y:51); actor.addChild(statusDot)
        let label=SKLabelNode(text:String(session.name.prefix(16))); label.fontName=NSFont.monospacedSystemFont(ofSize:9,weight:.medium).fontName; label.fontSize=9
        label.fontColor=NSColor(white:0.88,alpha:1); label.position=CGPoint(x:0,y:-15); label.zPosition=20; actor.addChild(label)
        configureProps(); render(elapsed:0)
    }
    required init?(coder:NSCoder) { fatalError("init(coder:) is unavailable") }
    private func pixel(_ parent:SKNode,_ x:Double,_ y:Double,_ w:Double,_ h:Double,_ color:UInt32) {
        let sprite=SKSpriteNode(color:WorldArtwork.color(color),size:CGSize(width:w,height:h)); sprite.position=CGPoint(x:x,y:y); parent.addChild(sprite)
    }
    func configure(activity:ActivityType,status:AgentStatus,taskID:String?,reduced:Bool,selected:Bool) {
        selection.isHidden = !selected
        alpha=status == .unknown ? 0.55:1
        let colors:[AgentStatus:UInt32]=[.working:0xA5C582,.waitingApproval:0xE2B36E,.failed:0xEB8A7D,.completed:0x88B8AA]
        statusDot.fillColor=WorldArtwork.color(colors[status] ?? 0x82877D)
        guard self.activity != activity || self.status != status || self.reduced != reduced || self.taskID != taskID else { return }
        self.activity=activity; self.status=status; self.reduced=reduced; self.taskID=taskID
        kind=WorkerMotion.kind(for:activity,status:status); epoch=nil
        if (reduced || status != .working), travelDuration > 0 { position=destination; travelDuration=0 }
        configureProps(); render(elapsed:0)
    }
    func move(to target:CGPoint) {
        guard target != destination else { return }
        if position == .zero || reduced || status != .working {
            position=target; destination=target; travelDuration=0; return
        }
        travelOrigin=position; destination=target; travelEpoch=nil
        travelDuration=min(2.5,max(0.6,hypot(target.x-position.x,target.y-position.y)/95))
    }
    func tick(_ time:TimeInterval) {
        if epoch == nil { epoch=time }
        if travelDuration > 0 {
            if travelEpoch == nil { travelEpoch=time }
            let progress=min(1,max(0,(time-(travelEpoch ?? time))/travelDuration))
            position=CGPoint(x:travelOrigin.x+(destination.x-travelOrigin.x)*progress,y:travelOrigin.y+(destination.y-travelOrigin.y)*progress)
            render(pose:WorkerMotion.pose(kind:.walking,elapsed:time-(travelEpoch ?? time),reduced:reduced))
            if progress >= 1 { travelDuration=0; epoch=time }
        } else { render(elapsed:time-(epoch ?? time)+phaseOffset) }
    }
    func render(elapsed:TimeInterval) { render(pose:WorkerMotion.pose(kind:kind,elapsed:elapsed,reduced:reduced)) }
    private func render(pose:WorkerPose) {
        workpiece.isHidden=travelDuration > 0 || ![WorkerMotionKind.mining,.hammering,.operating].contains(kind)
        book.isHidden=travelDuration > 0 || ![WorkerMotionKind.reading,.checking].contains(kind)
        actor.position=pose.pathOffset
        rig.position=pose.torsoOffset; rig.xScale=pose.facing
        torso.zRotation=pose.torsoTilt; head.zRotation=pose.headTilt
        leftArm.zRotation=pose.leftArm; rightArm.zRotation=pose.rightArm
        leftLeg.zRotation=pose.leftLeg; rightLeg.zRotation=pose.rightLeg
        handTool.zRotation=pose.toolAngle-pose.rightArm-pose.torsoTilt
        turningPage.xScale=cos(pose.pageTurn * .pi)
        turningPage.isHidden=pose.pageTurn == 0
        for (i,seed) in seeds.enumerated() {
            guard let progress=pose.seedProgress else { seed.isHidden=true; continue }
            let p=min(1,max(0,progress-Double(i)*0.08))
            seed.isHidden=false; seed.alpha=1-p*0.75
            seed.position=CGPoint(x:2+20*p+Double(i)*2,y:12*(1-p)+sin(p * .pi)*5)
        }
        for (i,chip) in chips.enumerated() {
            chip.isHidden=pose.impact <= 0
            let p=1-pose.impact, direction=Double(i-1)
            chip.alpha=pose.impact
            chip.position=CGPoint(x:27+direction*p*15,y:4+sin(p * .pi)*10+Double(i))
        }
    }
    private func configureProps() {
        handTool.removeAllChildren(); book.removeAllChildren(); turningPage.removeAllChildren(); workpiece.removeAllChildren()
        handTool.isHidden=false; book.isHidden=true; workpiece.isHidden=true
        switch kind {
        case .planting:
            pixel(handTool,0,0,7,8,0x8B6941); pixel(handTool,0,4,5,2,0xCEB67C)
        case .mining:
            pixel(handTool,0,8,3,19,0x9A794A)
            pixel(handTool,0,17,20,4,0xAFC7C3); pixel(handTool,-9,14,3,7,0x88ABA8); pixel(handTool,9,14,3,7,0x88ABA8)
            workpiece.isHidden=false
            pixel(workpiece,0,5,21,13,0x596761); pixel(workpiece,8,4,5,10,0x43504B)
            pixel(workpiece,-4,8,4,3,0x7BC2BB); pixel(workpiece,4,3,3,4,0x9DD3CF); pixel(workpiece,1,10,3,2,0x91B8B0)
        case .hammering:
            pixel(handTool,0,7,3,18,0x9B794B); pixel(handTool,0,16,13,8,0xAEB5AC)
            workpiece.isHidden=false; pixel(workpiece,0,3,22,8,0x96764C); pixel(workpiece,0,8,25,3,0xB09A70)
        case .reading,.checking:
            handTool.isHidden=true; book.isHidden=false
            pixel(book,0,0,24,15,kind == .reading ? 0x7B543D:0x637965)
            pixel(book,-5.5,1,10,12,0xDDD2AD); pixel(book,5.5,1,10,12,0xF0E4C2)
            for x in [-6.0,6.0] { for y in [-2.0,1.0,4.0] { pixel(book,x,y,7,1,0xA19879) } }
            pixel(book,0,0,1,15,0x94784E)
            pixel(turningPage,5.5,1,11,12,0xF3E7CB); turningPage.zPosition=4; book.addChild(turningPage)
        case .patrolling:
            pixel(handTool,0,1,8,11,0x695C44); pixel(handTool,0,1,4,7,0xF2CE81)
            pixel(handTool,0,7,9,2,0x596157); pixel(handTool,0,10,3,5,0x626B61)
        case .operating:
            pixel(handTool,0,5,3,14,0x9CABA5); pixel(handTool,0,13,10,4,0x657B71)
            workpiece.isHidden=false; pixel(workpiece,0,6,20,15,0x65736B); pixel(workpiece,-4,7,5,5,0xD2B66D)
        case .talking,.walking,.resting,.waiting: handTool.isHidden=true
        }
    }
}
