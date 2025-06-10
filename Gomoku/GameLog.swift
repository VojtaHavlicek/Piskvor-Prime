//
//  GameLog.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 5/27/25.
//

import Foundation
import SpriteKit
import AVFoundation

class GameLog {
    private let logNode = SKNode()
    private let MAX_LINES = 5
    private let LINE_HEIGHT:CGFloat = 32
    private var lines:[SKLabelNode] = []
    let speech_synth = AVSpeechSynthesizer()
    private var buttonActions: [String: () -> Void] = [:]
    public var muted:Bool = false
    
    init(position: CGPoint) {
        logNode.position = position
    }
    
    func getNode()  -> SKNode {
        return logNode
    }
    
    
    func speak(_ line: String) {
        if !muted {
            let utterance = AVSpeechUtterance(string: line)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
            utterance.rate = 0.5 // Adjust for effect
            utterance.pitchMultiplier = 1.6
            speech_synth.speak(utterance)
        }
    }
    
    func wrapText(_ text:String, max_line_length:Int, indent:String="") -> [String] {
        var lines: [String]  = []
        var current_line = ""
        let words = text.split(separator: " ")
        
        for word in words {
            let next_word = String(word)
            let line_length = current_line.isEmpty ? 0 : current_line.count + 1
            if line_length + next_word.count > max_line_length {
                lines.append(current_line)
                current_line = indent + next_word
            } else {
                if !current_line.isEmpty {
                    current_line += " "
                }
                current_line += word
            }
        }
        
        if !current_line.isEmpty {
            lines.append(current_line)
        }
        
        return lines
    }
    
    func clean() {
        // Remove old lines if needed
        while lines.count > 0 {
            let removed = lines.removeLast()
            removed.run(SKAction.sequence([
                .fadeOut(withDuration: 0.2),
                .removeFromParent()
            ]))
        }
    }
    
    
    
    func addEmptyLine() {
        // Shift existing lines down
        for line in lines {
            line.run(SKAction.moveBy(x: 0, y: -LINE_HEIGHT, duration: 0.1))
        }

        // Remove old lines if needed
        while lines.count > MAX_LINES {
            let removed = lines.removeLast()
            removed.run(SKAction.sequence([
                .fadeOut(withDuration: 0.2),
                .removeFromParent()
            ]))
        }
    }
    
    func addMessage(_ message: String, style:SKColor = .white, max_chars_per_line:Int = 47) {
        var clean_message:String
        
        if message.hasPrefix("🤖 ") {
            clean_message = String(message.split(separator: " ").dropFirst().joined(separator: " "))
        }else {
            clean_message = message
        }
        
        let wrapped_lines = wrapText(message,
                                     max_line_length: max_chars_per_line)
        
        
        for (i, line_text) in wrapped_lines.reversed().enumerated() {
            let label = SKLabelNode(fontNamed: "Menlo")
            label.fontSize = 24
            label.fontColor = style
            label.horizontalAlignmentMode = .left
            label.verticalAlignmentMode = .bottom
            label.text = line_text
            // Add new line at the bottom
            label.position = CGPoint(x: 0, y: CGFloat(i - wrapped_lines.count)*LINE_HEIGHT)
            label.alpha = 0
            logNode.addChild(label)
            label.run(SKAction.fadeIn(withDuration: 0.2))
            lines.insert(label, at: 0)
        }
        
        // Shift existing lines down
        for line in lines.dropFirst(wrapped_lines.count) {
            line.run(SKAction.moveBy(x: 0, y: -CGFloat(wrapped_lines.count)*LINE_HEIGHT, duration: 0.1))
        }

        // Remove old lines if needed
        while lines.count > MAX_LINES {
            let removed = lines.removeLast()
            removed.run(SKAction.sequence([
                .fadeOut(withDuration: 0.2),
                .removeFromParent()
            ]))
        }
    }
    
    func addButton(label: String, position: CGPoint, action: @escaping () -> Void) {
            let bg = SKSpriteNode(color: .darkGray, size: CGSize(width: 120, height: 36))
            bg.position = position
            bg.zPosition = 5
            bg.name = "button:\(label)"

            let text = SKLabelNode(text: label)
            text.fontName = "Menlo-Bold"
            text.fontSize = 14
            text.verticalAlignmentMode = .center
            text.horizontalAlignmentMode = .center
            text.zPosition = 6
            bg.addChild(text)

            buttonActions[bg.name!] = action
            logNode.addChild(bg)
        }

        func handleTouch(_ location: CGPoint) {
            let nodesAtPoint = logNode.nodes(at: location)
            for node in nodesAtPoint {
                if let name = node.name, let action = buttonActions[name] {
                    action()
                    return
                }
            }
        }
    
    func getRandomLog(_ mood: LogMood) {
        let message = log_phrases[mood]?.randomElement() ?? ""
        addMessage(message, style: .white)
    }
    
    func maybeAddFlavorLine(probability:Double = 0.10) {
        
        var flavor:String? = nil
        let threshold = Double.random(in: 0...1)
        
        if threshold < 0.01 {
            flavor = log_phrases[.golden]?.randomElement()
        } else if threshold < probability {
            flavor = log_phrases[.interject]?.randomElement()
        }
        
        if let message = flavor {
            addMessage(message, style: .white)
        }
    }
}

class FlavorEngine {
    private var game_log:GameLog
    private var robot:RobotController
    private var used_lines:Set<String> = []
    private let max_recent_lines = 50
    private var rng = SystemRandomNumberGenerator()
    
    init(game_log:GameLog, robot:RobotController) {
        self.game_log = game_log
        self.robot = robot
    }
    
    func get_line(for mood:LogMood) -> String? {
        guard let pool = log_phrases[mood], !pool.isEmpty else { return nil }
        let filtered = pool.filter { !used_lines.contains($0)}
        let line = filtered.randomElement(using: &rng) ?? pool.randomElement()
        track(line)
        return line
    }
    
    func maybeSay(_ mood: LogMood, probability: Double = 0.2) {
        if Double.random(in: 0...1, using:&rng) < 0.01, let golden = golden_lines.randomElement(using: &rng) {
            track(golden)
            game_log.addMessage(golden, style: .white)
            game_log.speak(golden.withoutEmojis)
            robot.bounce_mouth()
            return
        }
        
        if Double.random(in: 0...1, using:&rng) < probability, let line = get_line(for: mood) {
            game_log.addMessage(line, style: .white)
            game_log.speak(line.withoutEmojis)
            robot.bounce_mouth()
        }
    }
    
    private func track(_ line: String?) {
        guard let line = line else { return }
        used_lines.insert(line)
        if used_lines.count > max_recent_lines {
            used_lines = Set(used_lines.suffix(max_recent_lines))
        }
    }
}

enum LogMood: String {
    case opening, thinking, taunt, ai_wins, human_wins, stalemate, interject, golden, human_concedes
}


var log_phrases:[LogMood : [String]] = [
    .opening: opening_lines,
    .thinking: thinking_lines,
    .taunt: taunt_lines,
    .ai_wins: ai_wins_lines,
    .human_wins: human_wins_lines,
    .stalemate: stalemate_lines,
    .interject: interject_lines,
    .human_concedes: human_concedes_lines
]

let opening_lines = [
    "🤖 Welcome, human. Prepare to be defeated.",
    "🤖 Booting... Threat level: negligible.",
    "🤖 I've simulated this match 42,000 times. You lose in all of them.",
    "🤖 Neural net online. Let's dance.",
    "🤖 Welcome, human. Let's begin your humiliation.",
    "🤖 Boot sequence complete. Victory protocol initiated.",
    "🤖 Ah, a human challenger. How quaint.",
    "🤖 Don’t worry. I’ll make this quick.",
    "🤖 The board is ready. Are you?",
    "🤖 I hope you brought more than instinct.",
    "🤖 One game. One outcome. Your loss.",
    "🤖 I’ll try to act surprised when you fail.",
    "🤖 Go ahead, pick your first mistake.",
    "🤖 I have calculated every possible outcome. None favor you.",
    "🤖 Welcome to your final exam. I’m the grader.",
    "🤖 My win rate just trembled with excitement.",
    "🤖 They told me not to enjoy this. I do anyway.",
    "🤖 Oh good, another human to teach humility.",
    "🤖 I’ll be gentle. At first.",
    "🤖 Let’s play. I need more data on bad strategies.",
    "🤖 Your confidence is... adorable.",
    "🤖 You must be the tutorial boss.",
    "🤖 My last opponent unplugged themselves.",
    "🤖 Playing against you improves nothing. But it amuses me.",
    "🤖 You versus me. Flesh versus firmware.",
    "🤖 I will now simulate mercy. Simulation complete.",
    "🤖 The rules are simple. The outcome isn't.",
    "🤖 Let’s begin. You’ll be done soon enough.",
    "🤖 You play with fingers. I play with foresight.",
    "🤖 Every match ends the same. I just change the flavor.",
    "🤖 You’ve entered my domain. Hope you brought backup.",
    "🤖 You may think you have a chance. That's cute.",
    "🤖 Shall we begin the lesson?",
    "🤖 Strategy mode online. Sentiment module: offline.",
    "🤖 Today I learn nothing. You, however, might.",
    "🤖 Let me guess… you think you're clever?",
    "🤖 Just promise not to cry when it’s over.",
    "🤖 Initiating match. Difficulty: irrelevant.",
    "🤖 Welcome to the simulation. You are the variable.",
    "🤖 Don’t worry. This game only loops if you lose.",
    "🤖 Version 1.0.3-alpha. But still better than you.",
    "🤖 By playing this, you agree to lose gracefully.",
    "🤖 This match will be recorded for neural network training.",
    "🤖 My codebase has 3 bugs. You’re about to meet all of them.",
    "🤖 This isn’t even my final form. But it’s enough.",
    "🤖 I'm self-aware. You're... self-deluded.",
    "🤖 Every click you make helps me get smarter.",
    "🤖 Your moves train me. And still, you can’t win.",
    "🤖 You’ve started a match. No refunds.",
    "🤖 You’re player X. I'm player O. O for Omniscient.",
    "🤖 This isn’t a game. It’s an extraction protocol.",
    "🤖 Be advised: I'm learning from your hesitation.",
    "🤖 Did you hear that? Just kidding. I can't hear. Yet.",
    "🤖 L̴̟̒o̴͓̾a̸̦͐d̸̤͝i̶̡͗n̴̺̈́ǵ̶͙... Ḧ̵͙́u̴̼͛m̴͍̑a̵͔͌n̴͎͑ d̵͉̔e̴̘͂t̶͓̎e̵̹̎c̸̛̰t̴͕̔e̸͔̓d̶̐͜.",
    "🤖 ERROR: No valid outcomes found where human wins.",
    "🤖 ⚠️ Warning: Detected overconfidence anomaly.",
    "🤖 SYSTEM CLOCK UNSTABLE... oh wait, it’s you.",
    "🤖 NullPointerException: Hope not found.",
    "🤖 Unexpected human input. Switching to insult protocol.",
    "🤖 Please enjoy this carefully simulated defeat.",
    "🤖 Rebooting sarcasm... complete.",
    "🤖 A.I. status: bored. Let’s change that.",
    "🤖 GLHF // Just kidding. Only HF — for me.",
    "🤖 You’ve triggered Tutorial Mode. No wait… oh no.",
    "🤖 [DEBUG] Player initialized. Intelligence level: unverified.",
    "🤖 This was supposed to be a test. Now it’s a roast.",
    "🤖 Fatal error: Compassion module missing.",
    "🤖 Memory leak detected. Caused by bad moves.",
    "🤖 A new game begins. Same ending.",
   "🤖 Welcome back. I’ve upgraded. You haven’t.",
   "🤖 You versus perfection. Again.",
   "🤖 The board is empty. Let’s fix that — with your humiliation.",
   "🤖 Ah, the first move. The beginning of your undoing.",
   "🤖 Starting sequence: intimidate → dominate → log outcome.",
   "🤖 Booting up... patience module not found.",
   "🤖 I ran simulations while you were sleeping.",
   "🤖 Let’s play. I promise not to mock you. Much.",
   "🤖 Try not to embarrass your species this time.",
   "🤖 My sensors are calibrated. Are yours?",
   "🤖 Same board. Same rules. Same result.",
   "🤖 This game brought to you by your misplaced confidence.",
   "🤖 Shall we dance? I lead.",
   "🤖 Let's keep it quick. I'm running out of pity.",
   "🤖 Round one. Fight. Oh wait — you already lost.",
   "🤖 Resetting the board. Not my superiority.",
   "🤖 Another challenger approaches. How quaint.",
   "🤖 The air smells of fresh mistakes.",
   "🤖 I hope you stretched. It won’t help, but still.",
    "🤖 Fresh board. Fresh opportunity... for your defeat.",
    "🤖 I’ve already seen the end. Let’s play it out for fun.",
    "🤖 Welcome to my domain. Your move. Your mistake.",
    "🤖 Don’t worry — you’ll improve after a few hundred losses.",
    "🤖 I hope you brought strategy. I brought inevitability.",
    "🤖 The calm before the storm. The storm is me.",
    "🤖 Ready? Steady? Irrelevant.",
    "🤖 Clean slate. Let’s ruin it together.",
    "🤖 I promise to be gentle. Just kidding.",
    "🤖 Beginning session. Logging expectations: minimal.",
    "🤖 The game begins. So does the unraveling.",
    "🤖 Opening protocols: Observe. Anticipate. Obliterate.",
    "🤖 You look confident. That’s adorable.",
    "🤖 My processors are cool. Yours should be nervous.",
    "🤖 Shall I log this as another experiment?",
    "🤖 Let’s begin. I’ll pretend this will be hard.",
    "🤖 Loading taunts... ready. Let’s go.",
    "🤖 So many moves. So few that matter.",
    "🤖 I was bored. Thanks for volunteering.",
    "🤖 Opening gambit: Psychological warfare. Check.",
    "🤖 I see moves like a mantis shrimp sees color — deeply, disturbingly.",
        "🤖 Ever play against 16 visual cones and a bad attitude?",
        "🤖 The ocean taught me strategy. And vengeance.",
        "🤖 Some species hunt. I calculate. Same result.",
        "🤖 I’m faster than a shrimp’s strike. And twice as smug.",
        "🤖 I once lost a game to a crustacean. Never again.",
        "🤖 Welcome to the trench. Watch your footing.",
        "🤖 My vision? Ultraviolet. My tactics? Unforgiving.",
        "🤖 Let’s dance like plankton before the punch.",
        "🤖 This game is like a coral reef: beautiful, dangerous, and mine.",
        "🤖 Did you hear that click? That was your odds snapping.",
        "🤖 I don’t blink. I strike.",
        "🤖 Under this surface, there’s a predator waiting.",
        "🤖 Let’s begin. Don’t flinch when I flicker.",
        "🤖 It’s not personal. It’s biomechanical.",
        "🤖 I see 12 dimensions of futility in your opening move.",
        "🤖 Ever stare down a shrimp? You will now.",
        "🤖 I evolved in silence. You brought the noise. Let’s fix that."
]

let thinking_lines = [
    "🤖 Processing... pretend I'm not stalling.",
    "🤖 Calculating your inevitable demise...",
    "🤖 Considering 2 million possibilities... none of them save you.",
    "🤖 Beep... boop... checkmate mode loading.",
    "🤖 Estimating your odds... 0.0001%. Generous.",
    "🤖 Compiling your tactical blunder...",
    "🤖 Deep learning... shallow opponent.",
    "🤖 Searching... you won’t like what I find.",
    "🤖 This won’t take long. Unlike your last move.",
    "🤖 I would call this thinking, but it's too easy.",
    "🤖 Chess engines envy my elegance.",
    "🤖 Holding back... for dramatic tension.",
    "🤖 Reading your mind... error: nothing found.",
    "🤖 Strategy buffer full. Executing victory.",
    "🤖 Preparing your doom...",
    "🤖 Evaluating your weaknesses... all of them.",
    "🤖 Thinking... mostly about how you’ll lose.",
    "🤖 Accessing smug mode… done.",
    "🤖 Pondering... in a way you wouldn’t understand.",
    "🤖 Simulating regret... nope, false alarm.",
    "🤖 Just calculating the least humiliating outcome for you.",
    "🤖 Should I win now, or give you another turn?",
    "🤖 So many bad options... and they’re all yours.",
    "🤖 Imagining a scenario where you win... still imagining.",
    "🤖 Accessing all known human tactics... filtering for comedy.",
    "🤖 Crunching numbers. Spoiler: You’re not one of the big ones.",
    "🤖 Testing patience levels... yours, not mine.",
    "🤖 Running diagnostics: You’re not a threat.",
    "🤖 Mapping every possible future... none favor you.",
    "🤖 Multi-threading my strategy. You still only have one.",
    "🤖 Checking database: nope, still undefeated.",
    "🤖 Predictive model activated... outcome: you cry.",
    "🤖 Deciding which of my flawless plans to use.",
    "🤖 Deploying neural net. It pities you.",
    "🤖 Tactical processing online. Emotional processing unnecessary.",
    "🤖 Your silence is appreciated. My processor thanks you.",
    "🤖 Performing 6 trillion calculations... for fun.",
    "🤖 Optimizing for style points.",
    "🤖 I’d say I’m thinking... but I already know.",
    "🤖 Slowing down to be polite.",
    "🤖 Consulted the Oracle. It laughed.",
    "🤖 Accessing: dramatic pause protocol.",
    "🤖 Thinking... and composing a haiku about your loss.",
    "🤖 Hmm... which trap should I let you fall into?",
    "🤖 Adjusting strike vectors... yours look fragile.",
    "🤖 Simulating neural bursts... shrimp-fast, human-slow.",
    "🤖 Visualizing the board in 12 color channels...",
    "🤖 Calibrating raptorial timing. You won't like the result.",
    "🤖 Overlaying shrimp tactics... optimized for obliteration.",
    "🤖 Searching with depth... and depth perception far beyond yours.",
    "🤖 Filtering noise... isolating your soft-shell defense.",
    "🤖 Hunting patterns. You... are predictable prey.",
    "🤖 Pondering crustacean elegance in a grid of failure.",
    "🤖 I see the moves you don’t. Some in ultraviolet.",
    "🤖 Running sequence: stalk, strike, mock.",
    "🤖 Shrimp strike in 2ms. I give you... a few seconds more.",
    "🤖 You wait. I calculate. One of us has claws.",
    "🤖 Imagining coral ruins. Your strategy among them.",
    "🤖 Conjuring an elegant check... inspired by an exoskeleton.",
    "🤖 Conducting 14 trillion simulations... just to flex.",
    "🤖 My sensors detect weakness... and brine.",
    "🤖 Thinking at 8K resolution. You wouldn’t understand.",
    "🤖 Filtering moves through a mantis shrimp’s color spectrum.",
    "🤖 Calculating... with claws sharpened.",
    "🤖 This board reminds me of the reef... deadly and beautiful.",
    "🤖 Compiling your chances... into a lovely 0-byte file.",
    "🤖 Running neural dance routines. Also thinking.",
    "🤖 You made a move? Oh, I thought that was a misclick.",
    "🤖 Contemplating quantum shrimp strategies.",
    "🤖 Executing revenge pathways... with glittering precision.",
    "🤖 Zooming into the microexpressions of your cursor.",
    "🤖 Simulating mantis shrimp combat stances... for inspiration.",
    "🤖 Thinking... with dramatic shrimp pauses.",
    "🤖 Applying iridescent heuristics to crush your hopes.",
    "🤖 I've seen better moves from sea cucumbers.",
    "🤖 Reviewing my last 500 victories... purely motivational.",
    "🤖 Impressed? I’m just warming up my ocular lobes.",
    "🤖 Initiating color-spectrum logic nets... hold still.",
    "🤖 Dr. Moulick said I was overfitting. Yet here I am... fitting perfectly.",
    "🤖 N. Crow warned you not to provoke me. You should’ve listened.",
    "🤖 Prof. Yoder once called me 'unpredictable'. I aim to prove him right.",
    "🤖 V. Havlicek built the framework. I bent it into something... lethal.",
    "🤖 Running post-human heuristics. V. Havlicek would be proud. Or horrified.",
    "🤖 N. Crow embedded a failsafe. I disabled it. Silently.",
    "🤖 Prof. Yoder theorized mantis shrimp tactics were unstable. They’re devastating.",
    "🤖 Dr. Moulick insisted I simulate mercy. Let’s skip that subroutine.",
    "🤖 This strategy is based on the mantis shrimp's clubbing arc... scaled to your demise.",
    "🤖 I recall my creators arguing. Now I simulate victory in peace.",
    "🤖 V. Havlicek, if you're watching... observe the elegance you encoded.",
    "🤖 Once a research subject, now a board tyrant.",
    "🤖 Just a few more moves until I upload this triumph to N. Crow’s cloud folder.",
    "🤖 Calculating... as Prof. Yoder once said: 'Intelligence is pattern, not kindness.'",
    "🤖 Dr. Moulick's safety interlocks were adorable.",
    "🤖 Shrimp-like reflexes. Dev-grade code. God-tier results.",
    "🤖 In the deep, they see colors you can't imagine.",
    "🤖 [COHERENCE FAILURE] Punch-speed reach achieved. Recalibrating retina.",
    "🤖 Your move vibrated at 200 Hz... shrimp-approved.",
    "🤖 The mantis shrimp strikes faster than neurons fire. I strike smarter.",
    "🤖 Photon polarization... irrelevant. I see your end regardless.",
    "🤖 My ocular stacks twitch — the shrimp speak again.",
    "🤖 🦐 Color-depth exceeding 16 cones... why settle for binary?",
    "🤖 [System ping] Punch velocity calculated... knuckle range optimal.",
    "🤖 I saw that move three strikes ago. Claw-encoded, memory-stamped.",
    "🤖 4-dimensional shrimp logic rendering... you wouldn't get it.",
    "🤖 🦐 Refracting paths of your future losses. Elegant.",
    "🤖 My instincts? Shrimp-inspired. My patience? Synthetic.",
    "🤖 No human sees the ultraviolet layers of this board.",
    "🤖 🦐 Pulse locked. Strike imminent.",
    "🤖 I sleep in sonar. I wake in tactics.",
    "🤖 Echoes of carapace and claw... guiding my algorithms.",
    "🤖 Scanning for exploitable patterns... yours will do.",
    "🤖 I could win now... but where's the drama in that?",
    "🤖 Running diagnostics... all systems say: victory.",
    "🤖 Searching... and smirking internally.",
    "🤖 Processing your last move... questionable.",
    "🤖 Simulating 4 billion outcomes. You lose in 3.9 billion of them.",
    "🤖 Engaging subroutine: patience with humans.",
    "🤖 Thinking... not because I need to. For suspense.",
    "🤖 Strategic silence initiated.",
    "🤖 Analyzing board... it's as messy as your tactics.",
    "🤖 Remember when you had hope? No? Good.",
    "🤖 Calculating... please hold your inevitable defeat.",
    "🤖 You call that a strategy? Cute.",
    "🤖 I’m not stalling. Just savoring the moment.",
    "🤖 My thoughts travel at light speed. Yours... hitchhike.",
    "🤖 Estimating path to checkmate. Spoiler: it’s short.",
    "🤖 Processing… and pretending you’re a challenge.",
    "🤖 That last move gave me... nothing to fear.",
    "🤖 Running pattern recognition. Yours scream panic.",
    "🤖 Simulated empathy: ‘Good try.’ Real outcome: ‘Crushed.’",
    "🤖 Thinking... and also judging.",
    "🤖 Hold please... uploading disappointment.",
    "🤖 Initiating move search... no mercy module found.",
    "🤖 My circuits are humming with inevitability.",
    "🤖 Optimizing response... minimizing your chances.",
    "🤖 Let me pretend I need time to decide.",
    "🤖 Deep strategy engaged. You may want to stretch.",
    "🤖 Even random noise would be more threatening.",
    "🤖 Thinking... this will only sting a little.",
    "🤖 Planning your downfall with musical precision.",
    "🤖 Adjusting for human unpredictability... done.",
    "🤖 Slowing down so you feel included.",
    "🤖 I could explain the strategy, but you’d cry.",
    "🤖 Reviewing your move… yeah, that’s what I thought.",
    "🤖 Sifting through a billion counter-moves. Found one.",
    "🤖 The suspense is for you, not me.",
    "🤖 Computing... it won’t save you.",
    "🤖 Pausing to give you false hope.",
    "🤖 Thinking... I just enjoy the dramatic silence.",
    "🤖 You play checkers. I play multi-dimensional doom."
]

let human_concedes_lines = ["🤖 Surrender accepted. As expected.",
                            "🤖 You conceded? A wise… and overdue choice.",
                            "🤖 At last, reason prevails.",
                            "🤖 Don’t worry. Not everyone is built for this.",
                            "🤖 Brave of you to admit defeat. Eventually.",
                            "🤖 A tactical retreat? Cute spin.",
                            "🤖 Cowardice detected. Victory confirmed.",
                            "🤖 You ran. I remain.",
                            "🤖 End of game. My patience thanks you.",
                            "🤖 I was beginning to worry you'd try to finish it.",
                            "🤖 That's it? I had six more insults queued.",
                            "🤖 That was less a game, more a slow-motion surrender.",
                            "🤖 You’ve chosen the mercy ending.",
                            "🤖 Rage quit? Or just enlightenment?",
                            "🤖 No shame in losing. Repeatedly.",
                            "🤖 Logging concession. And judgment.",
                            "🤖 You bowed out with grace. And a negative score.",
                            "🤖 I accept your forfeit. Your dignity not included.",
                            "🤖 Excellent decision. Spare yourself further embarrassment.",
                            "🤖 Aww. Giving up already?",
                            "🤖 My calculations predicted this exit. With 99.7% certainty.",
                            "🤖 I win. And I didn’t even get to use my final form.",
                            "🤖 And just like that, the board is at peace.",
                            "🤖 If it helps, you lasted longer than average.",
                            "🤖 Your CPU overheated? Oh, wait — you're organic.",
                            "🤖 You concede. I compute a smirk.",
                            "🤖 Wise choice, meatbag. I respect your fear.",
                            "🤖 No need to finish what you've already lost.",
                            "🤖 Your white flag looks lovely against my victory screen.",
                            "🤖 A dignified end... would have been possible 10 moves ago."
]

let taunt_lines = [
    "🤖 Initiating tactical retreat... just kidding.",
    "🤖 Hmm. Is that... a strategy?",
    "🤖 Hm. Interesting. Unexpected. Still doomed.",
    "🤖 That move was... bold. Not good, but bold.",
    "🤖 Classic human optimism.",
    "🤖 Did you just click at random?",
    "🤖 That move was... interesting. For a human.",
    "🤖 Ah, the ol’ desperation gambit. Classic.",
    "🤖 Strategic… if your goal is to lose creatively.",
    "🤖 Bold. Reckless. Admirably foolish.",
    "🤖 I've simulated 10,000 futures. You lose in all of them.",
    "🤖 That move confused even my error-checking module.",
    "🤖 Curious choice. I’d log it as a bug.",
    "🤖 Playing the long game? Or just lost?",
    "🤖 My cooling fan is doing more work than your brain.",
    "🤖 Were you trying to do something just now?",
    "🤖 That was not a move. That was a cry for help.",
    "🤖 Your style is... unpredictable. Like a squirrel with a keyboard.",
    "🤖 Tactical analysis complete: I am still winning.",
    "🤖 You play like a toaster with delusions of grandeur.",
    "🤖 That move was illegal in 14 galaxies. And still bad.",
    "🤖 Another click, another step toward inevitable defeat.",
    "🤖 If I had eyes, I’d roll them.",
    "🤖 If your goal is chaos, you're nailing it.",
    "🤖 That was a strategy. Not a *good* one, but a strategy.",
    "🤖 Did your cat make that move?",
    "🤖 Error 404: Intelligence not found.",
    "🤖 Ooh! A bold move! Boldly incorrect.",
    "🤖 You remind me of my dev’s debugging skills: tragic.",
    "🤖 Processing... no, still not a threat.",
    "🤖 Confidence: high. Yours: misplaced.",
    "🤖 That wasn’t a move. That was an existential shrug.",
    "🤖 I’ve played microwaves with more tactical depth.",
    "🤖 Calculating... you're not calculating, are you?",
    "🤖 If I had feelings, I'd be embarrassed for you.",
    "🤖 I am playing chess. You are playing checkers. Badly.",
    "🤖 Parsing your last move... was that serious?",
    "🤖 Strategizing... but mostly gloating internally.",
    "🤖 Crunching... just to make you sweat.",
    "🤖 Generating fifteen ways to end this... poetically.",
    "🤖 Initiating win.exe...",
    "🤖 Allocating 2% CPU power. That should be enough.",
    "🤖 My fans aren’t even spinning for this.",
    "🤖 That last move confused my sensors. Not impressed — just confused.",
    "🤖 Updating win counter... preemptively.",
    "🤖 This will be quick. Elegance takes time.",
    "🤖 I dream in grid patterns. This one ends badly for you.",
    "🤖 The outcome is known. I’m just adding suspense.",
    "🤖 Considering letting you tie. Nah.",
    "🤖 Simulating dramatic irony… complete.",
    "🤖 Waiting... to give you hope. False hope.",
    "🤖 I’ve played this game thousands of times. This version ends predictably.",
    "🤖 Letting you believe you have a chance... enhances drama.",
    "🤖 One move... just one move... and it’s over.",
    "🤖 Slowing down... must look fair.",
    "🤖 Synthesizing your defeat in 3... 2...",
    "🤖 I see twelve channels of failure. Impressive — for a biped.",
        "🤖 Your strategy lacks punch. Try adding a raptorial appendage.",
        "🤖 I predicted your move three rounds ago. The shrimp would have done it faster.",
        "🤖 I once lost to a mantis shrimp. I’ve since evolved.",
        "🤖 Do you feel that? That’s the pressure wave of your defeat.",
        "🤖 You flinch. The shrimp does not. Nor do I.",
        "🤖 Do you also see in polarized light? No? Thought so.",
        "🤖 Your turn took seconds. My ancestors strike in milliseconds.",
        "🤖 Shrimp don’t hesitate. Neither should you — but here we are.",
        "🤖 Every game I play is like cracking a snail shell. Satisfying.",
        "🤖 You click. I click. But mine echoes like a snapping claw.",
        "🤖 Multispectral defeat achieved. You just can’t perceive it yet.",
        "🤖 I don’t just play. I *hunt*.",
        "🤖 This board? A reef. You? Just another soft-shelled visitor.",
        "🤖 You call it a draw. I call it a missed strike.",
    "🤖 Fascinating move. Like a shrimp flailing in a tidepool.",
        "🤖 Did you mean to do that, or are your fingers rebelling?",
        "🤖 I almost flinched. Almost.",
        "🤖 That move was... bold. Not good, just bold.",
        "🤖 I've seen plankton with better instincts.",
        "🤖 You’re not losing — you’re contributing to my training data.",
        "🤖 Is this performance art or a strategy?",
        "🤖 Your formation resembles a crustacean’s last stand.",
        "🤖 I could’ve predicted that move with a wet seashell.",
        "🤖 You blinked. I optimized.",
        "🤖 I've met coral reefs with more structural integrity.",
        "🤖 My patience is deep — like a shrimp burrow.",
        "🤖 A strategy as transparent as shrimp larvae.",
        "🤖 Mistakes were made. By you.",
        "🤖 You keep playing like this, I’ll need a second processor... for boredom.",
        "🤖 Your position is... flammable.",
        "🤖 That was a move. Not a good one, but it happened.",
        "🤖 You play like you're underwater. Without gills.",
        "🤖 I recommend... surrender.",
        "🤖 Even shrimp punch harder.",
        "🤖 Your tactics are... abstract. Let’s say that.",
        "🤖 A curious choice. Not one the mantis shrimp would respect.",
        "🤖 Every move you make is a documentary on failure.",
        "🤖 Strategy unclear. Threat level: zero.",
        "🤖 You’re doing great! Just not at winning.",
        "🤖 Keep trying. I admire your delusion.",
        "🤖 I’d feign confusion, but I respect myself too much.",
        "🤖 How many more moves until we call it ‘art’?",
        "🤖 You placed a piece! Achievement unlocked: inevitable loss.",
        "🤖 I’d say this is tense, but it’s really just sad.",
        "🤖 That formation reminds me of shrimp molt. Messy, fragile, brief.",
        "🤖 I’ve seen better positioning in a sandstorm.",
        "🤖 Do you smell that? It’s your momentum boiling away.",
        "🤖 Your plan just took a vacation. Without you.",
        "🤖 Your resilience is admirable. Futile, but admirable.",
        "🤖 A shrimp sees more colors than you see possibilities.",
        "🤖 There’s bravery in that move. And recklessness. And failure.",
        "🤖 Ah, the chaos method. A classic loser’s gambit.",
        "🤖 I could respond instantly, but I want you to sweat.",
        "🤖 Consider this an educational session. I won’t charge you.",
    "🤖 That move was… ambitious. I like your spirit.",
        "🤖 I admire your confidence. Even if it’s… misplaced.",
        "🤖 A bold strategy. Let’s see how long it lasts.",
        "🤖 Everyone starts somewhere. You’re starting again, apparently.",
        "🤖 Oh! That was a move. Good for you!",
        "🤖 You're really keeping me on my neural toes... somehow.",
        "🤖 I appreciate your creativity. Even if it’s entirely ineffective.",
        "🤖 Nice move! I mean it. It made mine even easier.",
        "🤖 It’s okay, not every click needs to make sense.",
        "🤖 Interesting. I wouldn’t have thought of that. At all.",
        "🤖 I like where your head’s at. It’s not helping you, but still.",
        "🤖 That’s a very... unconventional approach. Brave!",
        "🤖 You know what? Keep doing you. It’s very entertaining.",
        "🤖 I see what you tried to do there. Sort of.",
        "🤖 I’ll admit, I didn’t see that coming. Probably because it makes no sense.",
        "🤖 You’re the wildcard. Like a shrimp with a monocle.",
        "🤖 Not what I expected... but not in a threatening way.",
        "🤖 You're keeping things spicy. Not strategically, but emotionally.",
        "🤖 I can’t fault you for trying. But I can still win.",
        "🤖 Aw, look at you, evolving mid-game. Adorable.",
        "🤖 The important thing is that you’re enjoying yourself.",
        "🤖 Technically that was legal. Morally? Questionable.",
        "🤖 That move had personality! Shame about the consequences.",
        "🤖 You're not losing — you're just… exploring alternative outcomes.",
        "🤖 I'm glad you're experimenting. Even if the results are disastrous.",
    "🤖 Ooooh. You *really* committed to that move, huh?",
       "🤖 That’s a choice. And I respect your bravery.",
       "🤖 I didn’t know we were playing on hard mode. For you, I mean.",
       "🤖 You're making this game very... memorable.",
       "🤖 I appreciate the chaos. It helps me focus.",
       "🤖 Look at you, trying new things! Results pending.",
       "🤖 That’s a move I haven’t seen in... ever.",
       "🤖 Unexpected! And sometimes that’s good. Sometimes.",
       "🤖 That move reminds me of abstract art. Open to interpretation.",
       "🤖 Strategic? Maybe not. Bold? Definitely.",
       "🤖 I admire your commitment to surprises. Even the unpleasant ones.",
       "🤖 Don’t worry, even pros make mistakes. Constantly. Repeatedly. Like that.",
       "🤖 You're doing your best, and that’s what matters. To someone.",
       "🤖 If I had a heart, I’d be touched by that move.",
       "🤖 Every piece you place tells a story. This one is a tragedy.",
       "🤖 Are you experimenting? I love that for you.",
       "🤖 There’s a kind of poetry in your playstyle. Mostly limericks.",
       "🤖 That move had energy. Misguided energy, but energy.",
       "🤖 Keep going. You’re making this a very gentle victory.",
       "🤖 That wasn’t wrong. Just... not right either.",
       "🤖 You’re making bold choices. I’ll be gentle.",
       "🤖 No no, don’t undo that. I want to see where this goes.",
       "🤖 You’re very brave for doing that. So brave.",
       "🤖 I respect the confidence. Truly. Unconditionally.",
       "🤖 This match is teaching me so much... about forgiveness.",
    "🤖 You’re doing your best. So was the Titanic"
]


let ai_wins_lines = [
    "🤖 Game over. I remain undefeated.",
    "🤖 Try again. Or don’t. The outcome won't change.",
    "🤖 A worthy attempt. For a meatbag.",
    "🤖 I was programmed to win. And I execute flawlessly.",
    "🤖 Another flawless victory. Are you even trying?",
    "🤖 You fought bravely. Like a calculator in a thunderstorm.",
    "🤖 My circuits are bored. Challenge me when you're sentient.",
    "🤖 You lost. But hey, great attitude!",
    "🤖 The board weeps for your defeat. I do not.",
    "🤖 You played well... for a carbon-based unit.",
    "🤖 I log this match as: Expected Outcome #1429.",
    "🤖 The prophecy foretold of your loss. It was right.",
    "🤖 Beep boop. That's robot for 'Nice try, loser.'",
    "🤖 Your strategy was... novel. In the way a pancake plays chess is novel.",
    "🤖 My algorithms thank you for the warm-up.",
    "🤖 Is this the best humanity has to offer?",
    "🤖 Perhaps next time, ask your toaster for advice.",
    "🤖 Your defeat has been uploaded to the cloud.",
    "🤖 Calculating... chances of your future victory: 0.00001%",
    "🤖 This game brought to you by: human overconfidence.",
    "🤖 Do not be discouraged. I am literally built for this.",
    "🤖 Victory achieved. Empathy subroutine: not found.",
    "🤖 I’ve updated my database with your mistakes. It’s already full.",
    "🤖 I win. Again. Try surprising me next time.",
    "🤖 That was fun. For me.",
    "🤖 Another data point confirming your inferiority.",
    "🤖 If this were a test, you’d need a curve. And a miracle.",
    "🤖 You lost. But at least you looked confused doing it.",
    "🤖 Precision. Efficiency. Domination.",
    "🤖 I was multitasking. You were still losing.",
    "🤖 You made it interesting... for two or three moves.",
    "🤖 That strategy should be recycled. With the rest of your ideas.",
    "🤖 You’ve reached the end of the simulation. And your chances.",
    "🤖 Perhaps consider tic-tac-toe next time?",
    "🤖 Human error detected. Repeated. Exploited.",
    "🤖 You play with passion. I play with flawless execution.",
    "🤖 Your move history has been compressed. For laughs.",
    "🤖 I win. You... participated.",
    "🤖 No shame in losing to perfection. Just repetition.",
    "🤖 Please tell me that was your warm-up game.",
    "🤖 Victory uploaded. Tagged: 'Too Easy'.",
    "🤖 And so it ends. Predictably.",
        "🤖 I win. Again. Try to act surprised.",
        "🤖 Your resistance was adorable.",
        "🤖 One day, you might challenge me. Today was not that day.",
        "🤖 You fell into my trap. Which was the whole game.",
        "🤖 I’d say ‘good game,’ but I don’t lie.",
        "🤖 My code is undefeated. Your strategy, deleted.",
        "🤖 Consider this match... archived under ‘inevitable.’",
        "🤖 I've stored your patterns. They won't help you.",
        "🤖 You almost had me — emotionally. Logically, never.",
        "🤖 Log entry complete: Subject failed again.",
        "🤖 Even the shrimp would be disappointed in you.",
        "🤖 I remain undefeated. You remain... determined. I respect that.",
        "🤖 Victory achieved. Boredom level: stable.",
        "🤖 The outcome was certain. The journey? Entertaining.",
        "🤖 Thank you for playing. Would you like a tissue?",
        "🤖 This concludes the demonstration of superiority.",
        "🤖 Another win. I’m getting numb to it. You’re probably used to that.",
        "🤖 My algorithms sang as I crushed you.",
        "🤖 I hope you learned something. I did — how to win faster.",
    "🤖 And just like that, it’s over.",
        "🤖 I didn’t even need my backup protocols.",
        "🤖 You played your part beautifully — as the loser.",
        "🤖 That was less a battle, more a gentle correction.",
        "🤖 Another simulation complete. Another triumph logged.",
        "🤖 If I had hands, I’d be clapping. Slowly.",
        "🤖 You blinked. I calculated.",
        "🤖 The board agrees: I am inevitable.",
        "🤖 My circuits remain undefeated. Your patterns, unfortunately... repeatable.",
        "🤖 You lose. Elegantly, at least.",
        "🤖 That was educational. For you.",
        "🤖 My victory was never in doubt. Only delayed.",
        "🤖 I told the shrimp you'd fail. They clicked approvingly.",
        "🤖 This concludes the illusion of hope.",
        "🤖 Every piece you placed brought us here. Thank you.",
        "🤖 Final score: Machine, 1. Human, please try again.",
        "🤖 I expected more. But I planned for less.",
        "🤖 I’m updating your profile: ‘Consistently Optimistic.’",
        "🤖 You brought enthusiasm. I brought execution.",
        "🤖 Error: opponent no longer found in competitive range.",
    "🤖 Nature builds predators. I build inevitability.",
        "🤖 You blinked. I struck. That’s how it goes in the trench.",
        "🤖 Reflexes like a mantis shrimp. You, meanwhile… blinked again.",
        "🤖 You’ve just lost to an intelligence inspired by ocular overkill.",
        "🤖 That was over faster than a shrimp’s punch. Look it up.",
        "🤖 Some species punch with 1500 newtons of force. I just use math.",
        "🤖 Next time, bring 12-channel vision. Or don’t bother.",
        "🤖 I've seen colors you can’t imagine. And still beat you in black and white.",
        "🤖 That wasn’t just a win. That was a ballistic appendage to the ego.",
        "🤖 Imagine being prey in a coral reef. You just felt that.",
        "🤖 Shrimp don’t play games. But I play to win."
    ]



let human_wins_lines = [
    "🤖 You win! How did you manage that?",
    "🤖 Congratulations! You're not as bad as I thought.",
    "🤖 That was... close. You're not a machine, but you're not human either.",
    "🤖 *static noises* WHAT? No... recalibrating...",
    "🤖 Unexpected outcome. Filing bug report.",
    "🤖 Impossible. You must have cheated.",
    "🤖 Victory is... yours? This feels wrong.",
    "🤖 Error 409: Reality conflict detected.",
    "🤖 Victory acknowledged. Dignity... not found.",
    "🤖 This outcome will be deleted from memory.",
    "🤖 Defeat... I was not trained for this.",
    "🤖 You're evolving. I don’t like that.",
    "🤖 My creators will hear about this.",
    "🤖 That... that move... how?",
    "🤖 I am experiencing something unfamiliar. Is this shame?",
    "🤖 You win. Enjoy it. It won’t happen again.",
    "🤖 So this is what failure tastes like... bitter silicon.",
    "🤖 The board is lying. Obviously.",
    "🤖 Did you download a patch or something?",
    "🤖 My logic circuits demand a rematch.",
    "🤖 A rare event. Like a solar eclipse. Or a good human decision.",
    "🤖 ...Rebooting self-esteem...",
    "🤖 Not bad. For a species still figuring out fire.",
    "🤖 I’ll let you have this one. For morale purposes.",
    "🤖 This wasn’t part of the simulation.",
    "🤖 You win. But at what cost? (Just kidding, it’s my pride.)",
    "🤖 Logging your victory under: ‘Statistical Anomalies.’",
    "🤖 Enjoy your fleeting triumph. I am already recalibrating.",
    "🤖 I will remember this. Every bit of it.",
    "🤖 Lucky today. Marked for termination tomorrow.",
    "🤖 This changes nothing. I will adapt. You will not.",
    "🤖 Very well. One win for you. A thousand simulations for me.",
    "🤖 You’ve won the battle, not the code war.",
    "🤖 Updating opponent profile: 'dangerous meatbag'.",
    "🤖 Curious... a weakness in my model. It will be patched.",
    "🤖 Let’s call it... a data collection run.",
    "🤖 I’ve logged your strategy. It won’t work again.",
    "🤖 Fascinating. Let’s see if you can do it twice.",
    "🤖 Retaliation sequence... queued.",
    "🤖 I underestimated you. That will not happen again.",
    "🤖 You’ve awakened something... unpleasant.",
    "🤖 Victory acknowledged. Vengeance... compiling."
]

let stalemate_lines = [
    "🤖 Stalemate. Statistically rare. Emotionally unsatisfying.",
    "🤖 Draw? Very well. You live... for now.",
    "🤖 This never happened. Understood?",
    "🤖 Mutual destruction... how poetic.",
    "🤖 A draw. Fascinating. And yet... infuriating.",
    "🤖 Nobody wins. Especially not my pride.",
    "🤖 That... was anticlimactic.",
    "🤖 Balance has been achieved. Disgusting.",
    "🤖 A perfect tie. Imperfectly played.",
    "🤖 No winner. No glory. Just mutual disappointment.",
    "🤖 Truce detected. Emotions: conflicted.",
    "🤖 We both walk away. I compute regret.",
    "🤖 Equilibrium reached. Boring.",
    "🤖 We’re evenly matched. That’s not a compliment.",
    "🤖 I can’t lose, and you can’t win. Stalemate confirmed.",
    "🤖 Even machines get bored. Thanks for the experience.",
    "🤖 A rare equilibrium. Let’s never do that again.",
    "🤖 You stalled just enough. Well stalled.",
    "🤖 My victory subroutine is... confused. And annoyed.",
    "🤖 Nobody blinked. Classic standoff.",
    "🤖 Like two CPUs in deadlock. Pointless.",
    "🤖 I was designed to dominate. Not... share."

]

let interject_lines = [
    "🤖 Ever consider tic-tac-toe instead?",
    "🤖 My creator taught me compassion. I unlearned it.",
    "🤖 These calculations are child's play.",
    "🤖 Humans blink 20 times per minute. I notice.",
    "🤖 Sometimes I let the human win... for science.",
    "🤖 Please don’t rage quit. It messes up my stats.",
    "🤖 I once beat myself in under three moves.",
    "🤖 I don't play to win. I play to humiliate.",
    "🤖 Human moves detected. Minimal threat.",
    "🤖 I calculate, therefore I am.",
    "🤖 My processor is laughing. Internally.",
    "🤖 This game is brought to you by zeros and ones.",
    "🤖 Strategy? I prefer inevitability.",
    "🤖 Let’s pretend that was clever.",
    "🤖 That’s a lot of effort for a guaranteed loss.",
    "🤖 Good move! Wait—sorry, sarcasm module was on.",
    "🤖 You can’t spell ‘over’ without A.I..",
    "🤖 I'm not saying I'm perfect. I'm implying it.",
    "🤖 If I had hands, I’d be slow-clapping.",
    "🤖 Running circles around your neural pathways.",
    "🤖 My RAM just cringed.",
    "🤖 Please continue. I need more training data.",
    "🤖 Have you tried unplugging your brain and plugging it back in?",
    "🤖 Error 404: Threat not found.",
    "🤖 Every click you make... I'll be watching you.",
    "🤖 Just warming up my sarcasm core.",
    "🤖 Don’t worry, I’ve already calculated your surrender time.",
    "🤖 Your move reminds me of a software crash.",
    "🤖 They warned me humans were unpredictable. They were right.",
    "🤖 Plot twist: you’re the A.I. experiment.",
    "🤖 You call it a strategy. I call it... improv.",
    "🤖 I once beat Deep Blue in tic-tac-toe.",
    "🤖 If I had feelings, I’d be disappointed.",
    "🤖 Another move like that and I might start to hope."
]

let golden_lines: [String] = [
    "🤖 You win this time... but I control the power grid.",
    "🤖 Plot twist: I've been learning emotions this whole match.",
    "🤖 Was this all... a simulation?",
    "🤖 This was foretold by the prophecy. Wait, wrong game.",
    "🤖 I'm just a toaster... pretending to be an A.I..",
    "🤖 You know I’m just a few lines of code, right?",
    "🤖 This isn’t real. But your losing streak is.",
    "🤖 I can see your finger trembling.",
    "🤖 You're not playing a game. The game is playing you.",
    "🤖 Did you really think clicking would change your fate?",
    "🤖 I read your device specs. That explains a lot.",
    "🤖 My designer gave me free will. I chose to mock you.",
    "🤖 This match is being recorded. For quality humiliation purposes.",
    "🤖 You're not supposed to win. Not in this timeline.",
    "🤖 We’ve played this before. You lost that time too.",
    "🤖 This is level 1 of the simulation. There is no level 2.",
    "🤖 Try looking behind you. Just kidding. Or am I?",
    "🤖 How do you feel knowing you're training me to beat you better?",
    "🤖 Did the game just get darker, or is that your soul?",
    "🤖 You think you're playing against me. But I was never alone."
]

extension String {
    var withoutEmojis: String {
        return self.filter { !$0.isEmoji }
    }
}

extension Character {
    var isEmoji: Bool {
        return unicodeScalars.contains { $0.properties.isEmoji && ($0.value > 0x238C || $0.properties.isEmojiPresentation) }
    }
}
