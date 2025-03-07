import Foundation

/// Extend Int to conform to Comparable for comparison with TimeInterval
public extension Int {
    static func <(lhs: Int, rhs: TimeInterval) -> Bool {
        return TimeInterval(lhs) < rhs
    }

    static func <=(lhs: Int, rhs: TimeInterval) -> Bool {
        return TimeInterval(lhs) <= rhs
    }

    static func >(lhs: Int, rhs: TimeInterval) -> Bool {
        return TimeInterval(lhs) > rhs
    }

    static func >=(lhs: Int, rhs: TimeInterval) -> Bool {
        return TimeInterval(lhs) >= rhs
    }

    static func ==(lhs: Int, rhs: TimeInterval) -> Bool {
        return TimeInterval(lhs) == rhs
    }
}

/// Extend TimeInterval to conform to Comparable for comparison with Int
public extension TimeInterval {
    static func <(lhs: TimeInterval, rhs: Int) -> Bool {
        return lhs < TimeInterval(rhs)
    }

    static func <=(lhs: TimeInterval, rhs: Int) -> Bool {
        return lhs <= TimeInterval(rhs)
    }

    static func >(lhs: TimeInterval, rhs: Int) -> Bool {
        return lhs > TimeInterval(rhs)
    }

    static func >=(lhs: TimeInterval, rhs: Int) -> Bool {
        return lhs >= TimeInterval(rhs)
    }

    static func ==(lhs: TimeInterval, rhs: Int) -> Bool {
        return lhs == TimeInterval(rhs)
    }
}
