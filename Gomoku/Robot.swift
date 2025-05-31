//
//  Robot.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 5/27/25.
//

import Foundation
import SpriteKit

enum RobotState {
    case Idle, Thinking, Winning, Losing
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
        lightbulb_textures = Array(lightbulb_atlas.textureNames.map { lightbulb_atlas.textureNamed($0) })
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
        print("bouncing mouth")
        let up = SKAction.moveBy(x: 0, y: 20, duration: 0.15)
        let down = SKAction.moveBy(x: 0, y: -20, duration: 0.15)
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
    
    private func setupIdleAnimation() {
        let blink = SKAction.run { [weak self] in self?.blink() }
        let pause = SKAction.wait(forDuration: 2.0, withRange: 1.0)
        let eyeDart = SKAction.run { [weak self] in self?.eye_dart_left_right() }
        let sequence = SKAction.sequence([pause, blink, pause, eyeDart])
        idle_action = SKAction.repeatForever(sequence)
        runIdle()
    }
    
    func speak() {
        bounce_mouth()
    }
    
    func runIdle() {
        print("running idle")
        if let idle = idle_action {
            print("idle action still not nil")
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

