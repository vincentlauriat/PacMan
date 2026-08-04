import SpriteKit

/// One of the four ghosts, with its arcade personality.
final class Ghost {
    enum State { case inHouse, exiting, active, eyes, entering }

    let name: String
    let color: NSColor
    let scatterTarget: (x: Int, y: Int)
    let homeX: CGFloat  // in-house resting x (maze px)

    var pos: CGPoint
    var dir: Dir = .left
    var target: CGPoint  // waypoint: center of the tile being walked to
    var state: State = .inHouse
    var frightened = false
    var bounceUp = true
    var dotCounter = 0
    let dotLimit: Int

    let node = SKNode()
    let body: SKSpriteNode
    let whites: SKSpriteNode
    var pupilNodes: [Dir: SKSpriteNode] = [:]
    let face: SKSpriteNode
    private let bodyA: SKTexture
    private let bodyB: SKTexture
    private let frightA: SKTexture
    private let frightB: SKTexture
    private let flashA: SKTexture
    private let flashB: SKTexture
    private let faceBlue: SKTexture
    private let faceFlash: SKTexture

    init(name: String, color: NSColor, scatter: (Int, Int), homeX: CGFloat,
         start: CGPoint, dotLimit: Int) {
        self.name = name
        self.color = color
        self.scatterTarget = scatter
        self.homeX = homeX
        self.pos = start
        self.target = start
        self.dotLimit = dotLimit

        bodyA = Pixel.texture(Sprites.ghostBodyA, color: color)
        bodyB = Pixel.texture(Sprites.ghostBodyB, color: color)
        frightA = Pixel.texture(Sprites.ghostBodyA, color: Pac.frightBlue)
        frightB = Pixel.texture(Sprites.ghostBodyB, color: Pac.frightBlue)
        flashA = Pixel.texture(Sprites.ghostBodyA, color: Pac.frightSkin)
        flashB = Pixel.texture(Sprites.ghostBodyB, color: Pac.frightSkin)
        faceBlue = Pixel.texture(Sprites.frightFace, color: Pac.dotPeach)
        faceFlash = Pixel.texture(Sprites.frightFace, color: Pac.textRed)

        // The view runs with ignoresSiblingOrder, so layering inside the
        // ghost has to be spelled out with zPosition, not child order.
        body = SKSpriteNode(texture: bodyA)
        body.size = CGSize(width: 14, height: 14)
        body.zPosition = 0
        whites = SKSpriteNode(texture: Pixel.texture(Sprites.eyeWhites, color: .white))
        whites.size = body.size
        whites.zPosition = 1
        face = SKSpriteNode(texture: faceBlue)
        face.size = body.size
        face.zPosition = 3
        face.isHidden = true
        node.addChild(body)
        node.addChild(whites)
        node.addChild(face)
        for d in [Dir.up, .down, .left, .right, .none] {
            let p = SKSpriteNode(texture: Pixel.texture(Sprites.pupils(d), color: Pac.eyeBlue))
            p.size = body.size
            p.zPosition = 2
            p.isHidden = true
            node.addChild(p)
            pupilNodes[d] = p
        }
    }

    var tile: (x: Int, y: Int) { Maze.tileOf(pos) }

    /// Refresh textures for the current state; `frame` toggles the skirt,
    /// `flashing` is the end-of-frightened warning.
    func updateAppearance(frame: Bool, flashing: Bool) {
        let eyesOnly = (state == .eyes || state == .entering)
        body.isHidden = eyesOnly
        if frightened && !eyesOnly {
            body.texture = flashing ? (frame ? flashA : flashB) : (frame ? frightA : frightB)
            face.texture = flashing ? faceFlash : faceBlue
            face.isHidden = false
            whites.isHidden = true
            pupilNodes.values.forEach { $0.isHidden = true }
        } else {
            body.texture = frame ? bodyA : bodyB
            face.isHidden = true
            whites.isHidden = false
            for (d, p) in pupilNodes { p.isHidden = d != dir }
        }
        node.position = Maze.scenePos(pos)
    }
}
