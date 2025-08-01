//
//  GameScene.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 1/27/25.
//

import SpriteKit
import GameplayKit
import AVFoundation

enum GameState:Hashable {
    case waiting_for_player, ai_thinking, ai_playing, game_over(winner: Player?) // nil = draw
}

// TODO: [BUGS]
//
// 1. only rebuild board after concession
// 2. get rid of multiple touchdown
//

class GameScene: SKScene {
    private var game_log:GameLog!
    private var flavor_engine:FlavorEngine!
    private var hud_layer:HUDLayer!
    private var diodes:Diodes!
    private var door:Door?
    private let robot = RobotController()
    
    private var board:SKTileMapNode?
    private var stones:[Move : Stone?] = [:]
    private var current_player = Player.X // Player.X is human, Player.O is AI
    private var board_state:[[Player]] = Array(repeating: Array(repeating: Player.empty, count: BOARD_SIZE),  count:BOARD_SIZE)
    private var human_inactivity_timer:Timer? // To time taunts
    var human_can_place_stones:Bool = true // TODO: the most important bool in the whole game lol
    
    private var current_state:GameState = .waiting_for_player {
        didSet {
            // On state change:
            // 1. Update robot state
            updateRobotForState(current_state)
            
            // 2. Update diodes
            if case .waiting_for_player = current_state {
                diodes.change_state(to: current_state)
            } else if case .ai_thinking = current_state {
                diodes.change_state(to: current_state)
            }
            
            
            // 3. Update game and buttons
            switch current_state {
            case .waiting_for_player, .ai_playing, .ai_thinking :
                hud_layer.rematch_button.disabled = true
                let fade_out = SKAction.fadeAlpha(to: 0.0, duration: 0.3)
                hud_layer.rematch_button.run(fade_out)
                
                hud_layer.concede_button.disabled = false
                let fade_in = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                hud_layer.concede_button.run(fade_in)
                
            case .game_over( _):
                hud_layer.concede_button.disabled = true
                let fade_out = SKAction.fadeAlpha(to: 0.0, duration: 0.3)
                hud_layer.concede_button.run(fade_out)
                
                hud_layer.rematch_button.disabled = false
                let fade_in = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                hud_layer.rematch_button.run(fade_in)
            }
            
            // 4. Ensure that the board is unlocked if and only if.waiting_for_player?
            if current_state == .waiting_for_player {
                self.human_can_place_stones = true
            } else {
                self.human_can_place_stones = false
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
        // ---- BOARD BUILDING ----
        let dark_atlas = SKTextureAtlas(named: "dark")
        let dark_textures = dark_atlas.textureNames.sorted().map {dark_atlas.textureNamed($0}
        
        let light_atlas = SKTextureAtlas(named: "light")
        let light_textures = light_atlas.textureNames.sorted().map {light_atlas.textureNamed($0)}
        
        print("[Textures]: loaded light and dark tiles. ")
        
        for row in 0..<BOARD_SIZE {
            for col in 0..<BOARD_SIZE {
                
                let atlas = (col + row) % 2 == 0 ? light_atlas : dark_atlas
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
                tile.position.x += board!.position.x
                tile.position.y += board!.position.y
                tile.zPosition = 0
                addChild(tile)
            }
        }
        
        // --- GAME LOG ---
        game_log = GameLog(position: .zero)
        
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
        
        // --- FLAVOR ENGINE ---
        flavor_engine = FlavorEngine(game_log: game_log, robot: robot)
        flavor_engine.maybeSay(.opening, probability: 1.0)
        
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
        diodes = Diodes()
        diodes.position = CGPoint(x: 307, y: -360)
        addChild(diodes)
        diodes.zPosition = 10
        
        // --- DOOR ---
        let door_top = childNode(withName: "door_top") as! SKSpriteNode
        let door_bottom = childNode(withName: "door_bottom") as! SKSpriteNode
        let door_mask = childNode(withName: "door_mask") as! SKSpriteNode
        door = Door(top: door_top, bottom: door_bottom, mask: door_mask)
        door?.open()
    }
    
    
    func touchUp(atPoint pos : CGPoint)
    {
        // 1. Handle HUD
        if hud_layer.handleTouch(at: pos) { return }
        
        // 2. If you did not click HUD, check that the current state is .waiting_for_player
        guard current_state == .waiting_for_player else { return } // TODO: Early termination if you do not wait for player.
        
        // 3.
        let nodes_at_point = nodes(at: pos)
        for node in nodes_at_point {
            if node is Tile {
                let tile = node as! Tile
                
                // 1. Check if you clicked already full tile
                guard board_state[tile.coordinates.0][tile.coordinates.1] == .empty else {
                    game_log.addMessage( "🤖 There is a stone here already...")
                    return
                }
                
                // 2. Check if the board is active
                guard human_can_place_stones else { return }
                
                // 3. Resolve the player logic
                if current_player == Player.X {
                    
                    // Immediatelly disable the board clicks.
                    human_can_place_stones = false
                    human_inactivity_timer?.invalidate()
                    
                    // Places the stone.
                    let stone = Stone(size: tile.size, atlas: "blue")
                    stone.position = tile.position
                    stone.zPosition = 10
                    addChild(stone)
                    
                    // Update move and apply it to the board state
                    let move = Move(row: tile.coordinates.0, col: tile.coordinates.1)
                    board_state = applyMove(state: board_state, move: move, player: .X)
                    stones[move] = stone // Add stone
                    
                    game_log.addMessage("🧠 Plays (\(move.row), \(move.col))", style: .gray)
                    stone.setScale(1.5)
                    stone.run(SKAction.scale(to: 1.0, duration: 0.1)) { [self] in
                        
                    // Check for win condition
                    if let (_, streak) = checkWinCondition(state: board_state) {
                        for (row, col) in streak {
                            if let stone = stones[Move(row:row, col:col)] {
                                stone!.removeAllActions()
                                stone!.run(stone!.highlight_animation!)
                            }
                        }
                        flavor_engine.maybeSay(.human_wins, probability: 1.0)
                        stopHumanInactivityTaunts()
                        current_state = .game_over(winner: .X)
                        game_log.addMessage("🧠 Wins!", style: .gray)
                        return
                    }
                    
                    if checkDraw(state: board_state) {
                        flavor_engine.maybeSay(.stalemate, probability: 1.0)
                        stopHumanInactivityTaunts()
                        current_state = .game_over(winner: .none)
                        game_log.addMessage("🦐 Stalemate", style: .gray)
                        return
                    }
                        
                    // --------- AI -----------
                    // Switches the player
                    current_player = .O
                    
                    // Wait a little so it doesn't look like you think too fast
                    run(SKAction.wait(forDuration: 0.2))
                    current_state = .ai_thinking
                
                    if evaluateState(state: board_state, player: .O) < 0 {
                        flavor_engine.maybeSay(.taunt)
                    } else { // TODO: double check if this works
                        flavor_engine.maybeSay(.thinking)
                    }
                    
                    
                    // For consistency in multithreading
                    let snapshotBoard = board_state
                    let snapshotState = current_state
                    let aiQueue = DispatchQueue(label: "com.piskvor.ai", qos: .userInitiated)
                    
                    aiQueue.async { [weak self] in
                        guard let self = self else { return }
                        
                        // Early check — game already ended
                        guard case .ai_thinking = snapshotState else {
                            print("🛑 AI skipped: not in ai_thinking state")
                            return
                        }
                        
                        guard let move = findBestMove(state: snapshotBoard, player: .O) else {
                            print("⚠️ AI failed to find a move")
                            return }
                        
                        // Run this on the main thread
                        DispatchQueue.main.async {
                            [weak self] in
                            guard let self = self else { return }
                            
                            // Re-check current state before applying move
                            guard case .ai_thinking = self.current_state else {
                               print("🛑 Skipping stale AI callback. Current state: \(self.current_state)")
                               return
                            }
                            
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
                            
                            stone.setScale(1.5)
                            stone.run(SKAction.scale(to: 1.0, duration: 0.1)) {
                                // Check for win condition
                                if let (_, streak) = checkWinCondition(state: self.board_state) {
                                    // highlight the streak here
                                    
                                    for (row, col) in streak {
                                        if let stone = self.stones[Move(row:row, col:col)] {
                                            stone!.removeAllActions()
                                            stone!.run(stone!.highlight_animation!)
                                        }
                                    }
                                    self.flavor_engine.maybeSay(.ai_wins, probability: 1.0)
                                    self.stopHumanInactivityTaunts()
                                    self.current_state = .game_over(winner: .O)
                                    self.game_log.addMessage("🤖 Wins!", style: .gray)
                                } else if checkDraw(state: self.board_state) {
                                    self.flavor_engine.maybeSay(.stalemate, probability: 1.0)
                                    self.stopHumanInactivityTaunts()
                                    self.current_state = .game_over(winner: .none)
                                    self.game_log.addMessage("🦐 Stalemate", style: .gray)
                                } else {
                                    self.current_player = .X
                                    self.startHumanInactivityTimer()
                                    self.current_state = .waiting_for_player
                                    self.human_can_place_stones = true // Enable this only if there is no win or draw.
                                }
                            }
                        }
                        }
                    }
                }
            }
        }
    }
    
    func isGameOver(_ state: GameState) -> Bool {
        if case .game_over = state {
            return true
        }
        return false
    }
    
    func updateRobotForState(_ state:GameState) {
        robot.stopIdle()
        
        switch state {
        case .waiting_for_player:
            robot.setExpressionPreset(.smug)
            robot.runIdle()
        case .ai_thinking:
            robot.setExpressionPreset(.thinking)
        case .ai_playing:
            robot.setExpressionPreset(.smug)
        case .game_over(let winner):
            if winner == .O {
                robot.setExpressionPreset(.winning)
                robot.laugh()
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
    
    // Register touches up
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        self.touchUp(atPoint: location)
    }
}


extension GameScene: HUDDelegate {
    func didTapMute() {
        game_log.muted.toggle()
        
        if game_log.muted {
            hud_layer.mute_button.label.text = "UNMUTE"
        } else {
            hud_layer.mute_button.label.text = "MUTE"
        }
    }
    
    func didTapNewGame() {
        let restart_action = SKAction.run { [self] in
            
            game_log.addEmptyLine()
            game_log.addMessage("🧠 Started a new game.", style: .gray)
            
            let fade_out = SKAction.fadeAlpha(to: 0.0, duration: 0.3)
            hud_layer.new_game_button.run(fade_out)
            hud_layer.new_game_button.disabled = true
            
            self.door?.open{
                self.flavor_engine.maybeSay(.opening, probability: 1.0)
                self.current_player = .X
                self.current_state = .waiting_for_player
                self.hud_layer.reset()
                self.isUserInteractionEnabled = true
                self.human_can_place_stones = true
            }
        }
        
        run(restart_action)
    }

    func didTapRematch() {
        restartGame()
    }

    func restartGame() {
        diodes.reset()
        stopHumanInactivityTaunts()
        isUserInteractionEnabled = false
        
        human_can_place_stones = false
        self.hud_layer.reset()
        
        door?.close { [self] in
            
            // TODO: is this where the racing is?
            // If AI glitches, then it may make move after stones and board_state were emptied!
            stones.values.forEach { $0?.removeFromParent() }
            stones.removeAll()
            
            cleanAICaches() // Cleans AI caches so that the game does not replay
            
            board_state = Array(repeating: Array(repeating: Player.empty, count: BOARD_SIZE),  count:BOARD_SIZE)
            
            let wait_action = SKAction.sequence([SKAction.repeat(SKAction.sequence([SKAction.wait(forDuration: 0.5), SKAction.run {self.game_log.addEmptyLine()} ]), count: 5), SKAction.wait(forDuration: 0.5)])
            
            self.run(wait_action) { [self] in
                // Show [NEW GAME BUTTON on the door]
                let fade_in = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                hud_layer.new_game_button.run(fade_in)
                hud_layer.new_game_button.disabled = false
                
                
                print("new_game _button: fade in")
                isUserInteractionEnabled = true
            }
        }
    }

    
    func didTapConcede() {
        flavor_engine.maybeSay(.human_concedes, probability: 1.0)
        game_log.addMessage("🧠 Conceded", style: .gray)
        
        
        restartGame()
    }
}
