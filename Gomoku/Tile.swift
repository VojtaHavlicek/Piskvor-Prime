//
//  Tile.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 6/25/25.
//

import SpriteKit

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
