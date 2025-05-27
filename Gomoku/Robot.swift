//
//  Robot.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 5/27/25.
//

import Foundation
import SpriteKit

enum RobotState {
    case Thinking, Winning, Losing, StrongMove, Cornered
}

/* Animation template */

class Robot:SKSpriteNode {
    func thinking() {
        // Eyes dart side to side, gears rotate
        
        //eye.run(.sequence([.scale(to: 1.2, duration: 0.1), .scale(to: 1.0, duration: 0.1)]))

    }
    
    func playing_move() {
        // Smirk/Aha! expression
    }
    
    func wins() {
        // Glowing eyes, evil laugh
    }
    
    func loses() {
        // static burts, frowning, sparks fly
    }
    
    func human_wins_streak() {
        // shocked eyes, sweating, glitchy mouth
    }
    
    func tie() {
        // Shrug, head tilt
    }
}
