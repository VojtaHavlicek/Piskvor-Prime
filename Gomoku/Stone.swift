//
//  Stone.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 6/25/25.
//

import SpriteKit

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
