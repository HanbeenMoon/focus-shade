import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

struct ResizeEdges: OptionSet {
    let rawValue: Int
    static let left = Self(rawValue: 1 << 0)
    static let right = Self(rawValue: 1 << 1)
    static let bottom = Self(rawValue: 1 << 2)
    static let top = Self(rawValue: 1 << 3)

    static func hit(at point: CGPoint, in rect: CGRect) -> Self {
        let grip: CGFloat = 15
        let cornerGrip: CGFloat = 26
        let leftDistance = abs(point.x - rect.minX)
        let rightDistance = abs(point.x - rect.maxX)
        let bottomDistance = abs(point.y - rect.minY)
        let topDistance = abs(point.y - rect.maxY)
        let horizontal = min(leftDistance, rightDistance)
        let vertical = min(bottomDistance, topDistance)
        var edges: Self = []
        if horizontal <= grip || (horizontal <= cornerGrip && vertical <= grip) {
            edges.insert(leftDistance < rightDistance ? .left : .right)
        }
        if vertical <= grip || (vertical <= cornerGrip && horizontal <= grip) {
            edges.insert(bottomDistance < topDistance ? .bottom : .top)
        }
        return edges
    }
}

struct ShadeGeometry {
    static let minimum = CGSize(width: 120, height: 74)
    var normalFrame: CGRect
    var filledFrame: CGRect?

    var frame: CGRect { filledFrame ?? normalFrame }

    func dragged(from start: CGPoint, to point: CGPoint, edges: ResizeEdges) -> Self {
        let dx = point.x - start.x
        let dy = point.y - start.y
        var rect = frame
        if edges.isEmpty {
            if let filledFrame {
                let relativeX = (start.x - filledFrame.minX) / filledFrame.width
                let relativeY = (start.y - filledFrame.minY) / filledFrame.height
                rect = CGRect(x: point.x - relativeX * normalFrame.width,
                              y: point.y - relativeY * normalFrame.height,
                              width: normalFrame.width, height: normalFrame.height)
            } else {
                rect = rect.offsetBy(dx: dx, dy: dy)
            }
        } else {
            if edges.contains(.left) {
                rect.origin.x = min(rect.maxX - Self.minimum.width, rect.minX + dx)
                rect.size.width = frame.maxX - rect.minX
            }
            if edges.contains(.right) {
                rect.size.width = max(Self.minimum.width, rect.width + dx)
            }
            if edges.contains(.bottom) {
                rect.origin.y = min(rect.maxY - Self.minimum.height, rect.minY + dy)
                rect.size.height = frame.maxY - rect.minY
            }
            if edges.contains(.top) {
                rect.size.height = max(Self.minimum.height, rect.height + dy)
            }
        }
        return Self(normalFrame: rect, filledFrame: nil)
    }

    func clipped(to screen: CGRect) -> CGRect? {
        let part = frame.intersection(screen)
        return part.width >= 1 && part.height >= 1 ? part : nil
    }
}
