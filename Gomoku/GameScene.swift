//
//  GameScene.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 1/27/25.
//

import SpriteKit
import GameplayKit

enum GameState:String
{
    case Playing, Win, Draw
}

var game_state:GameState = .Playing


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
                
                var texture_name = "light"
                
                
                // TODO: correct this
                if (col + row*(BOARD_SIZE-1)) % 2 == 0 {
                   texture_name = "dark"
                }
                
                let tile:Tile = Tile(texture: SKTexture(imageNamed: texture_name),
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
                    var stone = SKSpriteNode(texture: SKTexture(imageNamed: "blue"), size: CGSize(width: tile.size.width, height: tile.size.width))
                    stone.position = tile.position
                    stone.zPosition = 10
                    addChild(stone)
                    
                    var move = Move(row: tile.coordinates.0, col: tile.coordinates.1)
                    board_state = applyMove(state: board_state, move: move, player: .X)
                    
                    // Check for win condition
                    if let (winner, streak) = checkWinCondition(state: board_state) {
                        print("winner \(winner)")
                        // highlight the streak here
                        
                        for (row, col) in streak {
                            
                            let dot:SKSpriteNode = SKSpriteNode(color: .yellow, size: CGSize(width: 10, height: 10) )
                            dot.position = board!.centerOfTile(atColumn: col, row: row)
                            dot.isUserInteractionEnabled = false
                            addChild(dot)
                            
                        }
                    }
                    
                    if checkDraw(state: board_state) {
                        print("Draw!")
                    }
                    
                    
                    // --------- AI -----------
                    // Switches the player
                    current_player = .O
                    
                    // Run AI
                    move = findBestMove(state: board_state, player: .O)!
                    print("Suggested move: \(move)")
                    
                    // Pack this into a function
                    stone = SKSpriteNode(texture: SKTexture(imageNamed: "red"), size: CGSize(width: tile.size.width, height: tile.size.width))
                    stone.position = board!.centerOfTile(atColumn: move.col, row: move.row)
                    stone.position.x += board!.position.x
                    stone.position.y += board!.position.y
                    stone.zPosition = 10
                    addChild(stone)
                    
                    board_state = applyMove(state: board_state, move: move, player: .O)
                    
                    // Check for win condition
                    if let (winner, streak) = checkWinCondition(state: board_state) {
                        print("winner \(winner)")
                        // highlight the streak here
                        
                        for (row, col) in streak {
                            
                            let dot:SKSpriteNode = SKSpriteNode(color: .yellow, size: CGSize(width: 10, height: 10) )
                            dot.position = board!.centerOfTile(atColumn: col, row: row)
                            dot.position.x += board!.position.x
                            dot.position.y += board!.position.y
                            dot.isUserInteractionEnabled = false
                            dot.zPosition = 12
                            addChild(dot)
                            
                            
                            
                        }
                    }
                    
                    if checkDraw(state: board_state) {
                        print("Draw !")
                    }
                    
                    // Switch the player
                    current_player = .X
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
