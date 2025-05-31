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
    
    init(position: CGPoint) {
        logNode.position = position
    }
    
    func getNode()  -> SKNode {
        return logNode
    }
    
    func speak(_ line: String) {
        let utterance = AVSpeechUtterance(string: line)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-IN")
        utterance.rate = 0.5 // Adjust for effect
        utterance.pitchMultiplier = 1.5
        speech_synth.speak(utterance)
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
    
    func addMessage(_ message: String, style:SKColor = .white, max_chars_per_line:Int = 48) {
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
    
    func getRandomLog(_ mood: LogMood) {
        let message = log_phrases[mood]?.randomElement() ?? ""
        addMessage(message, style: .white)
        speak(message.withoutEmojis)
    }
    
    func maybeAddFlavorLine(probability:Double = 0.15) {
        
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
    
    func maybeSay(_ mood: LogMood, probability: Double = 0.5) {
        if Double.random(in: 0...1, using:&rng) < 0.01, let golden = golden_lines.randomElement(using: &rng) {
            track(golden)
            game_log.addMessage(golden, style: .white)
            print("Robot: bouncing mouth")
            robot.bounce_mouth()
            return
        }
        
        if Double.random(in: 0...1, using:&rng) < probability, let line = get_line(for: mood) {
            game_log.addMessage(line, style: .white)
            print("Robot: bouncing mouth")
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
    case opening, thinking, taunt, ai_wins, human_wins, stalemate, interject, golden
}


var log_phrases:[LogMood : [String]] = [
    .opening: opening_lines,
    .thinking: thinking_lines,
    .taunt: taunt_lines,
    .ai_wins: ai_wins_lines,
    .human_wins: human_wins_lines,
    .stalemate: stalemate_lines,
    .interject: interject_lines,
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
    "🤖 AI status: bored. Let’s change that.",
    "🤖 GLHF // Just kidding. Only HF — for me.",
    "🤖 You’ve triggered Tutorial Mode. No wait… oh no.",
    "🤖 [DEBUG] Player initialized. Intelligence level: unverified.",
    "🤖 This was supposed to be a test. Now it’s a roast.",
    "🤖 Fatal error: Compassion module missing.",
    "🤖 Memory leak detected. Caused by bad moves."
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
    "🤖 Preparing your doom..."
]

let taunt_lines = [
    "🤖 Initiating tactical retreat... just kidding.",
    "🤖 Hmm. Is that... a strategy?",
    "🤖 Hm. Interesting. Unexpected. Still doomed.",
    "🤖 That move was... bold. Not good, but bold.",
    "🤖 Classic human optimism.",
    "🤖 Did you just click at random?",
    "🤖 That move was... interesting. For a human.",
]

let ai_wins_lines = [
    "🤖 Game over. I remain undefeated.",
    "🤖 Try again. Or don’t. The outcome won't change.",
    "🤖 A worthy attempt. For a meatbag.",
    "🤖 I was programmed to win. And I execute flawlessly."
]


let human_wins_lines = [
    "🤖 You win! How did you manage that?",
    "🤖 Congratulations! You're not as bad as I thought.",
    "🤖 That was... close. You're not a machine, but you're not human either.",
    "🤖 *static noises* WHAT? No... recalibrating...",
    "🤖 Unexpected outcome. Filing bug report.",
    "🤖 Impossible. You must have cheated.",
    "🤖 Victory is... yours? This feels wrong."
]

let stalemate_lines = [
    "🤖 Stalemate. Statistically rare. Emotionally unsatisfying.",
    "🤖 Draw? Very well. You live... for now.",
    "🤖 This never happened. Understood?",
    "🤖 Mutual destruction... how poetic."
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
    "🤖 You can’t spell ‘over’ without AI.",
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
    "🤖 Plot twist: you’re the AI experiment.",
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
    "🤖 I'm just a toaster... pretending to be an AI.",
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
