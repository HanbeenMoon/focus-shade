import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

@main
struct GeometryChecks {
    static func main() {
        let primary = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let secondary = CGRect(x: 1600, y: 50, width: 1100, height: 900)
        let frame = CGRect(x: 1470, y: 210, width: 340, height: 200)
        let geometry = ShadeGeometry(normalFrame: frame, filledFrame: nil)

        precondition(geometry.clipped(to: primary) == CGRect(x: 1470, y: 210, width: 130, height: 200))
        precondition(geometry.clipped(to: secondary) == CGRect(x: 1600, y: 210, width: 210, height: 200))
        precondition(geometry.clipped(to: CGRect(x: -900, y: 0, width: 900, height: 600)) == nil)

        let nearCorner = CGPoint(x: frame.maxX - 20, y: frame.minY + 10)
        let edges = ResizeEdges.hit(at: nearCorner, in: frame)
        precondition(edges == [.right, .bottom])
        let resized = geometry.dragged(from: nearCorner, to: CGPoint(x: nearCorner.x + 45, y: nearCorner.y - 25), edges: edges)
        precondition(resized.frame == CGRect(x: 1470, y: 185, width: 385, height: 225))

        let seam = CGPoint(x: primary.maxX, y: frame.midY)
        precondition(ResizeEdges.hit(at: seam, in: frame).isEmpty)
        let minimum = geometry.dragged(from: .zero, to: CGPoint(x: 900, y: 900), edges: [.left, .bottom])
        precondition(minimum.frame.size == ShadeGeometry.minimum)
        precondition(minimum.frame.maxX == frame.maxX && minimum.frame.maxY == frame.maxY)

        let filled = ShadeGeometry(normalFrame: frame, filledFrame: secondary)
        precondition(filled.clipped(to: secondary) == secondary)
        precondition(filled.clipped(to: primary) == nil)
        let destination = CGPoint(x: 1590, y: 520)
        let moved = filled.dragged(from: CGPoint(x: secondary.midX, y: secondary.midY), to: destination, edges: [])
        precondition(moved.filledFrame == nil && moved.frame.size == frame.size)
        precondition(moved.frame.midX == destination.x && moved.frame.midY == destination.y)
        print("Geometry checks passed.")
    }
}
