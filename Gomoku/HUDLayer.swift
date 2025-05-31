//
//  HUDLayer.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 5/31/25.
//

import SpriteKit
import Foundation

class GameButton:SKSpriteNode {
    private let label:SKLabelNode
    
    init(text:String) {
        self.label = SKLabelNode(fontNamed: "Menlo-Bold")
        self.label.text = text
        self.label.fontSize = 24
        self.label.fontColor = .white
        self.label.verticalAlignmentMode = .center
        super.init(texture:nil, color: .darkGray, size: CGSize(width:160, height:48))
        self.isUserInteractionEnabled = false // Why?
        self.addChild(label)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func highlight() {
        self.run(SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1),
        ]))
    }
}

class HUDLayer:SKNode {
    let new_game_button = GameButton(text: "New Game")
    let rematch_button = GameButton(text: "Rematch")
    let concede_button = GameButton(text: "Concede")
    
    override init() {
        super.init()
        
        new_game_button.name = "newGame"
        rematch_button.name = "rematch"
        concede_button.name = "concede"

        new_game_button.position = CGPoint(x: -160, y: 0)
        rematch_button.position = CGPoint(x: 0, y: 0)
        concede_button.position = CGPoint(x: 160, y: 0)

        addChild(new_game_button)
        addChild(rematch_button)
        addChild(concede_button)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

