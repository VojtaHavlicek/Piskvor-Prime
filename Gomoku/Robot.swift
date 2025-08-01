//
//  Robot.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 5/27/25.
//

import Foundation
import SpriteKit

enum RobotState {
    case Idle, Thinking, Winning, Losing, Laughing
}

/* Animation template */

class RobotController:SKNode {
    private let body:SKSpriteNode
    
    private let left_eye:SKSpriteNode!
    private let left_eye_textures:[SKTexture]!
    
    private let right_eye:SKSpriteNode!
    private let right_eye_textures:[SKTexture]!
    
    private let mouth:SKSpriteNode!
    private let mouth_textures:[SKTexture]!
    
    private let lightbulb_textures:[SKTexture]!
    private let lightbulb:SKSpriteNode!
    
    private var idle_action:SKAction?
    // Eye animation textures
    
    override init() {
        body = SKSpriteNode(texture: SKTexture(imageNamed: "head"))
        body.zPosition = 2
        
        
        let left_eye_atlas = SKTextureAtlas(named: "left_eye")
        let left_eye_sorted = left_eye_atlas.textureNames.sorted {
            let num1 = Int($0.components(separatedBy: CharacterSet.decimalDigits.inverted).last ?? "") ?? 0
            let num2 = Int($1.components(separatedBy: CharacterSet.decimalDigits.inverted).last ?? "") ?? 0
            return num1 < num2
        }
        
        left_eye_textures = Array(left_eye_sorted.map { left_eye_atlas.textureNamed($0) }).reversed()
        left_eye = SKSpriteNode(texture: left_eye_textures[0])
        left_eye.zPosition = 3
        
        
        let right_eye_atlas = SKTextureAtlas(named: "right_eye")
        let right_eye_sorted = right_eye_atlas.textureNames.sorted {
            let num1 = Int($0.components(separatedBy: CharacterSet.decimalDigits.inverted).last ?? "") ?? 0
            let num2 = Int($1.components(separatedBy: CharacterSet.decimalDigits.inverted).last ?? "") ?? 0
            return num1 < num2
        }
        right_eye_textures = Array(right_eye_sorted.map { right_eye_atlas.textureNamed($0) }).reversed()
        right_eye = SKSpriteNode(texture: right_eye_textures[0])
        right_eye.zPosition = 3
        
        
        let mouth_atlas = SKTextureAtlas(named: "mouth")
        let mouth_sorted = mouth_atlas.textureNames.sorted {
            let num1 = Int($0.components(separatedBy: CharacterSet.decimalDigits.inverted).last ?? "") ?? 0
            let num2 = Int($1.components(separatedBy: CharacterSet.decimalDigits.inverted).last ?? "") ?? 0
            return num1 < num2
        }
        mouth_textures = Array(mouth_sorted.map { mouth_atlas.textureNamed($0) }).reversed()
        mouth = SKSpriteNode(texture: mouth_textures[0])
        mouth.zPosition = 4
 
        
        let lightbulb_atlas = SKTextureAtlas(named: "lightbulb")
        lightbulb_textures = Array(lightbulb_atlas.textureNames.sorted().map { lightbulb_atlas.textureNamed($0) }).reversed()
        lightbulb = SKSpriteNode(texture: lightbulb_textures[0])
        lightbulb.zPosition = 5
        
        super.init()
        
        setupIdleAnimation()
        
        self.addChild(body)
        self.addChild(left_eye)
        self.addChild(right_eye)
        self.addChild(mouth)
        self.addChild(lightbulb)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    // --- EXPRESSION CONTROLLS ---
    // TODO: prepare enum for expressions?
    func set_expression(eye:String, mouth:String) {
        
    }
    
    func setExpressionPreset(_ preset: ExpressionPreset) {
        switch preset {
        case .thinking:
            set_expression(eye: "left", mouth: "flat")
        case .winning:
            set_expression(eye: "glow", mouth: "smile")
        case .losing:
            set_expression(eye: "cracked", mouth: "frown")
        case .smug:
            set_expression(eye: "neutral", mouth: "smirk")
        }
        
        }
    
    
    func blink() {
        let left_open = SKAction.animate(with: left_eye_textures, timePerFrame: 0.01)
        let left_close = SKAction.animate(with: left_eye_textures.reversed(), timePerFrame: 0.01)
        let left_sequence = SKAction.sequence([left_open, left_close])
        
        let right_open = SKAction.animate(with: right_eye_textures, timePerFrame: 0.01)
        let right_close = SKAction.animate(with: right_eye_textures.reversed(), timePerFrame: 0.01)
        let right_sequence = SKAction.sequence([right_open, right_close])
        
        left_eye.run(left_sequence)
        right_eye.run(right_sequence)
    }
    
    func bounce_mouth() {
        let up = SKAction.moveBy(x: 0, y: 10, duration: 0.1)
        let down = SKAction.moveBy(x: 0, y: -10, duration: 0.1)
        mouth.run(SKAction.repeat(SKAction.sequence([up,down]), count: 3))
    }
    
    func eye_dart_left_right() {
        let left = SKAction.moveBy(x: -3, y: 0, duration: 0.01)
        let right = SKAction.moveBy(x: 3, y: 0, duration: 0.01)
        let back = SKAction.moveTo(x: 0, duration: 0.01)
        left_eye.run(SKAction.sequence([left,right,back]))
        right_eye.run(SKAction.sequence([right,left,back]))
    }
    
    func wiggle_head() {
        let rotate_left = SKAction.rotate(byAngle: .pi/10, duration: 0.05)
        let rotate_right = SKAction.rotate(byAngle: -.pi/10, duration: 0.05)
        let reset = SKAction.rotate(byAngle: 0, duration: 0.05)
        run(SKAction.sequence([rotate_left, rotate_right, reset]))
    }
    
    func laugh(){
        // Mouth up and head down
        // Head up mouth down
        // Head down mouth down
        // mouth up
        let basic_interval = 0.1
        let bob_unit = 10.0
        
        let mouth_up = SKAction.moveBy(x: 0, y: bob_unit, duration: basic_interval)
        let mouth_down = SKAction.moveBy(x:0, y:-bob_unit, duration: basic_interval)
        //let mouth_wair = SKAction.wait(forDuration: basic_interval)
        
        let head_up = SKAction.moveBy(x: 0, y: bob_unit, duration: basic_interval)
        let head_down = SKAction.moveBy(x:0, y:-bob_unit, duration: basic_interval)
        //let head_wait = SKAction.wait(forDuration: basic_interval)
        
        let eyes_up = SKAction.moveBy(x: 0, y: bob_unit/2, duration: basic_interval)
        let eyes_down = SKAction.moveBy(x: 0, y: -bob_unit/2, duration: basic_interval)
        
        
        let head_sequence = SKAction.sequence([head_down, head_up, head_up, head_down, head_down, head_up])
        let mouth_sequence = SKAction.sequence([mouth_up, mouth_up, mouth_down, mouth_up, mouth_down, mouth_down])
        let eyes_sequence = SKAction.sequence([eyes_down, eyes_up, eyes_up, eyes_down, eyes_down, eyes_up])
        
        body.run(SKAction.repeat(head_sequence, count:7))
        mouth.run(SKAction.repeat(mouth_sequence, count:7))
        left_eye.run(SKAction.repeat(eyes_sequence, count:7))
        right_eye.run(SKAction.repeat(eyes_sequence, count:7))
        lightbulb.run(SKAction.repeat(head_sequence, count:7))
        
        
        lightbulb.run(SKAction.repeat(SKAction.sequence([SKAction.animate(with: lightbulb_textures, timePerFrame: basic_interval/5), SKAction.animate(with: lightbulb_textures.reversed(), timePerFrame: basic_interval/5)]), count: 10))
    }
    
    private func setupIdleAnimation() {
        let blink = SKAction.run { [weak self] in self?.blink() }
        let pause = SKAction.wait(forDuration: 2.0, withRange: 1.0)
        let eyeDart = SKAction.run { [weak self] in self?.eye_dart_left_right() }
        let sequence = SKAction.sequence([pause, blink, pause, eyeDart])
        idle_action = SKAction.repeatForever(sequence)
        runIdle()
    }
   
    func look_at_point(_ point: CGPoint) {
        let dx = point.x - position.x
        let dy = point.y - position.y
        //let angle = atan2(dy, dx)
        
        // TODO: rotate the eyes towards the point?
        
    }
   
    func runIdle() {
        if let idle = idle_action {
            run(idle, withKey: "idle")
        }
    }
    
    func stopIdle() {
        removeAction(forKey: "idle")
    }
}

enum ExpressionPreset {
    case thinking, winning, losing, smug
}

