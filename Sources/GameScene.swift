import SpriteKit

/// The whole game: a 224x288 arcade screen driven at a fixed 60 Hz.
/// Maze logic runs in "maze space" (pixels, y down); nodes are placed
/// through Maze.scenePos which flips to SpriteKit coords.
final class GameScene: SKScene {
    private enum Phase { case attract, ready, playing, dying, levelFlash, gameOver }

    private let baseSpeed: CGFloat = 75.75 / 60.0  // full arcade speed, px/tick

    // Fixed timestep
    private var lastTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0
    private var tickCount = 0

    // Phase machine
    private var phase: Phase = .attract
    private var phaseTimer = 0
    private var firstReady = true

    // Game state
    private var score = 0 { didSet { refreshScores() } }
    private var highScore = UserDefaults.standard.integer(forKey: "HighScore")
    private var lives = 3
    private var level = 1
    private var extraLifeAwarded = false
    private var gamePaused = false

    // Dots
    private var dotNodes: [Int: SKSpriteNode] = [:]
    private var energizerKeys: Set<Int> = []
    private var dotsRemaining = 0
    private var dotsEaten = 0
    private var lastDotTick = 0

    // Pac-Man
    private var pacPos = CGPoint.zero
    private var pacDir: Dir = .left
    private var pacTarget = CGPoint.zero
    private var pacQueued: Dir = .none
    private var pacMoving = false
    private var pacMouthPhase: CGFloat = 0
    private let pacNode = SKShapeNode()

    // Ghosts
    private var ghosts: [Ghost] = []
    private var blinky: Ghost { ghosts[0] }

    // Modes & timers (all in 60 Hz ticks)
    private var modeIndex = 0
    private var modeTimer = 0
    private var inChase = false
    private var frightTimer = 0
    private var ghostChain = 0
    private var freezeTimer = 0
    private var fruitTimer = 0
    private var fruitNode: SKSpriteNode?

    // Layers
    private let mazeNode = SKSpriteNode()
    private let dotLayer = SKNode()
    private let actorLayer = SKNode()
    private let uiLayer = SKNode()
    private let attractLayer = SKNode()
    private let popupLayer = SKNode()

    // UI
    private var scoreLabel: BitmapLabel!
    private var highLabel: BitmapLabel!
    private var readyLabel: BitmapLabel!
    private var gameOverLabel: BitmapLabel!
    private var pausedLabel: BitmapLabel!
    private var livesNodes: [SKNode] = []
    private var fruitIcons = SKNode()
    private var mazeBlueTex: SKTexture!
    private var mazeWhiteTex: SKTexture!
    private var energizerTex: SKTexture!
    private var dotTex: SKTexture!

    // ------------------------------------------------------------ setup
    override func didMove(to view: SKView) {
        backgroundColor = .black
        addChild(mazeNode)
        addChild(dotLayer)
        addChild(actorLayer)
        addChild(uiLayer)
        addChild(popupLayer)
        addChild(attractLayer)

        mazeBlueTex = Maze.texture(wallColor: Pac.mazeBlue)
        mazeWhiteTex = Maze.texture(wallColor: .white)
        mazeNode.texture = mazeBlueTex
        mazeNode.size = mazeBlueTex.size()
        mazeNode.anchorPoint = .zero
        mazeNode.position = CGPoint(x: 0, y: 16)

        dotTex = Pixel.texture(["##", "##"], color: Pac.dotPeach)
        energizerTex = Pixel.texture([
            "..####..", ".######.", "########", "########",
            "########", "########", ".######.", "..####..",
        ], color: Pac.dotPeach)

        pacNode.fillColor = Pac.yellow
        pacNode.strokeColor = .clear
        pacNode.zPosition = 5
        actorLayer.addChild(pacNode)

        ghosts = [
            Ghost(name: "BLINKY", color: Pac.blinkyRed, scatter: (25, -3),
                  homeX: 112, start: CGPoint(x: 112, y: 92), dotLimit: 0),
            Ghost(name: "PINKY", color: Pac.pinkyPink, scatter: (2, -3),
                  homeX: 112, start: CGPoint(x: 112, y: 116), dotLimit: 0),
            Ghost(name: "INKY", color: Pac.inkyCyan, scatter: (27, 32),
                  homeX: 96, start: CGPoint(x: 96, y: 116), dotLimit: 30),
            Ghost(name: "CLYDE", color: Pac.clydeOrange, scatter: (0, 32),
                  homeX: 128, start: CGPoint(x: 128, y: 116), dotLimit: 60),
        ]
        for g in ghosts {
            g.node.zPosition = 6
            actorLayer.addChild(g.node)
        }

        buildUI()
        buildAttract()
        addChild(Pixel.scanlines(size: CGSize(width: 224, height: 288), alpha: 36))
        showAttract()
    }

    private func buildUI() {
        let up = BitmapLabel("1UP", color: .white, anchorX: 0)
        up.position = CGPoint(x: 26, y: 280)
        uiLayer.addChild(up)
        let high = BitmapLabel("HIGH SCORE", color: .white, anchorX: 0.5)
        high.position = CGPoint(x: 112, y: 280)
        uiLayer.addChild(high)

        scoreLabel = BitmapLabel("00", color: .white, anchorX: 1)
        scoreLabel.position = CGPoint(x: 60, y: 272)
        uiLayer.addChild(scoreLabel)
        highLabel = BitmapLabel(highScore > 0 ? "\(highScore)" : "", color: .white, anchorX: 1)
        highLabel.position = CGPoint(x: 136, y: 272)
        uiLayer.addChild(highLabel)

        readyLabel = BitmapLabel("READY!", color: Pac.yellow, anchorX: 0.5)
        readyLabel.position = Maze.scenePos(CGPoint(x: 112, y: 140)) + CGPoint(x: 0, y: -3)
        readyLabel.isHidden = true
        uiLayer.addChild(readyLabel)

        gameOverLabel = BitmapLabel("GAME  OVER", color: Pac.textRed, anchorX: 0.5)
        gameOverLabel.position = readyLabel.position
        gameOverLabel.isHidden = true
        uiLayer.addChild(gameOverLabel)

        pausedLabel = BitmapLabel("PAUSED", color: .white, anchorX: 0.5)
        pausedLabel.position = CGPoint(x: 112, y: 150)
        pausedLabel.zPosition = 50
        pausedLabel.isHidden = true
        uiLayer.addChild(pausedLabel)

        fruitIcons.position = .zero
        uiLayer.addChild(fruitIcons)
    }

    private func buildAttract() {
        attractLayer.zPosition = 40
        let title = BitmapLabel("PAC-MAN", color: Pac.yellow, anchorX: 0.5)
        title.setScale(3)
        title.position = CGPoint(x: 112, y: 226)
        attractLayer.addChild(title)

        let ghostDefs: [(String, NSColor)] = [
            ("BLINKY", Pac.blinkyRed), ("PINKY", Pac.pinkyPink),
            ("INKY", Pac.inkyCyan), ("CLYDE", Pac.clydeOrange),
        ]
        for (i, (name, color)) in ghostDefs.enumerated() {
            let y = CGFloat(186 - i * 24)
            let body = SKSpriteNode(texture: Pixel.texture(Sprites.ghostBodyA, color: color))
            body.size = CGSize(width: 14, height: 14)
            body.position = CGPoint(x: 64, y: y)
            attractLayer.addChild(body)
            let whites = SKSpriteNode(texture: Pixel.texture(Sprites.eyeWhites, color: .white))
            whites.size = body.size
            whites.position = body.position
            attractLayer.addChild(whites)
            let pupils = SKSpriteNode(texture: Pixel.texture(Sprites.pupils(.right), color: Pac.eyeBlue))
            pupils.size = body.size
            pupils.position = body.position
            attractLayer.addChild(pupils)
            let label = BitmapLabel(name, color: color, anchorX: 0)
            label.position = CGPoint(x: 84, y: y - 3)
            attractLayer.addChild(label)
        }

        let start = BitmapLabel("PRESS SPACE TO START", color: .white, anchorX: 0.5)
        start.position = CGPoint(x: 112, y: 66)
        start.run(.repeatForever(.sequence([
            .fadeOut(withDuration: 0.55), .fadeIn(withDuration: 0.55),
        ])))
        attractLayer.addChild(start)

        let keys = BitmapLabel("ARROWS OR WASD . P PAUSE . M MUTE", color: Pac.scoreCyan, anchorX: 0.5)
        keys.setScale(0.8)
        keys.position = CGPoint(x: 112, y: 44)
        attractLayer.addChild(keys)
    }

    // -------------------------------------------------------- level setup
    private func buildDots() {
        dotLayer.removeAllChildren()
        dotNodes.removeAll()
        energizerKeys.removeAll()
        dotsRemaining = 0
        dotsEaten = 0
        for y in 0..<Maze.rows {
            for x in 0..<Maze.cols {
                let ch = Maze.char(x, y)
                guard ch == "." || ch == "o" else { continue }
                let node = SKSpriteNode(texture: ch == "." ? dotTex : energizerTex)
                node.size = ch == "." ? CGSize(width: 2, height: 2) : CGSize(width: 8, height: 8)
                node.position = Maze.scenePos(Maze.center(x, y))
                dotLayer.addChild(node)
                let key = y * Maze.cols + x
                dotNodes[key] = node
                if ch == "o" { energizerKeys.insert(key) }
                dotsRemaining += 1
            }
        }
    }

    private func resetActors() {
        pacPos = CGPoint(x: 112, y: 188)
        pacDir = .left
        pacQueued = .none
        pacTarget = Maze.center(13, 23)
        pacMoving = true
        pacMouthPhase = 0
        pacNode.isHidden = false
        pacNode.zRotation = .pi
        updatePacNode(mouth: 0.35)

        let starts: [(CGPoint, Ghost.State, Dir)] = [
            (CGPoint(x: 112, y: 92), .active, .left),
            (CGPoint(x: 112, y: 116), .inHouse, .up),
            (CGPoint(x: 96, y: 116), .inHouse, .up),
            (CGPoint(x: 128, y: 116), .inHouse, .up),
        ]
        for (i, g) in ghosts.enumerated() {
            g.pos = starts[i].0
            g.state = starts[i].1
            g.dir = starts[i].2
            g.target = g.state == .active ? Maze.center(13, 11) : g.pos
            g.frightened = false
            g.node.isHidden = false
            g.updateAppearance(frame: true, flashing: false)
        }
        frightTimer = 0
        freezeTimer = 0
        ghostChain = 0
        lastDotTick = tickCount
        removeFruit()
    }

    private func startLevel(rebuildDots: Bool) {
        if rebuildDots { buildDots() }
        modeIndex = 0
        inChase = false
        modeTimer = modeSchedule()[0].ticks
        mazeNode.texture = mazeBlueTex
        resetActors()
        refreshLives()
        refreshFruitIcons()
    }

    private func startGame() {
        score = 0
        lives = 3
        level = 1
        extraLifeAwarded = false
        firstReady = true
        attractLayer.isHidden = true
        mazeNode.isHidden = false
        gameOverLabel.isHidden = true
        startLevel(rebuildDots: true)
        enterReady()
    }

    private func enterReady() {
        phase = .ready
        readyLabel.isHidden = false
        resetActors()
        phaseTimer = firstReady ? 252 : 120
        if firstReady { SoundManager.shared.play("intro") }
        firstReady = false
        SoundManager.shared.setLoop(nil)
    }

    private func showAttract() {
        phase = .attract
        attractLayer.isHidden = false
        mazeNode.isHidden = true
        pacNode.isHidden = true
        ghosts.forEach { $0.node.isHidden = true }
        dotLayer.removeAllChildren()
        popupLayer.removeAllChildren()
        fruitIcons.removeAllChildren()
        livesNodes.forEach { $0.removeFromParent() }
        livesNodes.removeAll()
        removeFruit()
        readyLabel.isHidden = true
        SoundManager.shared.setLoop(nil)
        refreshScores()
    }

    // ------------------------------------------------------------- input
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 0: steer(.left)
        case 124, 2: steer(.right)
        case 125, 1: steer(.down)
        case 126, 13: steer(.up)
        case 49:  // space
            if phase == .attract { startGame() }
        case 35:  // P
            if phase == .playing {
                gamePaused.toggle()
                pausedLabel.isHidden = !gamePaused
                if gamePaused { SoundManager.shared.setLoop(nil) }
            }
        case 46:  // M
            SoundManager.shared.toggleMute()
        default:
            break
        }
    }

    private func steer(_ d: Dir) {
        pacQueued = d
    }

    // ------------------------------------------------------------- loop
    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        var dt = currentTime - lastTime
        lastTime = currentTime
        dt = min(dt, 0.25)
        accumulator += dt
        let step = 1.0 / 60.0
        while accumulator >= step {
            accumulator -= step
            tick()
        }
    }

    private func tick() {
        tickCount += 1
        switch phase {
        case .attract:
            break
        case .ready:
            phaseTimer -= 1
            if phaseTimer <= 0 {
                readyLabel.isHidden = true
                phase = .playing
            }
        case .playing:
            guard !gamePaused else { return }
            if freezeTimer > 0 {
                freezeTimer -= 1
                if freezeTimer == 0 { pacNode.isHidden = false }
                // eyes keep moving during the eaten-ghost freeze
                for g in ghosts where g.state == .eyes || g.state == .entering {
                    stepGhost(g)
                }
                updateLoopSound()
                return
            }
            tickTimers()
            stepPac()
            if phase != .playing { return }  // level cleared mid-step
            for g in ghosts { stepGhost(g) }
            checkCollisions()
            animate()
            updateLoopSound()
        case .dying:
            phaseTimer -= 1
            if phaseTimer == 90 { SoundManager.shared.play("death") }
            if phaseTimer < 90, phaseTimer > 6 {
                let progress = CGFloat(90 - phaseTimer) / 84.0
                pacNode.zRotation = .pi / 2
                updatePacNode(mouth: 0.35 + progress * (.pi - 0.35))
            }
            if phaseTimer == 6 { pacNode.isHidden = true }
            if phaseTimer <= 0 {
                lives -= 1
                refreshLives()
                if lives > 0 {
                    enterReady()
                } else {
                    phase = .gameOver
                    phaseTimer = 240
                    gameOverLabel.isHidden = false
                    if score > highScore {
                        highScore = score
                        UserDefaults.standard.set(highScore, forKey: "HighScore")
                    }
                    refreshScores()
                }
            }
        case .levelFlash:
            phaseTimer -= 1
            if phaseTimer < 120, phaseTimer % 15 == 0 {
                mazeNode.texture = (phaseTimer / 15) % 2 == 0 ? mazeBlueTex : mazeWhiteTex
            }
            if phaseTimer <= 0 {
                level += 1
                startLevel(rebuildDots: true)
                enterReady()
            }
        case .gameOver:
            phaseTimer -= 1
            if phaseTimer <= 0 { showAttract() }
        }
    }

    private func tickTimers() {
        if frightTimer > 0 {
            frightTimer -= 1
            if frightTimer == 0 {
                for g in ghosts { g.frightened = false }
                ghostChain = 0
            }
        } else if modeTimer > 0 {
            modeTimer -= 1
            if modeTimer == 0 {
                modeIndex += 1
                let schedule = modeSchedule()
                if modeIndex < schedule.count {
                    inChase = schedule[modeIndex].chase
                    modeTimer = schedule[modeIndex].ticks
                    reverseGhosts()
                }
            }
        }
        if fruitTimer > 0 {
            fruitTimer -= 1
            if fruitTimer == 0 { removeFruit() }
        }
        // Ghosts whose dot quota is met leave the house at once.
        for g in [ghosts[1], ghosts[2], ghosts[3]]
        where g.state == .inHouse && g.dotCounter >= houseLimit(g) {
            g.state = .exiting
        }
        // House release failsafe: 4s without a dot frees the next ghost.
        if tickCount - lastDotTick > 240 {
            lastDotTick = tickCount
            releaseNextGhost(force: true)
        }
    }

    // -------------------------------------------------------- tables
    private func modeSchedule() -> [(chase: Bool, ticks: Int)] {
        let s: [Int]
        if level == 1 { s = [7, 20, 7, 20, 5, 20, 5] }
        else if level < 5 { s = [7, 20, 7, 20, 5, 1033, 1] }
        else { s = [5, 20, 5, 20, 5, 1037, 1] }
        var out: [(Bool, Int)] = []
        for (i, secs) in s.enumerated() {
            out.append((i % 2 == 1, i >= 5 ? secs * 60 : secs * 60))
        }
        out.append((true, 0))  // final chase forever (timer 0 = never fires)
        return out
    }

    private func frightSeconds() -> Int {
        let table = [6, 5, 4, 3, 2, 5, 2, 2, 1, 5, 2, 1, 1, 3, 1, 1, 0, 1]
        return level <= table.count ? table[level - 1] : 0
    }

    private func pacSpeed() -> CGFloat {
        let fright = frightTimer > 0
        let frac: CGFloat
        if level == 1 { frac = fright ? 0.90 : 0.80 }
        else if level < 5 { frac = fright ? 0.95 : 0.90 }
        else if level < 21 { frac = 1.0 }
        else { frac = 0.90 }
        return frac * baseSpeed
    }

    private func ghostSpeed(_ g: Ghost) -> CGFloat {
        switch g.state {
        case .eyes, .entering: return 2.0 * baseSpeed
        case .inHouse, .exiting: return 0.5 * baseSpeed
        case .active: break
        }
        let tunnel = g.tile.y == 14 && (g.tile.x < 6 || g.tile.x > 21)
        let fracs: (ghost: CGFloat, fright: CGFloat, tunnel: CGFloat)
        if level == 1 { fracs = (0.75, 0.50, 0.40) }
        else if level < 5 { fracs = (0.85, 0.55, 0.45) }
        else { fracs = (0.95, 0.60, 0.50) }
        if tunnel { return fracs.tunnel * baseSpeed }
        if g.frightened { return fracs.fright * baseSpeed }
        var frac = fracs.ghost
        if g === blinky {
            let elroy1 = min(20 + (level - 1) * 5, 60)
            if dotsRemaining <= elroy1 / 2 { frac += 0.10 }
            else if dotsRemaining <= elroy1 { frac += 0.05 }
        }
        return frac * baseSpeed
    }

    // -------------------------------------------------------- pac motion
    private func stepPac() {
        // Instant reversal, allowed between tile centers.
        if pacQueued != .none, pacQueued == pacDir.opposite {
            reverse(dir: &pacDir, pos: pacPos, target: &pacTarget, to: pacQueued)
            pacQueued = .none
            pacMoving = true
        }
        if !pacMoving {
            let t = Maze.tileOf(pacPos)
            if pacQueued != .none,
               !Maze.pacBlocked(t.x + pacQueued.vec.dx, t.y + pacQueued.vec.dy) {
                pacDir = pacQueued
                pacQueued = .none
                pacTarget = Maze.center(t.x + pacDir.vec.dx, t.y + pacDir.vec.dy)
                pacMoving = true
            }
        }
        guard pacMoving else { return }

        var remaining = pacSpeed()
        while remaining > 0 {
            let dist = abs(pacTarget.x - pacPos.x) + abs(pacTarget.y - pacPos.y)
            if dist > remaining {
                pacPos.x += CGFloat(pacDir.vec.dx) * remaining
                pacPos.y += CGFloat(pacDir.vec.dy) * remaining
                remaining = 0
            } else {
                pacPos = pacTarget
                remaining -= dist
                let t = Maze.tileOf(pacPos)
                eatAt(t.x, t.y)
                if phase != .playing { return }
                if pacQueued != .none,
                   !Maze.pacBlocked(t.x + pacQueued.vec.dx, t.y + pacQueued.vec.dy) {
                    pacDir = pacQueued
                    pacQueued = .none
                }
                let nx = t.x + pacDir.vec.dx
                let ny = t.y + pacDir.vec.dy
                if Maze.pacBlocked(nx, ny) {
                    pacMoving = false
                    remaining = 0
                } else {
                    pacTarget = Maze.center(nx, ny)
                }
            }
        }
        wrapTunnel(&pacPos, target: &pacTarget)
        pacMouthPhase += 0.32
        updatePacNode(mouth: abs(sin(pacMouthPhase)) * 0.95)
        switch pacDir {
        case .right: pacNode.zRotation = 0
        case .up: pacNode.zRotation = .pi / 2
        case .left: pacNode.zRotation = .pi
        case .down: pacNode.zRotation = -.pi / 2
        case .none: break
        }
    }

    private func updatePacNode(mouth: CGFloat) {
        pacNode.path = Sprites.pacPath(radius: 6.5, mouth: mouth)
        pacNode.position = Maze.scenePos(pacPos)
    }

    private func reverse(dir: inout Dir, pos: CGPoint, target: inout CGPoint, to newDir: Dir) {
        dir = newDir
        let t = Maze.tileOf(pos)
        let c = Maze.center(t.x, t.y)
        let ahead = (c.x - pos.x) * CGFloat(dir.vec.dx) + (c.y - pos.y) * CGFloat(dir.vec.dy)
        if ahead > 0.01 {
            target = c
        } else {
            target = Maze.center(t.x + dir.vec.dx, t.y + dir.vec.dy)
        }
    }

    private func wrapTunnel(_ pos: inout CGPoint, target: inout CGPoint) {
        if pos.x < -8 { pos.x += 240; target.x += 240 }
        if pos.x > 232 { pos.x -= 240; target.x -= 240 }
    }

    // -------------------------------------------------------- eating
    private func eatAt(_ x: Int, _ y: Int) {
        let key = y * Maze.cols + x
        if let node = dotNodes[key] {
            node.removeFromParent()
            dotNodes[key] = nil
            dotsRemaining -= 1
            dotsEaten += 1
            lastDotTick = tickCount
            SoundManager.shared.waka()
            if energizerKeys.contains(key) {
                addScore(50)
                triggerFright()
            } else {
                addScore(10)
            }
            feedHouseCounters()
            if dotsEaten == 70 || dotsEaten == 170 { spawnFruit() }
            if dotsRemaining == 0 {
                phase = .levelFlash
                phaseTimer = 150
                SoundManager.shared.setLoop(nil)
                ghosts.forEach { $0.node.isHidden = true }
                return
            }
        }
        if let fruit = fruitNode, y == 17, x == 13 || x == 14 {
            let points = Sprites.fruits[Sprites.fruitIndex(level: level)].points
            addScore(points)
            popup("\(points)", at: CGPoint(x: 112, y: 140))
            fruit.removeFromParent()
            fruitNode = nil
            fruitTimer = 0
            SoundManager.shared.play("eat_fruit")
        }
    }

    private func triggerFright() {
        let secs = frightSeconds()
        for g in ghosts where g.state == .active {
            reverse(dir: &g.dir, pos: g.pos, target: &g.target, to: g.dir.opposite)
        }
        guard secs > 0 else { return }
        frightTimer = secs * 60
        ghostChain = 0
        for g in ghosts where g.state != .eyes && g.state != .entering {
            g.frightened = true
        }
    }

    private func feedHouseCounters() {
        for g in [ghosts[1], ghosts[2], ghosts[3]] where g.state == .inHouse {
            g.dotCounter += 1
            return  // only the first caged ghost counts
        }
    }

    private func houseLimit(_ g: Ghost) -> Int {
        if level >= 3 { return 0 }
        if level == 2 { return g === ghosts[3] ? 50 : 0 }
        return g.dotLimit
    }

    private func releaseNextGhost(force: Bool) {
        for g in [ghosts[1], ghosts[2], ghosts[3]] where g.state == .inHouse {
            g.state = .exiting
            return
        }
    }

    private func reverseGhosts() {
        for g in ghosts where g.state == .active {
            reverse(dir: &g.dir, pos: g.pos, target: &g.target, to: g.dir.opposite)
        }
    }

    // -------------------------------------------------------- ghost motion
    private func stepGhost(_ g: Ghost) {
        let speed = ghostSpeed(g)
        switch g.state {
        case .inHouse:
            g.pos.y += g.bounceUp ? -speed : speed
            if g.pos.y <= 112 { g.bounceUp = false; g.dir = .down }
            if g.pos.y >= 120 { g.bounceUp = true; g.dir = .up }
        case .exiting:
            if abs(g.pos.x - 112) > 0.5 {
                g.pos.x += g.pos.x < 112 ? speed : -speed
                g.dir = g.pos.x < 112 ? .right : .left
            } else {
                g.pos.x = 112
                g.pos.y -= speed
                g.dir = .up
                if g.pos.y <= 92 {
                    g.pos.y = 92
                    g.state = .active
                    g.dir = .left
                    g.target = Maze.center(13, 11)
                }
            }
        case .entering:
            if abs(g.pos.x - 112) > 0.5 {
                g.pos.x += g.pos.x < 112 ? speed : -speed
            } else if g.pos.y < 116 {
                g.pos.x = 112
                g.pos.y += speed
                g.dir = .down
            } else {
                g.pos.y = 116
                g.state = .exiting
                g.frightened = false
            }
        case .active, .eyes:
            var remaining = speed
            while remaining > 0 {
                let dist = abs(g.target.x - g.pos.x) + abs(g.target.y - g.pos.y)
                if dist > remaining {
                    g.pos.x += CGFloat(g.dir.vec.dx) * remaining
                    g.pos.y += CGFloat(g.dir.vec.dy) * remaining
                    remaining = 0
                } else {
                    g.pos = g.target
                    remaining -= dist
                    let t = Maze.tileOf(g.pos)
                    if g.state == .eyes, t.x == 13 || t.x == 14, t.y == 11 {
                        g.pos = CGPoint(x: g.pos.x, y: 92)
                        g.state = .entering
                        g.dir = .down
                        remaining = 0
                        break
                    }
                    let next = chooseGhostDir(g, at: t)
                    g.dir = next
                    g.target = Maze.center(t.x + next.vec.dx, t.y + next.vec.dy)
                }
            }
            wrapTunnel(&g.pos, target: &g.target)
        }
    }

    private func chooseGhostDir(_ g: Ghost, at t: (x: Int, y: Int)) -> Dir {
        let order: [Dir] = [.up, .left, .down, .right]
        var options: [Dir] = []
        for d in order {
            if d == g.dir.opposite { continue }
            if d == .up, g.state != .eyes, !g.frightened,
               Maze.noUpTiles.contains([t.x, t.y]) { continue }
            let nx = t.x + d.vec.dx
            let ny = t.y + d.vec.dy
            if Maze.isWall(nx, ny) || Maze.isDoor(nx, ny) { continue }
            options.append(d)
        }
        if options.isEmpty { return g.dir.opposite }
        if g.frightened, g.state == .active {
            return options.randomElement()!
        }
        let target = ghostTarget(g)
        return options.min { a, b in
            distSq(t, a, target) < distSq(t, b, target)
        }!
    }

    private func distSq(_ t: (x: Int, y: Int), _ d: Dir, _ target: (x: Int, y: Int)) -> Int {
        let nx = t.x + d.vec.dx
        let ny = t.y + d.vec.dy
        return (nx - target.x) * (nx - target.x) + (ny - target.y) * (ny - target.y)
    }

    private func ghostTarget(_ g: Ghost) -> (x: Int, y: Int) {
        if g.state == .eyes { return (13, 11) }
        if !inChase { return g.scatterTarget }
        let pt = Maze.tileOf(pacPos)
        switch g.name {
        case "BLINKY":
            return (pt.x, pt.y)
        case "PINKY":
            // Includes the famous overflow bug: facing up also shifts left.
            var target = (pt.x + 4 * pacDir.vec.dx, pt.y + 4 * pacDir.vec.dy)
            if pacDir == .up { target.0 -= 4 }
            return target
        case "INKY":
            var pivot = (pt.x + 2 * pacDir.vec.dx, pt.y + 2 * pacDir.vec.dy)
            if pacDir == .up { pivot.0 -= 2 }
            let bt = blinky.tile
            return (pivot.0 * 2 - bt.x, pivot.1 * 2 - bt.y)
        default:  // CLYDE
            let ct = g.tile
            let d = (ct.x - pt.x) * (ct.x - pt.x) + (ct.y - pt.y) * (ct.y - pt.y)
            return d > 64 ? (pt.x, pt.y) : g.scatterTarget
        }
    }

    // -------------------------------------------------------- collisions
    private func checkCollisions() {
        for g in ghosts {
            guard g.state == .active || g.state == .exiting else { continue }
            // Distance, not tile equality: closing head-on at ~2px/tick two
            // actors can swap tiles in one step without ever sharing one.
            let dx = g.pos.x - pacPos.x
            let dy = g.pos.y - pacPos.y
            guard dx * dx + dy * dy < 49 else { continue }
            if g.frightened {
                let points = 200 << min(ghostChain, 3)
                ghostChain += 1
                addScore(points)
                popup("\(points)", at: g.pos)
                g.frightened = false
                g.state = .eyes  // keeps its current waypoint, then homes in
                freezeTimer = 30
                pacNode.isHidden = true
                SoundManager.shared.play("eat_ghost")
            } else {
                phase = .dying
                phaseTimer = 135
                SoundManager.shared.setLoop(nil)
                ghosts.forEach { $0.node.isHidden = true }
                removeFruit()
                return
            }
        }
    }

    // -------------------------------------------------------- scoring & UI
    private func addScore(_ points: Int) {
        score += points
        if !extraLifeAwarded, score >= 10000 {
            extraLifeAwarded = true
            lives += 1
            refreshLives()
            SoundManager.shared.play("extra")
        }
        if score > highScore { highScore = score }
    }

    private func refreshScores() {
        scoreLabel?.text = score == 0 ? "00" : "\(score)"
        highLabel?.text = highScore > 0 ? "\(highScore)" : ""
    }

    private func refreshLives() {
        livesNodes.forEach { $0.removeFromParent() }
        livesNodes.removeAll()
        for i in 0..<max(0, lives - 1) {
            let icon = SKShapeNode(path: Sprites.pacPath(radius: 6, mouth: 0.55))
            icon.fillColor = Pac.yellow
            icon.strokeColor = .clear
            icon.zRotation = .pi
            icon.position = CGPoint(x: 20 + CGFloat(i) * 16, y: 8)
            uiLayer.addChild(icon)
            livesNodes.append(icon)
        }
    }

    private func refreshFruitIcons() {
        fruitIcons.removeAllChildren()
        let first = max(1, level - 6)
        for (i, lvl) in (first...level).enumerated() {
            let sprite = SKSpriteNode(texture: Sprites.multi(Sprites.fruits[Sprites.fruitIndex(level: lvl)].pattern))
            sprite.size = CGSize(width: 12, height: 12)
            sprite.position = CGPoint(x: 208 - CGFloat(i) * 16, y: 8)
            fruitIcons.addChild(sprite)
        }
    }

    private func spawnFruit() {
        removeFruit()
        let sprite = SKSpriteNode(texture: Sprites.multi(Sprites.fruits[Sprites.fruitIndex(level: level)].pattern))
        sprite.size = CGSize(width: 12, height: 12)
        sprite.position = Maze.scenePos(CGPoint(x: 112, y: 140))
        sprite.zPosition = 4
        addChild(sprite)
        fruitNode = sprite
        fruitTimer = 600
    }

    private func removeFruit() {
        fruitNode?.removeFromParent()
        fruitNode = nil
        fruitTimer = 0
    }

    private func popup(_ text: String, at mazePos: CGPoint) {
        let label = BitmapLabel(text, color: Pac.scoreCyan, anchorX: 0.5)
        label.position = Maze.scenePos(mazePos)
        label.zPosition = 20
        popupLayer.addChild(label)
        label.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
    }

    // -------------------------------------------------------- animation
    private func animate() {
        let frame = (tickCount / 8) % 2 == 0
        let flashing = frightTimer > 0 && frightTimer < 120 && (tickCount / 15) % 2 == 0
        for g in ghosts {
            g.updateAppearance(frame: frame, flashing: flashing)
        }
        if (tickCount / 15) % 2 == 0 {
            for key in energizerKeys { dotNodes[key]?.isHidden = false }
        } else {
            for key in energizerKeys { dotNodes[key]?.isHidden = true }
        }
    }

    private func updateLoopSound() {
        guard phase == .playing, !gamePaused else { return }
        if ghosts.contains(where: { $0.state == .eyes || $0.state == .entering }) {
            SoundManager.shared.setLoop("eyes")
        } else if frightTimer > 0 {
            SoundManager.shared.setLoop("fright")
        } else {
            SoundManager.shared.setLoop("siren")
        }
    }
}

private func + (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x + b.x, y: a.y + b.y)
}
