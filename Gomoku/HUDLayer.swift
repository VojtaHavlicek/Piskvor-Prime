//
//  HUDLayer.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 5/31/25.
//

import SpriteKit
import Foundation

enum DiodeType:String {
    case red, blue
}

class Diode:SKSpriteNode {
    
    let diode_on:SKAction
    let diode_off:SKAction
    var type:DiodeType
    
    var state:Bool = false
    
    
    init(diode_type:DiodeType) {
        type = diode_type
        
        var atlas_name:String? = nil
        if type == .red {
            atlas_name = "red_diode"
        } else if type == .blue {
            atlas_name = "blue_diode"
        }
        
        let diode_atlas = SKTextureAtlas(named: atlas_name!)
        let textures:[SKTexture] = diode_atlas.textureNames.sorted().compactMap { diode_atlas.textureNamed($0) }
       
        
        diode_on = SKAction.animate(with: textures, timePerFrame: 0.05)
        diode_off = SKAction.animate(with: textures.reversed(), timePerFrame: 0.05)
        
        super.init(texture: textures[0], color: .clear, size: textures[0].size())
        
        if state {
            run(diode_on)
        } else {
            run(diode_off)
        }
        
        setScale(0.413)
    }
    
    func blink() {
        removeAllActions()
        let blink_action = SKAction.repeatForever(SKAction.sequence([diode_on, diode_off]))
        run(blink_action)
    }
    
    func toggle() {
        if state {
            run(diode_off)
        } else {
            run(diode_on)
        }
        state.toggle()
    }
    
    func set_state(state:Bool) {
        self.state = state
        if state {
            run(diode_on)
        } else {
            run(diode_off)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("not implemented")
    }
}

class StatusLabel:SKNode {
    let blue:Diode
    let red:Diode
    
    override init() {
        red = Diode(diode_type: .red)
        blue = Diode(diode_type: .blue)
        
        red.position = CGPoint(x:-red.size.width/2, y:-red.size.width/2)
        blue.position = CGPoint(x:blue.size.width/2, y:-blue.size.width/2)
        
        red.zPosition = 20
        blue.zPosition = 20
    
        super.init()
        
        addChild(red)
        addChild(blue)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reset() {
        red.removeAllActions()
        blue.removeAllActions()
        
        red.set_state(state: false)
        blue.set_state(state: false)
    }
    
    func change_state(to state:GameState) {
        switch state {
        case .ai_thinking:
            red.set_state(state: true)
            blue.set_state(state: false)
        case .ai_playing:
            red.set_state(state: false)
            blue.set_state(state: false)
        case .waiting_for_player:
            red.set_state(state: false)
            blue.set_state(state: true)
        case .game_over(winner: .O):
            red.blink()
            blue.set_state(state: false)
        case .game_over(winner: .X):
            blue.blink()
            red.set_state(state: false)
        case .game_over(winner: .none), .game_over(winner: .some(.empty)):
            blue.set_state(state: false)
            red.set_state(state: false)
        }
        
    }
}

class GameButton:SKSpriteNode {
    public let label:SKLabelNode
    public var disabled:Bool = true
    
    init(text:String) {
        self.label = SKLabelNode(fontNamed: "Menlo-Bold")
        self.label.text = text
        self.label.fontSize = 24
        self.label.fontColor = .white
        self.label.verticalAlignmentMode = .center
        super.init(texture:nil, color: .clear, size: CGSize(width:160, height:48))
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
    func didTapMute()
}

class HUDLayer:SKNode {
    weak var delegate: HUDDelegate?
    
    let mute_button = GameButton(text: "🔊")
    let new_game_button = GameButton(text: "New Game")
    let rematch_button = GameButton(text: "REMATCH")
    let concede_button = GameButton(text: "CONCEDE")
    
    override init() {
        super.init()
        
        //new_game_button.name = "newGame"
        rematch_button.name = "rematch"
        concede_button.name = "concede"
        mute_button.name = "mute"

        //new_game_button.position = CGPoint(x: -160, y: 0)
        rematch_button.position = CGPoint(x: 0, y: 0)
        rematch_button.alpha = 0.0
        
        concede_button.position = CGPoint(x: 0, y: 0)
        concede_button.alpha = 0.0

        
        mute_button.position = CGPoint(x:320, y:0)
        mute_button.disabled = false
        
        addChild(mute_button)
        //addChild(new_game_button)
        addChild(rematch_button)
        addChild(concede_button)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reset() {
        let fade_out:SKAction = SKAction.fadeOut(withDuration: 0.3)
        
        concede_button.run(fade_out)
        rematch_button.run(fade_out)
        
        concede_button.disabled = true
        rematch_button.disabled = true
        
    }
    
    func handleTouch(at point: CGPoint) {
            for button in [new_game_button, rematch_button, concede_button, mute_button] {
                if button.contains(convert(point, from: parent!)) {
                    print("\(button.name) clicked and disabled? : \(button.disabled)")
                    if !button.disabled {
                        button.highlight()
                        print("handling touch at \(button.name)")
                        switch button.name {
                        case "newGame": delegate?.didTapNewGame()
                        case "rematch": delegate?.didTapRematch()
                        case "concede": delegate?.didTapConcede()
                        case "mute": delegate?.didTapMute()
                        default: break
                        }
                    }
                }
            }
        }
}

