//
//  HUDLayer.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 5/31/25.
//

import SpriteKit
import Foundation


class StatusLabel:SKNode {
    
    private var label:SKLabelNode
    private let labels:[GameState:String] = [.ai_thinking: "🤖 Thinking...", .waiting_for_player: "🧠 Your Turn", .game_over(winner: .O): "🤖 AI Wins!", .game_over(winner: .X): "🏆 Human Wins!", .game_over(winner: .none): "😒 Draw!"]
    
    override init() {
        self.label = SKLabelNode(fontNamed: "Menlo")
        self.label.text = labels[.ai_playing]
        self.label.fontSize = 16
        self.label.fontColor = .white
        self.label.verticalAlignmentMode = .center
        self.label.horizontalAlignmentMode = .center
        
        super.init()
        self.position = position
        self.addChild(label)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func change_label(to state:GameState) {
        self.label.text = labels[state]
    }
}

class GameButton:SKSpriteNode {
    private let label:SKLabelNode
    
    init(text:String) {
        self.label = SKLabelNode(fontNamed: "Menlo-Bold")
        self.label.text = text
        self.label.fontSize = 24
        self.label.fontColor = .white
        self.label.verticalAlignmentMode = .center
        super.init(texture:nil, color: .darkGray, size: CGSize(width:160, height:64))
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

protocol HUDDelegate: AnyObject {
    func didTapNewGame()
    func didTapRematch()
    func didTapConcede()
}

class HUDLayer:SKNode {
    weak var delegate: HUDDelegate?
    
    let new_game_button = GameButton(text: "New Game")
    let rematch_button = GameButton(text: "Rematch")
    let concede_button = GameButton(text: "Concede")
    
    override init() {
        super.init()
        
        //new_game_button.name = "newGame"
       // rematch_button.name = "rematch"
        concede_button.name = "concede"

        //new_game_button.position = CGPoint(x: -160, y: 0)
        //rematch_button.position = CGPoint(x: 160, y: 0)
        concede_button.position = CGPoint(x: 0, y: 0)

        //addChild(new_game_button)
        //addChild(rematch_button)
        addChild(concede_button)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func handleTouch(at point: CGPoint) {
            for button in [new_game_button, rematch_button, concede_button] {
                if button.contains(convert(point, from: parent!)) {
                    button.highlight()
                    print("handling touch at \(button.name)")
                    switch button.name {
                    case "newGame": delegate?.didTapNewGame()
                    case "rematch": delegate?.didTapRematch()
                    case "concede": delegate?.didTapConcede()
                    default: break
                    }
                }
            }
        }
}

