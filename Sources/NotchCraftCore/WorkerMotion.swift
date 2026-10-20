import Foundation
import CoreGraphics

public enum WorkerMotionKind: String, CaseIterable, Sendable {
    case planting, mining, patrolling, reading, hammering, checking, operating, talking, walking, resting, waiting
}
public struct WorkerPose: Equatable, Sendable {
    public var torsoOffset=CGPoint.zero
    public var pathOffset=CGPoint.zero
    public var torsoTilt=0.0
    public var headTilt=0.0
    public var leftArm=0.0
    public var rightArm=0.0
    public var leftLeg=0.0
    public var rightLeg=0.0
    public var toolAngle=0.0
    public var facing=1.0
    public var seedProgress:Double?
    public var impact=0.0
    public var pageTurn=0.0
}
/// Poses describe decorative movement, never task progress. Only observed working states select work clips.
public enum WorkerMotion {
    public static func kind(for activity:ActivityType,status:AgentStatus) -> WorkerMotionKind {
        guard status == .working else { return status == .waitingApproval ? .waiting:.resting }
        return switch activity {
        case .farming: .planting
        case .mining: .mining
        case .monitoring: .patrolling
        case .research: .reading
        case .building,.crafting,.repairing: .hammering
        case .testing: .checking
        case .automation: .operating
        case .meeting: .talking
        case .resting,.approval,.storage: .resting
        }
    }
    private static func smooth(_ value:Double) -> Double {
        let t=min(1,max(0,value)); return t*t*(3-2*t)
    }
    private static func mix(_ a:Double,_ b:Double,_ t:Double) -> Double { a+(b-a)*smooth(t) }
    public static func pose(kind:WorkerMotionKind,elapsed:TimeInterval,reduced:Bool=false) -> WorkerPose {
        var pose=WorkerPose()
        if kind == .reading || kind == .checking {
            pose.leftArm=0.98; pose.rightArm = -0.98; pose.headTilt = -0.08
        }
        if kind == .waiting { pose.headTilt = 0.06 }
        guard !reduced, kind != .resting, kind != .waiting else { return pose }
        let time=elapsed.isFinite ? max(0,elapsed):0
        let period:Double=switch kind {
        case .planting:4.4; case .mining:2.2; case .reading:5.2; case .patrolling:7
        case .hammering:1.8; case .checking:4; case .operating:3; case .talking:3.5
        case .walking:0.65; default:1
        }
        let phase=(time/period).truncatingRemainder(dividingBy:1)
        let wave=sin(phase * .pi * 2)
        switch kind {
        case .planting:
            let bend=smooth((phase-0.18)/0.18)*(1-smooth((phase-0.62)/0.19))
            pose.torsoOffset=CGPoint(x:2*bend,y:-5*bend); pose.torsoTilt = -0.16*bend
            pose.headTilt = -0.18*bend; pose.leftArm = -0.1 - 0.45*bend
            pose.rightArm = 0.12 - 1.05*bend; pose.leftLeg = -0.1*bend; pose.rightLeg=0.16*bend
            pose.pathOffset=CGPoint(x:mix(-7,7,phase < 0.8 ? phase/0.8:(1-phase)/0.2),y:0)
            if (0.39...0.62).contains(phase) { pose.seedProgress=(phase-0.39)/0.23 }
            pose.toolAngle = -0.25*bend
        case .mining,.hammering:
            let anticipation=kind == .mining ? 0.43:0.38
            let hit=kind == .mining ? 0.57:0.53
            let arm:Double
            if phase < anticipation { arm=mix(0.8,2.5,phase/anticipation) }
            else if phase < hit { arm=mix(2.5,0.74,(phase-anticipation)/(hit-anticipation)) }
            else { arm=mix(0.74,0.8,(phase-hit)/(1-hit)) }
            pose.rightArm=arm; pose.leftArm = -0.3
            let contact=(phase >= hit && phase < hit+0.16) ? 1-(phase-hit)/0.16:0
            pose.impact=contact
            pose.toolAngle=phase < anticipation ? mix(-2.32,-0.18,phase/anticipation):
                (phase < hit ? mix(-0.18,-2.32,(phase-anticipation)/(hit-anticipation)):-2.32)
            pose.torsoTilt = -0.06 + 0.12*smooth(arm/2.5)
            pose.torsoOffset=CGPoint(x:contact*1.5,y:-contact*1.4)
            pose.headTilt = -0.04 - contact*0.08
            pose.leftLeg = -0.09; pose.rightLeg=0.09
        case .patrolling:
            let walk=phase < 0.76
            let travel=smooth(min(1,phase/0.76)) * .pi * 2
            pose.pathOffset=CGPoint(x:cos(travel)*20,y:sin(travel)*6)
            pose.facing=sin(travel) < 0 ? -1:1
            let stride=walk ? sin(time*9.5):0
            pose.leftLeg=stride*0.42; pose.rightLeg = -stride*0.42
            pose.leftArm = -stride*0.3; pose.rightArm=walk ? stride*0.25:1.7
            pose.torsoOffset.y=walk ? abs(stride)*0.8:0
            pose.headTilt=walk ? sin(time*1.3)*0.04:sin((phase-0.76)/0.24 * .pi*2)*0.16
        case .reading:
            pose.torsoOffset.y=wave*0.28; pose.headTilt = -0.08+wave*0.02
            pose.pageTurn=(0.70...0.93).contains(phase) ? smooth((phase-0.70)/0.23):0
        case .checking:
            pose.headTilt=mix(-0.1,0.1,(wave+1)/2); pose.rightArm = -0.98+wave*0.08
        case .operating:
            pose.rightArm=0.6+wave*0.55; pose.leftArm = -0.2
            pose.torsoOffset.x=wave*0.7; pose.toolAngle = -0.4+wave*0.3
        case .talking:
            pose.leftArm=0.25+max(0,wave)*0.6; pose.rightArm = -0.2-max(0,-wave)*0.55
            pose.headTilt=wave*0.07
        case .walking:
            pose.leftLeg=wave*0.46; pose.rightLeg = -wave*0.46
            pose.leftArm = -wave*0.34; pose.rightArm=wave*0.34
            pose.torsoOffset.y=abs(wave)*0.8
        case .resting,.waiting:break
        }
        return pose
    }
}
