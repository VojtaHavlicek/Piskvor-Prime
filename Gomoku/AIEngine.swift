//
//  AIEngine.swift
//  Gomoku
//
//  Created by Vojta Havlicek on 2/2/25.
//

// TODO: switch this to MCTS, but use the same heuristics?
// TODO: run AI in background?
// Works well

import Foundation

let BOARD_SIZE = 9
let L = 5
let WIN_UTIL = 100000
let MAX_DEPTH = 1 // It's super shallow, but it plays well anyway?

enum Player: String {
    case X = "X"
    case O = "O" // AI, MINIMIZING
    case empty = " "
}

struct Move: Hashable {
    let row: Int
    let col: Int
}

// Caches for dynamic programming
var movesCache = [String: [Move]]()
var applyMoveCache = [String: [[Player]]]()
var gameStateCache = [String: Player?]()
var evaluateStateCache = [String: Int]()
var heuristicCache = [String: Int]()

func getMoves(state: [[Player]], player:Player, topK: Int = 5) -> [Move] {
    let key = state.flatMap { $0.map { $0.rawValue } }.joined()+"_\(player.rawValue)"
    if let cached = movesCache[key] {
        return cached
    }

    let radius = 3
    var allEmpty = true
    var moves = Set<Move>()

    for row in 0..<BOARD_SIZE {
        for col in 0..<BOARD_SIZE {
            if state[row][col] != .empty {
                allEmpty = false
                for r in -radius..<radius {
                    for s in -radius..<radius {
                        let newRow = row + r
                        let newCol = col + s
                        guard newRow >= 0, newRow < BOARD_SIZE, newCol >= 0, newCol < BOARD_SIZE else { continue }
                                
                        if state[newRow][newCol] == .empty {
                            let move = Move(row: newRow, col: newCol)
                            moves.insert(Move(row: newRow, col: newCol))
                        }
                    }
                }
            }
        }
    }
    
    // Subsample moves?
    let result:[Move]
    
    if allEmpty {
        result = (0..<BOARD_SIZE).flatMap { row in (0..<BOARD_SIZE).map { col in Move(row: row, col: col) } }
    } else {
        let scored = moves.map { move in
                    let newState = applyMove(state: state, move: move, player: player)
                    let score = heuristic(state: newState, player: player)
                    return (move, score)
                }
        
        let sorted: [(Move, Int)]
        if player == .X {
            sorted = scored.sorted {$0.1 > $1.1}
        }
        else {
            sorted = scored.sorted {$0.1 < $1.1}
        }
        
        result = sorted.prefix(topK).map {$0.0}
    }
    movesCache[key] = result
    return result
}

func applyMove(state: [[Player]], move: Move, player: Player) -> [[Player]] {
    let key = state.flatMap { $0.map { $0.rawValue } }.joined() + "_\(move.row)_\(move.col)_\(player.rawValue)"
    if let cached = applyMoveCache[key] {
        return cached
    }

    var newState = state
    newState[move.row][move.col] = player
    applyMoveCache[key] = newState
    return newState
}

func policyScore(state: [[Player]], move: Move, player: Player) -> Int {
    // Policy scoring
    /*let opponent: Player = (player == .X) ? .O : .X
    var score = 0

    let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]
    let (r, c) = (move.row, move.col)

    for (dr, dc) in directions {
        var countPlayer = 0
        var countOpponent = 0

        for i in -3...3 {
            let nr = r + i * dr
            let nc = c + i * dc
            guard nr >= 0 && nr < BOARD_SIZE && nc >= 0 && nc < BOARD_SIZE else { continue }

            switch state[nr][nc] {
            case player: countPlayer += 1
            case opponent: countOpponent += 1
            default: break
            }
        }

        // Favor extensions of your lines and blocking opponent lines
        score += countPlayer * 10
        score += countOpponent * 6
    }*/
    

    // Small bias toward center of board
    //let center = BOARD_SIZE / 2
    //let distToCenter = abs(r - center) + abs(c - center)
    //score += (BOARD_SIZE * 2 - distToCenter)

    return evaluateState(state: state, player: player)
}


func getGameState(state: [[Player]]) -> Player? {
    let key = state.flatMap { $0.map { $0.rawValue } }.joined()
    if let cached = gameStateCache[key] {
        return cached
    }

    let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]

    for row in 0..<BOARD_SIZE {
        for col in 0..<BOARD_SIZE {
            for (dx, dy) in directions {
                var sequence: [Player] = []
                for i in 0..<L {
                    let x = col + i * dx
                    let y = row + i * dy
                    if x < 0 || x >= BOARD_SIZE || y < 0 || y >= BOARD_SIZE {
                        break
                    }
                    sequence.append(state[y][x])
                }

                if sequence.count == L {
                    if sequence.allSatisfy({ $0 == .X }) {
                        gameStateCache[key] = .X
                        return .X
                    }
                    if sequence.allSatisfy({ $0 == .O }) {
                        gameStateCache[key] = .O
                        return .O
                    }
                }
            }
        }
    }

    if state.flatMap({ $0 }).allSatisfy({ $0 != .empty }) {
        gameStateCache[key] = .empty
        return .empty
    }

    gameStateCache[key] = nil
    return nil
}

func minimax(state: [[Player]], player: Player, depth: Int, alpha: inout Int, beta: inout Int) -> Int {
    if depth == 0 || getGameState(state: state) != nil {
        return evaluateState(state: state, player: player)
    }

    let moves = getMoves(state: state, player: player) // ??? TODO: Subsample the number of moves?
    if player == .X {
        var maxEval = Int.min
        for move in moves {
            let newState = applyMove(state: state, move: move, player: .X)
            let eval = minimax(state: newState, player: .O, depth: depth - 1, alpha: &alpha, beta: &beta)
            maxEval = max(maxEval, eval)
            alpha = max(alpha, eval)
            if beta <= alpha {
                break
            }
        }
        return maxEval
    } else {
        var minEval = Int.max
        for move in moves {
            let newState = applyMove(state: state, move: move, player: .O)
            let eval = minimax(state: newState, player: .X, depth: depth - 1, alpha: &alpha, beta: &beta)
            minEval = min(minEval, eval)
            beta = min(beta, eval)
            if beta <= alpha {
                break
            }
        }
        return minEval
    }
}

func evaluateState(state: [[Player]], player: Player) -> Int {
    let key = state.flatMap { $0.map { $0.rawValue } }.joined() + "_\(player.rawValue)"
    if let cached = evaluateStateCache[key] {
        return cached
    }

    let result = heuristic(state: state, player: player)
    evaluateStateCache[key] = result
    return result
}

func heuristic(state: [[Player]], player: Player) -> Int {
    let key = state.flatMap { $0.map { $0.rawValue } }.joined() + "_\(player.rawValue)"
    if let cached = heuristicCache[key] {
        return cached
    }

    let patterns: [([Player], Int)] = [
        ([.X, .X, .X, .X, .X], WIN_UTIL),
        ([.O, .O, .O, .O, .O], -WIN_UTIL),
        ([.empty, .X, .X, .X, .X, .empty], WIN_UTIL/2),
        ([.empty, .O, .O, .O, .O, .empty], -WIN_UTIL/2),
        ([.X, .X, .empty, .X, .X], WIN_UTIL/20),
        ([.O, .O, .empty, .O, .O], -WIN_UTIL/20), // Add all of those
        ([.X, .empty, .X, .X, .X], WIN_UTIL/20),
        ([.O, .empty, .O, .O, .O], -WIN_UTIL/20), // Add all of those
        ([.X, .X, .X, .empty, .X], WIN_UTIL/20),
        ([.O, .O, .O, .empty, .O], -WIN_UTIL/20), // Add all of those
        ([.empty, .X, .X, .X, .X], WIN_UTIL / 10),
        ([.empty, .O, .O, .O, .O], -WIN_UTIL / 10),
        ([.X, .X, .X, .X, .empty], WIN_UTIL / 10),
        ([.O, .O, .O, .O, .empty], -WIN_UTIL / 10),
        ([.empty, .X, .X, .X, .empty], WIN_UTIL / 100),
        ([.empty, .O, .O, .O, .empty], -WIN_UTIL / 100),
        ([.empty, .X, .X, .empty], WIN_UTIL / 1000),
        ([.empty, .O, .O, .empty], -WIN_UTIL / 1000),
        ([.empty, .X, .empty], WIN_UTIL / 10000),
        ([.empty, .O, .empty], -WIN_UTIL / 10000)
    ]

    let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]
    var cost = 0

    for row in 0..<BOARD_SIZE {
        for col in 0..<BOARD_SIZE {
            for (dx, dy) in directions {
                for (pattern, score) in patterns {
                    var matched = true
                    for i in 0..<pattern.count {
                        let x = col + i * dx
                        let y = row + i * dy
                        if x < 0 || x >= BOARD_SIZE || y < 0 || y >= BOARD_SIZE || state[y][x] != pattern[i] {
                            matched = false
                            break
                        }
                    }
                    if matched {
                        cost += score
                    }
                }
            }
        }
    }

    heuristicCache[key] = cost
    return cost
}

func findBestMove(state: [[Player]], player: Player) -> Move? {
    var bestScore = player == .X ? Int.min : Int.max
    var bestMove: Move? = nil
    let moves = getMoves(state: state, player: player)

    for move in moves {
        let newState = applyMove(state: state, move: move, player: player)
        var alpha = Int.min
        var beta = Int.max
        let score = minimax(state: newState, player: player == .X ? .O : .X, depth: MAX_DEPTH, alpha: &alpha, beta: &beta)

        if player == .X && score > bestScore {
            bestScore = score
            bestMove = move
        } else if player == .O && score < bestScore {
            bestScore = score
            bestMove = move
        }
    }

    return bestMove
}

func checkWinCondition(state:[[Player]]) -> (Player, [(Int,Int)])?
{
    // Wincond patterns:
    let patterns:[([Player], Player)] = [(Array(repeating: .X, count: L), .X), (Array(repeating: .O, count: L), .O)]
    
    let directions = [(0,1),(1,0),(1,1),(1,-1)]
    for row in 0..<BOARD_SIZE {
        for col in 0..<BOARD_SIZE {
            for (dx, dy) in directions {
                // Winconds:
                for (pattern, winner) in patterns {
                    var matched = true
                    var streak:[(Int,Int)] = []
                    for i in 0..<pattern.count {
                        let x = col + i * dx
                        let y = row + i * dy
                        if x < 0 || x >= BOARD_SIZE || y < 0 || y >= BOARD_SIZE || state[y][x] != pattern[i] {
                            matched = false
                            break
                        }
                        
                        streak.append((y,x))
                    }
                    if matched {
                        return (winner, streak)
                    }
                }
            }
        }
    }
    
    return nil
}

func checkDraw(state:[[Player]]) -> Bool {
    // Draw: if you don't find this pattern, it's a draw
    let directions = [(0,1),(1,0),(1,1),(1,-1)]
    for row in 0..<BOARD_SIZE {
        for col in 0..<BOARD_SIZE {
            for (dx, dy) in directions {
                
                var types:Set<Player> = Set()
                var steps = 0
                
                // Winconds:
                for i in 0..<L {
                    let x = col + i * dx
                    let y = row + i * dy
                    
                    if x < 0 || x >= BOARD_SIZE || y < 0 || y >= BOARD_SIZE {
                        break
                    }
                    
                    types.insert(state[y][x])
                    steps += 1
                }
                
                // Check if the streak is playable
                if types.intersection([.O, .X]).count < 2 && steps == L{
                    return false
                }
            }
        }
    }
    
    return true
}
