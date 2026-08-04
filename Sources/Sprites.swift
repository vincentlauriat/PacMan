import SpriteKit

/// Arcade cabinet palette, straight from the 1980 PCB.
enum Pac {
    static let yellow = NSColor(red: 1.0, green: 0.95, blue: 0.0, alpha: 1)
    static let mazeBlue = NSColor(red: 0.13, green: 0.13, blue: 0.87, alpha: 1)
    static let dotPeach = NSColor(red: 1.0, green: 0.72, blue: 0.68, alpha: 1)
    static let doorPink = NSColor(red: 1.0, green: 0.72, blue: 1.0, alpha: 1)
    static let blinkyRed = NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1)
    static let pinkyPink = NSColor(red: 1.0, green: 0.72, blue: 1.0, alpha: 1)
    static let inkyCyan = NSColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1)
    static let clydeOrange = NSColor(red: 1.0, green: 0.72, blue: 0.32, alpha: 1)
    static let frightBlue = NSColor(red: 0.13, green: 0.13, blue: 0.87, alpha: 1)
    static let frightSkin = NSColor(red: 0.87, green: 0.87, blue: 1.0, alpha: 1)
    static let eyeBlue = NSColor(red: 0.13, green: 0.13, blue: 0.87, alpha: 1)
    static let textRed = NSColor(red: 1.0, green: 0.1, blue: 0.1, alpha: 1)
    static let scoreCyan = NSColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1)
}

enum Sprites {
    // ------------------------------------------------------------- ghosts
    static let ghostBodyA: [String] = [
        "....######....",
        "..##########..",
        ".############.",
        ".############.",
        "##############",
        "##############",
        "##############",
        "##############",
        "##############",
        "##############",
        "##############",
        "##############",
        "##############",
        "##.###..###.##",
    ]

    static let ghostBodyB: [String] = [
        "....######....",
        "..##########..",
        ".############.",
        ".############.",
        "##############",
        "##############",
        "##############",
        "##############",
        "##############",
        "##############",
        "##############",
        "##############",
        "##############",
        ".##..####..##.",
    ]

    static let eyeWhites: [String] = [
        "..............",
        "..............",
        "..............",
        "...##....##...",
        "..####..####..",
        "..####..####..",
        "..####..####..",
        "...##....##...",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
    ]

    /// 2x2 blue pupils, shifted toward the travel direction.
    static func pupils(_ dir: Dir) -> [String] {
        var grid = Array(repeating: Array(repeating: Character("."), count: 14), count: 14)
        var lx = 3, rx = 9, y = 5
        switch dir {
        case .left: lx = 2; rx = 8
        case .right: lx = 4; rx = 10
        case .up: y = 3
        case .down: y = 6
        case .none: break
        }
        for dy in 0..<2 {
            for dx in 0..<2 {
                grid[y + dy][lx + dx] = "#"
                grid[y + dy][rx + dx] = "#"
            }
        }
        return grid.map { String($0) }
    }

    /// Frightened face: hollow eyes + zigzag mouth.
    static let frightFace: [String] = [
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "...##....##...",
        "...##....##...",
        "..............",
        "..............",
        ".#..##..##..#.",
        ".#.#..##..#.#.",
        "..............",
        "..............",
        "..............",
    ]

    // ------------------------------------------------------------- fruits
    /// Multicolor pixel texture. Palette keys: R red, G green, Y yellow,
    /// O orange, W white, T tan/brown, P peach, C cyan, B blue, K grey.
    static func multi(_ pattern: [String]) -> SKTexture {
        let palette: [Character: (UInt8, UInt8, UInt8)] = [
            "R": (255, 30, 30), "G": (40, 200, 60), "Y": (255, 240, 50),
            "O": (255, 160, 40), "W": (240, 240, 240), "T": (200, 140, 70),
            "P": (255, 184, 150), "C": (60, 255, 255), "B": (60, 60, 230),
            "K": (170, 170, 190),
        ]
        let h = pattern.count
        let w = pattern[0].count
        var data = [UInt8](repeating: 0, count: w * h * 4)
        for (y, row) in pattern.enumerated() {
            for (x, ch) in Array(row).enumerated() {
                guard let (r, g, b) = palette[ch] else { continue }
                let i = (y * w + x) * 4
                data[i] = r; data[i + 1] = g; data[i + 2] = b; data[i + 3] = 255
            }
        }
        return Pixel.textureFromRGBA(&data, width: w, height: h)
    }

    /// Level fruits in arcade order with their point value.
    static let fruits: [(pattern: [String], points: Int)] = [
        (cherry, 100), (strawberry, 300), (peach, 500), (apple, 700),
        (grapes, 1000), (galaxian, 2000), (bell, 3000), (key, 5000),
    ]

    /// Fruit index for a given 1-based level (arcade schedule).
    static func fruitIndex(level: Int) -> Int {
        switch level {
        case 1: return 0
        case 2: return 1
        case 3, 4: return 2
        case 5, 6: return 3
        case 7, 8: return 4
        case 9, 10: return 5
        case 11, 12: return 6
        default: return 7
        }
    }

    static let cherry: [String] = [
        ".........GG.",
        "........GG..",
        ".......GG...",
        "......GG....",
        ".....GG.....",
        "..RRRGR.....",
        ".RRRRR.RRR..",
        ".RWRRRRRRRR.",
        ".RWRRRRWRRR.",
        ".RRRRRRWRRR.",
        "..RRR.RRRR..",
        ".......RR...",
    ]

    static let strawberry: [String] = [
        ".....GG.....",
        "..GGGGGGGG..",
        "....GGGG....",
        "..RRRGGRRR..",
        ".RRRWRRRRRR.",
        ".RRRRRRWRRR.",
        ".RWRRRRRRRR.",
        ".RRRRWRRRRR.",
        "..RRRRRRWR..",
        "..RWRRRRRR..",
        "...RRRWRR...",
        ".....RR.....",
    ]

    static let peach: [String] = [
        "......TG....",
        ".....TGG....",
        "....GGG.....",
        "..OOOOOOO...",
        ".OOOOOOOOO..",
        ".OOOOOOOOO..",
        ".OOOOOOOOO..",
        ".OOOOOOOOO..",
        ".OOOOOOOOO..",
        "..OOOOOOO...",
        "...OOOOO....",
        "............",
    ]

    static let apple: [String] = [
        ".....T......",
        "....TT......",
        "...RRTRR....",
        "..RRRRRRR...",
        ".RRRRRRRRR..",
        ".RRRRRRRRR..",
        ".RRRRRRRRR..",
        ".RRRRRRRRW..",
        ".RRRRRRRWW..",
        "..RRRRRRW...",
        "...RR.RR....",
        "............",
    ]

    static let grapes: [String] = [
        ".....GG.....",
        "....GGGG....",
        "..B.BBBB.B..",
        ".BBBBBBBBBB.",
        ".BBWBBBBBBB.",
        ".BBBBBBWBBB.",
        "..BBBBBBBB..",
        "..BBWBBBBB..",
        "...BBBBBB...",
        "...BBBWBB...",
        "....BBBB....",
        ".....BB.....",
    ]

    static let galaxian: [String] = [
        ".....YY.....",
        ".Y...YY...Y.",
        ".YY..YY..YY.",
        ".RYY.YY.YYR.",
        ".RRYYYYYYRR.",
        ".RRRYYYYRRR.",
        "..RRYYYYRR..",
        "...RYYYYR...",
        "....YYYY....",
        "....Y..Y....",
        "...Y....Y...",
        "............",
    ]

    static let bell: [String] = [
        ".....YY.....",
        "....YYYY....",
        "...YYYYYY...",
        "...YYYYYY...",
        "..YYYYYYYY..",
        "..YYYYYYYY..",
        ".YYYYYYYYYY.",
        ".YYYYYYYYYY.",
        ".YYYYYYYYYY.",
        ".WWWWWWWWWW.",
        "....CCCC....",
        "............",
    ]

    static let key: [String] = [
        "....KKKK....",
        "...KK..KK...",
        "...KK..KK...",
        "....KKKK....",
        ".....KK.....",
        ".....KK.....",
        ".....KK.....",
        ".....KKKK...",
        ".....KK.....",
        ".....KKKK...",
        "............",
        "............",
    ]

    /// Pac-Man wedge path: full disc minus the mouth, `mouth` in radians
    /// (half-angle of the opening), facing right before rotation.
    static func pacPath(radius: CGFloat, mouth: CGFloat) -> CGPath {
        let path = CGMutablePath()
        if mouth <= 0.01 {
            path.addEllipse(in: CGRect(x: -radius, y: -radius,
                                       width: radius * 2, height: radius * 2))
            return path
        }
        path.move(to: .zero)
        path.addArc(center: .zero, radius: radius,
                    startAngle: mouth, endAngle: -mouth, clockwise: false)
        path.closeSubpath()
        return path
    }
}
