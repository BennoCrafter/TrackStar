/// The QR code of a card, module for module what backend/cards.py draws (CoreImage picks other segments and masks):
/// byte mode, error correction M, smallest version, the mask with the lowest penalty (first on ties), no quiet zone.
enum QRMatrix {
    /// Error correction level M, indexed by version.
    private static let eccPerBlock = [0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26,
                                      26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28]
    private static let blockCount = [0, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16,
                                     17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49]

    /// Dark modules, `[row][column]`.
    static func modules(_ text: String) -> [[Bool]] {
        let bytes = Array(text.utf8)
        let version = (1 ... 40).first { 4 + ($0 < 10 ? 8 : 16) + bytes.count * 8 <= dataCodewords($0) * 8 }!
        var bits: [Bool] = []
        func put(_ value: Int, _ count: Int) {
            for i in (0 ..< count).reversed() {
                bits.append(value >> i & 1 == 1)
            }
        }
        put(0b0100, 4)
        put(bytes.count, version < 10 ? 8 : 16)
        bytes.forEach { put(Int($0), 8) }
        let capacity = dataCodewords(version) * 8
        put(0, min(4, capacity - bits.count))
        put(0, (8 - bits.count % 8) % 8)
        for pad in [0xEC, 0x11].cycled(until: (capacity - bits.count) / 8) {
            put(pad, 8)
        }
        let data = stride(from: 0, to: bits.count, by: 8).map { bits[$0 ..< $0 + 8].reduce(0) { $0 << 1 | ($1 ? 1 : 0) } }

        var grid = Grid(size: version * 4 + 17)
        grid.drawFunctionPatterns(version: version)
        grid.drawCodewords(interleaved(data, version: version))
        return (0 ..< 8).map { mask in
            var masked = grid
            masked.apply(mask: mask)
            masked.drawFormatBits(mask: mask)
            return masked
        }.min { $0.penalty < $1.penalty }!.modules
    }

    private static func rawModules(_ version: Int) -> Int {
        var result = (16 * version + 128) * version + 64
        if version >= 2 {
            let align = version / 7 + 2
            result -= (25 * align - 10) * align - 55
            if version >= 7 {
                result -= 36
            }
        }
        return result
    }

    private static func dataCodewords(_ version: Int) -> Int {
        rawModules(version) / 8 - eccPerBlock[version] * blockCount[version]
    }

    /// Splits into blocks, appends Reed-Solomon codewords, interleaves.
    private static func interleaved(_ data: [Int], version: Int) -> [Int] {
        let blocks = blockCount[version], eccLength = eccPerBlock[version]
        let raw = rawModules(version) / 8
        let shortBlocks = blocks - raw % blocks, shortLength = raw / blocks
        let divisor = reedSolomonDivisor(eccLength)
        var start = 0
        let all = (0 ..< blocks).map { i in
            let length = shortLength - eccLength + (i < shortBlocks ? 0 : 1)
            let chunk = Array(data[start ..< start + length])
            start += length
            return chunk + (i < shortBlocks ? [0] : []) + reedSolomonRemainder(chunk, divisor)
        }
        return (0 ..< all[0].count).flatMap { i in
            all.indices.filter { i != shortLength - eccLength || $0 >= shortBlocks }.map { all[$0][i] }
        }
    }

    private static func reedSolomonDivisor(_ degree: Int) -> [Int] {
        var result = [Int](repeating: 0, count: degree)
        result[degree - 1] = 1
        var root = 1
        for _ in 0 ..< degree {
            for j in 0 ..< degree {
                result[j] = multiply(result[j], root)
                if j + 1 < degree {
                    result[j] ^= result[j + 1]
                }
            }
            root = multiply(root, 2)
        }
        return result
    }

    private static func reedSolomonRemainder(_ data: [Int], _ divisor: [Int]) -> [Int] {
        var result = [Int](repeating: 0, count: divisor.count)
        for byte in data {
            let factor = byte ^ result.removeFirst()
            result.append(0)
            for i in result.indices {
                result[i] ^= multiply(divisor[i], factor)
            }
        }
        return result
    }

    /// GF(2⁸) modulo x⁸ + x⁴ + x³ + x² + 1.
    private static func multiply(_ x: Int, _ y: Int) -> Int {
        var z = 0
        for i in (0 ..< 8).reversed() {
            z = (z << 1) ^ ((z >> 7) * 0x11D)
            z ^= (y >> i & 1) * x
        }
        return z
    }

    private struct Grid {
        let size: Int
        var modules: [[Bool]]
        var isFunction: [[Bool]]

        init(size: Int) {
            self.size = size
            modules = Array(repeating: Array(repeating: false, count: size), count: size)
            isFunction = modules
        }

        mutating func set(_ x: Int, _ y: Int, _ dark: Bool) {
            modules[y][x] = dark
            isFunction[y][x] = true
        }

        mutating func drawFunctionPatterns(version: Int) {
            for i in 0 ..< size {
                set(6, i, i % 2 == 0)
                set(i, 6, i % 2 == 0)
            }
            for (cx, cy) in [(3, 3), (size - 4, 3), (3, size - 4)] {
                for dy in -4 ... 4 {
                    for dx in -4 ... 4 where (0 ..< size).contains(cx + dx) && (0 ..< size).contains(cy + dy) {
                        let distance = max(abs(dx), abs(dy))
                        set(cx + dx, cy + dy, distance != 2 && distance != 4)
                    }
                }
            }
            let positions = alignmentPositions(version)
            let last = positions.count - 1
            for (i, cx) in positions.enumerated() {
                for (j, cy) in positions.enumerated() where !(i == 0 && j == 0 || i == 0 && j == last || i == last && j == 0) {
                    for dy in -2 ... 2 {
                        for dx in -2 ... 2 {
                            set(cx + dx, cy + dy, max(abs(dx), abs(dy)) != 1)
                        }
                    }
                }
            }
            drawFormatBits(mask: 0) // reserves the area; redrawn per mask
            if version >= 7 {
                var remainder = version
                for _ in 0 ..< 12 {
                    remainder = (remainder << 1) ^ ((remainder >> 11) * 0x1F25)
                }
                let bits = version << 12 | remainder
                for i in 0 ..< 18 {
                    let dark = bits >> i & 1 == 1, a = size - 11 + i % 3, b = i / 3
                    set(a, b, dark)
                    set(b, a, dark)
                }
            }
        }

        private func alignmentPositions(_ version: Int) -> [Int] {
            guard version > 1 else { return [] }
            let count = version / 7 + 2
            let step = version == 32 ? 26 : (version * 4 + count * 2 + 1) / (count * 2 - 2) * 2
            return [6] + (0 ..< count - 1).map { size - 7 - $0 * step }.reversed()
        }

        mutating func drawFormatBits(mask: Int) {
            let data = 0b00 << 3 | mask // level M
            var remainder = data
            for _ in 0 ..< 10 {
                remainder = (remainder << 1) ^ ((remainder >> 9) * 0x537)
            }
            let bits = (data << 10 | remainder) ^ 0x5412
            func bit(_ i: Int) -> Bool {
                bits >> i & 1 == 1
            }
            for i in 0 ... 5 {
                set(8, i, bit(i))
            }
            set(8, 7, bit(6))
            set(8, 8, bit(7))
            set(7, 8, bit(8))
            for i in 9 ..< 15 {
                set(14 - i, 8, bit(i))
            }
            for i in 0 ..< 8 {
                set(size - 1 - i, 8, bit(i))
            }
            for i in 8 ..< 15 {
                set(8, size - 15 + i, bit(i))
            }
            set(8, size - 8, true)
        }

        mutating func drawCodewords(_ data: [Int]) {
            var i = 0
            var right = size - 1
            while right >= 1 {
                if right == 6 {
                    right = 5
                }
                for vertical in 0 ..< size {
                    for j in 0 ..< 2 {
                        let x = right - j
                        let y = (right + 1) & 2 == 0 ? size - 1 - vertical : vertical
                        if !isFunction[y][x], i < data.count * 8 {
                            modules[y][x] = data[i >> 3] >> (7 - i & 7) & 1 == 1
                            i += 1
                        }
                    }
                }
                right -= 2
            }
        }

        mutating func apply(mask: Int) {
            for y in 0 ..< size {
                for x in 0 ..< size where !isFunction[y][x] {
                    let invert = switch mask {
                    case 0: (x + y) % 2 == 0
                    case 1: y % 2 == 0
                    case 2: x % 3 == 0
                    case 3: (x + y) % 3 == 0
                    case 4: (x / 3 + y / 2) % 2 == 0
                    case 5: x * y % 2 + x * y % 3 == 0
                    case 6: (x * y % 2 + x * y % 3) % 2 == 0
                    default: ((x + y) % 2 + x * y % 3) % 2 == 0
                    }
                    if invert {
                        modules[y][x].toggle()
                    }
                }
            }
        }

        /// Same scoring as `_penalty` in backend/cards.py.
        var penalty: Int {
            let columns = (0 ..< size).map { x in modules.map { $0[x] } }
            var score = 0
            for line in modules + columns {
                var run = 1
                for i in 1 ... size {
                    if i < size, line[i] == line[i - 1] {
                        run += 1
                        continue
                    }
                    if run >= 5 {
                        score += run - 2
                    }
                    run = 1
                }
                for pattern in [[1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0], [0, 0, 0, 0, 1, 0, 1, 1, 1, 0, 1]] {
                    for i in 0 ..< size where i + pattern.count <= size
                        && zip(line[i...], pattern).allSatisfy({ $0 == ($1 == 1) })
                    {
                        score += 40
                    }
                }
            }
            for y in 0 ..< size - 1 {
                for x in 0 ..< size - 1 {
                    let m = modules[y][x]
                    if modules[y][x + 1] == m, modules[y + 1][x] == m, modules[y + 1][x + 1] == m {
                        score += 3
                    }
                }
            }
            let dark = modules.joined().filter { $0 }.count, total = size * size
            score += ((abs(dark * 20 - total * 10) + total - 1) / total - 1) * 10
            return score
        }
    }
}

private extension Array {
    /// `[a, b].cycled(until: 5)` → `[a, b, a, b, a]`.
    func cycled(until count: Int) -> [Element] {
        (0 ..< Swift.max(count, 0)).map { self[$0 % self.count] }
    }
}
