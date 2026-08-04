import SpriteKit

/// Direction of travel on the maze grid (y grows downward in maze space).
enum Dir: CaseIterable {
    case up, left, down, right, none

    var vec: (dx: Int, dy: Int) {
        switch self {
        case .up: return (0, -1)
        case .down: return (0, 1)
        case .left: return (-1, 0)
        case .right: return (1, 0)
        case .none: return (0, 0)
        }
    }

    var opposite: Dir {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        case .none: return .none
        }
    }
}

/// The original 28x31 maze. '#' wall, '.' dot, 'o' energizer, '-' ghost
/// door, ' ' open corridor / house interior / tunnel.
enum Maze {
    static let cols = 28
    static let rows = 31
    static let tile: CGFloat = 8
    /// The maze occupies screen rows 3..33 of the 224x288 arcade screen.
    static let topOffset: CGFloat = 24

    static let layout: [String] = [
        "############################",
        "#............##............#",
        "#.####.#####.##.#####.####.#",
        "#o####.#####.##.#####.####o#",
        "#.####.#####.##.#####.####.#",
        "#..........................#",
        "#.####.##.########.##.####.#",
        "#.####.##.########.##.####.#",
        "#......##....##....##......#",
        "######.##### ## #####.######",
        "######.##### ## #####.######",
        "######.##          ##.######",
        "######.## ###--### ##.######",
        "######.## #      # ##.######",
        "      .   #      #   .      ",
        "######.## #      # ##.######",
        "######.## ######## ##.######",
        "######.##          ##.######",
        "######.## ######## ##.######",
        "######.## ######## ##.######",
        "#............##............#",
        "#.####.#####.##.#####.####.#",
        "#.####.#####.##.#####.####.#",
        "#o..##.......  .......##..o#",
        "###.##.##.########.##.##.###",
        "###.##.##.########.##.##.###",
        "#......##....##....##......#",
        "#.##########.##.##########.#",
        "#.##########.##.##########.#",
        "#..........................#",
        "############################",
    ]

    static let grid: [[Character]] = layout.map { Array($0) }

    /// Ghosts may not choose to turn up while crossing these tiles.
    static let noUpTiles: Set<[Int]> = [[12, 11], [15, 11], [12, 23], [15, 23]]

    static func char(_ x: Int, _ y: Int) -> Character {
        guard y >= 0, y < rows else { return "#" }
        guard x >= 0, x < cols else { return y == 14 ? " " : "#" }  // tunnel
        return grid[y][x]
    }

    static func isWall(_ x: Int, _ y: Int) -> Bool { char(x, y) == "#" }
    static func isDoor(_ x: Int, _ y: Int) -> Bool { char(x, y) == "-" }

    /// Pac-Man can never pass walls or the ghost door.
    static func pacBlocked(_ x: Int, _ y: Int) -> Bool {
        isWall(x, y) || isDoor(x, y)
    }

    /// Center of a tile in maze pixel space (y down).
    static func center(_ x: Int, _ y: Int) -> CGPoint {
        CGPoint(x: CGFloat(x) * tile + 4, y: CGFloat(y) * tile + 4)
    }

    static func tileOf(_ p: CGPoint) -> (x: Int, y: Int) {
        (Int(floor(p.x / tile)), Int(floor(p.y / tile)))
    }

    /// Convert maze pixel coords (y down) to SpriteKit scene coords (y up).
    static func scenePos(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: 288 - topOffset - p.y)
    }

    // ---------------------------------------------------------- rendering
    /// Draw the wall outlines into one nearest-neighbor texture.
    /// Every wall edge that faces a corridor gets a 1px stroke.
    static func texture(wallColor: NSColor) -> SKTexture {
        let w = cols * Int(tile)
        let h = rows * Int(tile)
        let c = wallColor.usingColorSpace(.deviceRGB) ?? wallColor
        let r = UInt8(c.redComponent * 255)
        let g = UInt8(c.greenComponent * 255)
        let b = UInt8(c.blueComponent * 255)
        var data = [UInt8](repeating: 0, count: w * h * 4)

        func set(_ x: Int, _ y: Int) {
            guard x >= 0, x < w, y >= 0, y < h else { return }
            let i = (y * w + x) * 4
            data[i] = r; data[i + 1] = g; data[i + 2] = b; data[i + 3] = 255
        }

        func open(_ x: Int, _ y: Int) -> Bool {
            let ch = char(x, y)
            return ch != "#"
        }

        for ty in 0..<rows {
            for tx in 0..<cols where isWall(tx, ty) {
                let px = tx * 8, py = ty * 8
                if open(tx, ty - 1) { for x in 0..<8 { set(px + x, py) } }
                if open(tx, ty + 1) { for x in 0..<8 { set(px + x, py + 7) } }
                if open(tx - 1, ty) { for y in 0..<8 { set(px, py + y) } }
                if open(tx + 1, ty) { for y in 0..<8 { set(px + 7, py + y) } }
            }
        }

        // Ghost house door: pink horizontal bar.
        let dc = Pac.doorPink.usingColorSpace(.deviceRGB)!
        for ty in 0..<rows {
            for tx in 0..<cols where isDoor(tx, ty) {
                for x in 0..<8 {
                    for y in 3...4 {
                        let i = ((ty * 8 + y) * w + tx * 8 + x) * 4
                        data[i] = UInt8(dc.redComponent * 255)
                        data[i + 1] = UInt8(dc.greenComponent * 255)
                        data[i + 2] = UInt8(dc.blueComponent * 255)
                        data[i + 3] = 255
                    }
                }
            }
        }
        return Pixel.textureFromRGBA(&data, width: w, height: h)
    }
}
