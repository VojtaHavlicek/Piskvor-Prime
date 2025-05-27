//
//  GameScene.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 1/27/25.
//

import SpriteKit
import GameplayKit

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
        
        print("highlight textures: \(highlight_textures)")
        
        if !highlight_textures.isEmpty {
            let sequence = SKAction.animate(with: highlight_textures.reversed(), timePerFrame: 0.03)
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


class GameScene: SKScene {
    
    private var board:SKTileMapNode?
    private var stones:[Move : Stone?] = [:]
   //   private var animation_state_machine:AnimationStateMachine?
    private var current_player = Player.X
    private var board_state:[[Player]] = Array(repeating: Array(repeating: Player.empty, count: BOARD_SIZE),  count:BOARD_SIZE)
    
    required init?(coder aDecoder: NSCoder) {
        // Build the game board
        super.init(coder: aDecoder)
        
        board = (self.childNode(withName: "board") as! SKTileMapNode)
        // animation_state_machine = AnimationStateMachine(scene:self)
    }
    
    override func didMove(to view: SKView)
    {
       
        
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
    }
    
    func touchDown(atPoint pos : CGPoint) {
        
        let nodes_at_point = nodes(at: pos)
        
        for node in nodes_at_point {
            if node is Tile {
                let tile = node as! Tile
                
                
                // Check if I am clicking on an empty tile. If not, pass.
                if board_state[tile.coordinates.0][tile.coordinates.1] != .empty{
                    print("Placed already")
                    break
                }
                
                // Resolve the player logic
                if current_player == Player.X {
                    
                    // Places the stone
                    var stone = Stone(size: tile.size, atlas: "blue")
                    stone.position = tile.position
                    stone.zPosition = 10
                    addChild(stone)
                    
                    var move = Move(row: tile.coordinates.0, col: tile.coordinates.1)
                    board_state = applyMove(state: board_state, move: move, player: .X)
                    stones[move] = stone // Add stone
                    
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
                        
                        break
                    }
                    
                    if checkDraw(state: board_state) {
                        print("Draw!")
                        break
                    }
                    
                    
                    // --------- AI -----------
                    // Switches the player
                    current_player = .O
                    
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
                            } else if checkDraw(state: board_state) {
                                print("Draw !")
                            } else {
                                current_player = .X
                            }
                            
                            isUserInteractionEnabled = true
                        }
                    }
                }
            }
        }
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
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}
