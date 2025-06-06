//
//  Door.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 6/5/25.
//

import SpriteKit
import GameplayKit
import AVFoundation

enum InscriptionType: String, Codable {
    case devQuote
    case corruptedLog
    case unknownGraffiti
    case piskvorWhisper
}

struct InscriptionAnimation: Codable {
    let type: String
    let delayPerLine: Double
}

struct Inscription: Codable {
    let type:InscriptionType
    let metadata:String
    let text:String
    let author:String?
    let rarity: Float
    let animation: InscriptionAnimation?
}

class InscriptionLoader {
    static func load() -> [Inscription] {
        guard let url = Bundle.main.url(forResource: "inscriptions", withExtension: "json") else {
            print("Could not find inscriptions.json")
            return[]
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Inscription].self, from: data)
            return decoded
        } catch {
            print(" Error loading inscriptions.json")
            return []
        }
    }
}

class InscriptionManager {
    private var inscriptions:[Inscription] = []
    
    init() {
        inscriptions = InscriptionLoader.load()
        print("[Inscriptions]: Loaded \(inscriptions.count) inscriptions")
        print("[Inscriptions]: First: \(inscriptions[0].text)")
    }
    
    func randomInscription(rarityThreshold: Float = 1.0) -> Inscription? {
        let filtered = inscriptions.filter { $0.rarity <= rarityThreshold }
        return filtered.randomElement()
    }
}



class Door {
    private var is_open:Bool = false // TODO: Switch on completion
    private var top:SKSpriteNode
    var bottom:SKSpriteNode
    
 
    
    private let inscription_manager:InscriptionManager!

    
    init(top:SKSpriteNode, bottom:SKSpriteNode, mask:SKSpriteNode) {
        // Prepare door
        let crop_node = SKCropNode()
        crop_node.position = mask.position
        mask.position = .zero
        crop_node.maskNode = mask
        crop_node.zPosition = mask.zPosition
        
        let ref = top.parent!
        
        top.removeFromParent()
        bottom.removeFromParent()
        
        mask.removeFromParent()
        
        top.position = CGPoint(x: 0, y: top.size.height/2)
        bottom.position = CGPoint(x:0, y: -bottom.size.height/2)
        
        crop_node.addChild(top)
        crop_node.addChild(bottom)
        
        self.top = top
        self.bottom = bottom
        
        ref.addChild(crop_node)
        
        // Prep easter eggs
        let easter_egg_atlas:SKTextureAtlas = SKTextureAtlas(named: "easter_eggs")
        easter_egg_textures = Array(easter_egg_atlas.textureNames.map { easter_egg_atlas.textureNamed($0) })
        
        // Insription Manager
        inscription_manager = InscriptionManager()
    }
    
    
    func open(completion: (() -> Void)? = nil) {
        // Remove easter egg
        if let egg = easter_egg {
            egg.removeFromParent()
            easter_egg = nil
        }
        
        if let last = last_inscription {
            last.removeFromParent()
            last_inscription = nil
        }
        
        top.run(SKAction.sequence([SKAction.moveBy(x: 0, y: top.size.height, duration: 0.5), SKAction.run {
            self.is_open = true
            completion?()
        }]))
        bottom.run(SKAction.moveBy(x: 0, y: -bottom.size.height, duration: 0.5))
    }

    func close(completion: (() -> Void)? = nil) {
        plant_easter_egg(rarityThreshold: 0.9)
        display_inscription(rarityThreshold: Float.random(in: 0.11...1.0))
        
        top.run(SKAction.sequence([SKAction.moveBy(x: 0, y: -top.size.height, duration: 0.5), SKAction.run {
            self.is_open = false
            completion?()
        }]))
        bottom.run(SKAction.moveBy(x: 0, y: bottom.size.height, duration: 0.5))
    }
    
    private var last_inscription:SKNode?
    
    func display_inscription(rarityThreshold:Float = 0.0)
    {
        
        guard let ins = inscription_manager.randomInscription(rarityThreshold: rarityThreshold) else
        {
            print("[Inscription Engine]: Getting a random inscription, but found none")
            return
        }
        
        print(ins)
        print("[Inscription Engine]: adding a random inscription")
        /*let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = "\(ins.metadata) - \(ins.text) - \(ins.author ?? "Unknown")"
        label.fontSize = 24
        label.fontColor = .white
        label.preferredMaxLayoutWidth = 100
        
        label.position = .zero
        label.zPosition = bottom.zPosition + 1
        label.scene?.anchorPoint = CGPoint(x: 0.5, y: 0.5)*/
        
        let node:SKNode = SKNode()
        
        
        let log: String = "\(ins.metadata):"
        let (log_label, _) = renderMultiline(text: log, fontSize: 24, color: .white, maxWidth: 350, justify: .right)
        log_label.position = CGPoint(x:-100/bottom.xScale, y:0)
        log_label.zPosition = bottom.zPosition + 1
        log_label.scene?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        log_label.xScale = 1/bottom.xScale
        log_label.yScale = 1/bottom.yScale
        
        node.addChild(log_label)
        
        let quote:String = "\(ins.text)"
        let (label, num_lines):(SKNode, Int) = renderMultiline(text: quote, fontSize: 24, color: .white, maxWidth: 350)
        
        label.position = CGPoint(x:-80/bottom.xScale, y:0)
        label.zPosition = bottom.zPosition + 1
        label.scene?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        label.xScale = 1/bottom.xScale
        label.yScale = 1/bottom.yScale
        
        node.addChild(label)
        
        let label_height = label.calculateAccumulatedFrame().height
        
        print("Label bounds: \(label.bounds), label frame: \(label.frame), label height: \(label_height)")
        
        let author:String = "-- \(ins.author ?? "Unknown")"
        let (author_label, _) = renderMultiline(text: author, fontSize: 24, color: .white, maxWidth: 350, justify: .right)
        author_label.position = CGPoint(x:200/bottom.xScale, y:-(CGFloat(num_lines+1)*(24+4))/bottom.yScale)
        author_label.zPosition = bottom.zPosition + 1
        
        author_label.xScale = 1/bottom.xScale
        author_label.yScale = 1/bottom.yScale
        
        node.addChild(author_label)
        node.position = CGPoint(x: 10/bottom.xScale, y: 80/bottom.yScale)
        node.alpha = 0.75
        
        bottom.addChild(node)
        
        self.last_inscription = node
    }
    
    func renderMultiline(text: String, fontSize: CGFloat = 24, color: SKColor = .white, maxWidth: CGFloat = 600, justify: SKLabelHorizontalAlignmentMode = .left) -> (SKNode, Int) {
        let container = SKNode()
        let words = text.split(separator: " ")
        
        var lines: [String] = []
        var currentLine = ""
        
        let testLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        testLabel.fontSize = fontSize
        
        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : "\(currentLine) \(word)"
            testLabel.text = testLine
            
            if testLabel.frame.width > maxWidth {
                lines.append(currentLine)
                currentLine = String(word)
            } else {
                currentLine = testLine
            }
        }
        lines.append(currentLine)
        
        for (i, line) in lines.enumerated() {
            let label = SKLabelNode(fontNamed: "Menlo-Bold")
            label.text = line
            label.fontSize = fontSize
            label.fontColor = color
            label.horizontalAlignmentMode = justify
            label.position = CGPoint(x: 0, y: CGFloat(-i) * (fontSize + 4))
            label.alpha = 0.75
            container.addChild(label)
        }
        
        return (container, lines.count)
    }

    
    
    private var easter_egg_textures:[SKTexture] = []
    private var easter_egg:SKSpriteNode?
    
    func plant_easter_egg(rarityThreshold: Float = 0.9) {
        if Float.random(in: 0..<1) > rarityThreshold {
            // How to add this to the top texture?
            let overlay_size = top.frame.size
            let egg_texture = easter_egg_textures.randomElement()!
            let egg = SKSpriteNode(texture: egg_texture, size: overlay_size)
            egg.position = .zero
            egg.zPosition = top.zPosition + 1
            egg.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            
            // Waht the HACK
            egg.xScale = 1/top.xScale
            egg.yScale = 1/top.yScale
            
            top.addChild(egg)
            self.easter_egg = egg
            
            print("Planted solid red egg. Size: \(egg.size), top frame: \(top.frame.size)")
        }
    }
}
