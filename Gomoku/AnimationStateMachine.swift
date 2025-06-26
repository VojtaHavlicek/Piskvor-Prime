//
//  AnimationStateMachine.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 5/23/25.
//

import Foundation
import SpriteKit

enum AnimationState {
    case Idle, Winning, Joking
}

class AnimationStateMachine {
    
    private var current_state:AnimationState?
    
    let transitions:[AnimationState: [AnimationState]] = [.Idle:[.Idle,.Joking,.Winning], .Joking:[.Idle, .Winning], .Winning:[]]
    var on_enter:[AnimationState: ()->()]?
    
    // Animation objects
    var head:SKSpriteNode?
    
    init(scene:SKScene) {
        head = (scene.childNode(withName: "head") as! SKSpriteNode)
        on_enter = [.Idle: enters_idle, .Joking: enters_joking, .Winning: enters_winning]
        
        change_state(state: .Idle)
    }
    
    // Tries to change the state
    func change_state(state:AnimationState)
    {
        if current_state == nil || transitions[current_state!]!.contains(state) {
            current_state = state
            on_enter![current_state!]!()
        }
    }
    
    
    func enters_idle() {
        let moveUp = SKAction.moveBy(x: 0, y: 25, duration: 1.0)
        moveUp.timingMode = .easeInEaseOut
        
        let scaleUp = SKAction.scale(to: 0.6, duration: 0.5)
        let moveDown = moveUp.reversed()
        let sequence = SKAction.sequence([moveDown, moveUp])
        let loop = SKAction.repeatForever(sequence)
        head!.run(scaleUp)
        head!.run(loop)
    }
    
    func enters_joking() {
        
    }
    
    func enters_winning() {
        
    }
}
