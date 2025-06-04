//
//  GameScene.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 1/27/25.
//

import SpriteKit
import GameplayKit
import AVFoundation

class Stone:SKSpriteNode {
    // Places the stone
    
    var flash_textures:[SKTexture]
    var flash_animation:SKAction?
    
    var highlight_textures:[SKTexture]
    var highlight_animation:SKAction?
    
    init(size:CGSize, atlas:String) {
        let atlas = SKTextureAtlas(named: atlas)
        let textures = atlas.textureNames.sorted().map {atlas.textureNamed($0)}
        
        // Flash textures
        flash_textures = atlas.textureNames.filter {$0.contains("flash")}.sorted().map {atlas.textureNamed($0)}
        
        if Bool.random() {
            flash_textures.reverse()
        }
        
        if !flash_textures.isEmpty {
            let sequence = SKAction.sequence([SKAction.wait(forDuration: TimeInterval(Float.random(in: 4...8))), SKAction.animate(with: flash_textures, timePerFrame: 0.03)])
            flash_animation = SKAction.repeatForever(sequence)
        }
        
        // Highlight textutes
        highlight_textures = atlas.textureNames.filter {$0.contains("highlight")}.sorted().map {atlas.textureNamed($0)} // For some reason, the textures were reversed.
        
        if !highlight_textures.isEmpty {
            let sequence = SKAction.animate(with: highlight_textures.reversed(), timePerFrame: 0.01)
            let rev_sequence = SKAction.animate(with: highlight_textures, timePerFrame: 0.03)
            highlight_animation = SKAction.repeatForever(SKAction.sequence([sequence, SKAction.wait(forDuration: 0.1), rev_sequence, SKAction.wait(forDuration: 0.5)]))
        }
        
        super.init(texture: textures[0], color: .clear, size: size)
        zPosition = 10
        
        if flash_animation != nil {
            run(flash_animation!)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
}


class Tile:SKSpriteNode {
    public var coordinates:(Int, Int)
    
    
    init(texture:SKTexture? = nil, color:UIColor, size:CGSize, coordinates: (Int, Int)) {
        self.coordinates = coordinates
        super.init(texture: texture, color: color, size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum GameState:Hashable {
    case waiting_for_player, ai_thinking, ai_playing, game_over(winner: Player?) // nil = draw
}

class GameScene: SKScene {
    
    
    private var game_log:GameLog!
    private var flavor_engine:FlavorEngine!
    private var hud_layer:HUDLayer!
    private var status_label:StatusLabel!
    
    private var board:SKTileMapNode?
    private var stones:[Move : Stone?] = [:]
   //   private var animation_state_machine:AnimationStateMachine?
    private var current_player = Player.X
    private var board_state:[[Player]] = Array(repeating: Array(repeating: Player.empty, count: BOARD_SIZE),  count:BOARD_SIZE)
    
    let robot = RobotController()
    private var human_inactivity_timer:Timer?
    
    private var current_state:GameState = .waiting_for_player {
        didSet {
            updateRobotForState(current_state)
            status_label.change_state(to: current_state)
            
            if case .game_over = current_state {
                
                print("Game over state")
                hud_layer.concede_button.disabled = true
                let fade_out = SKAction.fadeAlpha(to: 0.0, duration: 0.3)
                hud_layer.concede_button.run(fade_out)
                
                hud_layer.rematch_button.disabled = false
                let fade_in = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                hud_layer.rematch_button.run(fade_in)
                
            } else
            {
                hud_layer.rematch_button.disabled = true
                let fade_out = SKAction.fadeAlpha(to: 0.0, duration: 0.3)
                hud_layer.rematch_button.run(fade_out)
                
                hud_layer.concede_button.disabled = false
                let fade_in = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                hud_layer.concede_button.run(fade_in)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        // Build the game board
        super.init(coder: aDecoder)
        
        board = (self.childNode(withName: "board") as! SKTileMapNode)
        // animation_state_machine = AnimationStateMachine(scene:self)
    }

    
    override func didMove(to view: SKView)
    {
        // ---- BOARD ----
        // Add tiles. TODO: do this on the tilemap directly.
        for row in 0..<BOARD_SIZE {
            for col in 0..<BOARD_SIZE {
                
                var texture_atlas_name = "light"
                
                // TODO: correct this
                if (col + row) % 2 == 0 {
                   texture_atlas_name = "dark"
                }
                
                let atlas = SKTextureAtlas(named: texture_atlas_name)
                let random_texture:SKTexture
                let textures = atlas.textureNames.sorted().map {atlas.textureNamed($0)}
                
                if Float.random(in: 0..<1) > 0.95 {
                    random_texture = textures[1...].randomElement()!
                } else {
                    random_texture = textures[0]
                }
                
                let tile:Tile = Tile(texture: random_texture,
                                     color: .clear,
                                     size: board!.tileSize,
                                     coordinates: (row, col))
                tile.position = board!.centerOfTile(atColumn: col, row: row)
                
                // TODO: clean up
                tile.position.x += board!.position.x
                tile.position.y += board!.position.y
                tile.zPosition = 0
                addChild(tile)
            }
        }
        
        // --- GAME LOG ---
        game_log = GameLog(position: .zero)//GameLog(position: CGPoint(x: -338, y: -417))
        
        if let maskGuide = childNode(withName: "crop_node") as? SKSpriteNode {
            let crop_node = SKCropNode()
            crop_node.position = maskGuide.position
            crop_node.zPosition = maskGuide.zPosition
            
            let mask = SKSpriteNode(color:.white, size: maskGuide.size)
            mask.position = CGPoint.zero
            mask.anchorPoint = maskGuide.anchorPoint
            crop_node.maskNode = mask
            
            maskGuide.removeFromParent()
            
            crop_node.addChild(game_log.getNode())
            addChild(crop_node)
            
        } else {
            addChild(game_log.getNode())
        }
        
        game_log.getRandomLog(.opening)
        flavor_engine = FlavorEngine(game_log: game_log, robot: robot)
        
        
        // --- ROBOT ---
        robot.position = CGPoint(x: 0, y: 540)
        robot.setScale(0.5)
        addChild(robot)
    
        // --- HUD ---
        hud_layer = HUDLayer()
        hud_layer.position = CGPoint(x: 0, y: -630)
        addChild(hud_layer)
        hud_layer.delegate = self
        
        
        // --- STATUS LABEL --
        status_label = StatusLabel()
        status_label.position = CGPoint(x: 330, y: -360)
        addChild(status_label)
        status_label.zPosition = 10
        
    }
    
    func touchDown(atPoint pos : CGPoint) {
        
        let nodes_at_point = nodes(at: pos)
        
        for node in nodes_at_point {
            if node is Tile {
                let tile = node as! Tile
                
                
                // Check if I am clicking on an empty tile. If not, pass.
                if board_state[tile.coordinates.0][tile.coordinates.1] != .empty{
                    game_log.addMessage( "🤖 There is a stone here already...")
                    break
                }
                
                // Resolve the player logic
                if current_player == Player.X {
                    // Cancel human inactivity timer
                    human_inactivity_timer?.invalidate()
                    
                    // Places the stone
                    var stone = Stone(size: tile.size, atlas: "blue")
                    stone.position = tile.position
                    stone.zPosition = 10
                    addChild(stone)
                    
                    var move = Move(row: tile.coordinates.0, col: tile.coordinates.1)
                    board_state = applyMove(state: board_state, move: move, player: .X)
                    stones[move] = stone // Add stone
                    
                    game_log.addMessage("🧠 Plays (\(move.row), \(move.col))", style: .gray)
                    
                    // Check for win condition
                    if let (winner, streak) = checkWinCondition(state: board_state) {
                        print("winner \(winner)")
                        // highlight the streak here
                        
                        for (row, col) in streak {
                            if let stone = stones[Move(row:row, col:col)] {
                                print("found the stone at \(row),\(col)")
                                stone!.removeAllActions()
                                stone!.run(stone!.highlight_animation!)
                            }
                        }
                        game_log.getRandomLog(.human_wins)
                        stopHumanInactivityTaunts()
                        current_state = .game_over(winner: .X)
                        break
                    }
                    
                    if checkDraw(state: board_state) {
                        game_log.getRandomLog(.stalemate)
                        stopHumanInactivityTaunts()
                        current_state = .game_over(winner: .none)
                        break
                    }
                    
                   
                    
                    // --------- AI -----------
                    // Switches the player
                    current_player = .O
                    
                    // If AI is winning, taunt
                    if evaluateState(state: board_state, player: .O) < 0 {
                        flavor_engine.maybeSay(.taunt)
                    }
                    
                    current_state = .ai_thinking
                    flavor_engine.maybeSay(.thinking)
                    
                    isUserInteractionEnabled = false
                    DispatchQueue.global(qos: .userInitiated).async { [self] in
                        guard let move = findBestMove(state: board_state, player: .O) else { return }
                        
                  
                        DispatchQueue.main.async {
                            [self] in
                            print("Suggested move: \(move)")
                    
                            
                            // Pack this into a function
                            let stone = Stone(size: tile.size, atlas: "red")
                            stone.position = board!.centerOfTile(atColumn: move.col, row: move.row)
                            stone.position.x += board!.position.x
                            stone.position.y += board!.position.y
                            stone.zPosition = 10
                            addChild(stone)
                            
                            board_state = applyMove(state: board_state, move: move, player: .O)
                            stones[move] = stone // Add stone
                            
                            current_state = .ai_playing
                            game_log.addMessage("🤖 Plays (\(move.row), \(move.col))", style: .gray)
                            
                            
                            // Check for win condition
                            if let (winner, streak) = checkWinCondition(state: board_state) {
                                print("winner \(winner). Running highlight animation")
                                // highlight the streak here
                                
                                for (row, col) in streak {
                                    if let stone = stones[Move(row:row, col:col)] {
                                        print("found the stone at \(row),\(col)")
                                        stone!.removeAllActions()
                                        stone!.run(stone!.highlight_animation!)
                                    }
                                }
                                game_log.getRandomLog(.ai_wins)
                                stopHumanInactivityTaunts()
                                current_state = .game_over(winner: .O)
                            } else if checkDraw(state: board_state) {
                                game_log.getRandomLog(.stalemate)
                                stopHumanInactivityTaunts()
                                current_state = .game_over(winner: .none)
                            } else {
                                current_player = .X
                                startHumanInactivityTimer()
                                current_state = .waiting_for_player
                            }
                            
                            isUserInteractionEnabled = true
                        }
                    }
                }
            }
        }
    }
    
    func updateRobotForState(_ state:GameState) {
        print("Updating robot for state: \(state)")
        robot.stopIdle()
        
        switch state {
        case .waiting_for_player:
            robot.setExpressionPreset(.smug)
            robot.runIdle()
        case .ai_thinking:
            robot.setExpressionPreset(.thinking)
        case .ai_playing:
            robot.setExpressionPreset(.smug)
            robot.bounce_mouth()
            
        case .game_over(let winner):
            if winner == .O {
                robot.setExpressionPreset(.winning)
                robot.wiggle_head()
            } else if winner == .X {
                robot.setExpressionPreset(.losing)
            } else {
                robot.setExpressionPreset(.thinking)
            }
        
        }
    }
    
    func startHumanInactivityTimer()
    {
        human_inactivity_timer?.invalidate() // Cancel existing
        human_inactivity_timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in self?.flavor_engine.maybeSay(.interject, probability: 0.6) }
        
    }
    
    func stopHumanInactivityTaunts() {
        human_inactivity_timer?.invalidate()
    }
    
    
    func touchMoved(toPoint pos : CGPoint) {
        
    }
    
    func touchUp(atPoint pos : CGPoint) {
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchDown(atPoint: t.location(in: self)) }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        hud_layer.handleTouch(at: location)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}


extension GameScene: HUDDelegate {
    func didTapNewGame() {
        restartGame()
    }

    func didTapRematch() {
        restartGame()
    }

    func restartGame() {
        stones.values.forEach { $0?.removeFromParent() }
        stones.removeAll()
        
        board_state = Array(repeating: Array(repeating: Player.empty, count: BOARD_SIZE),  count:BOARD_SIZE)
        status_label.reset()
        
        isUserInteractionEnabled = false
        
        SKAction.
       
        game_log.addMessage("------------------------------------------------------", style: .gray)
        game_log.addMessage("🧠 Started a new game.", style: .gray)
        
        SKAction.wait(forDuration: 1.0)
        flavor_engine.maybeSay(.opening, probability: 1.0)
        
        current_player = .X
        current_state = .waiting_for_player
        
        hud_layer.reset()
        
       
    }

    func didTapConcede() {
        game_log.addMessage("🧠 Conceded...", style: .gray)
        game_log.getRandomLog(.human_concedes)
        
        restartGame()
    }
}
