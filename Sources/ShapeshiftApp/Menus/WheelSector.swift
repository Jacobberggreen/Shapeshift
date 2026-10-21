import SwiftUI

/// An annular sector of the pie wheel. Angles: 0 = top, increasing clockwise.
struct WheelSector: Equatable {
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    var startAngle: CGFloat
    var endAngle: CGFloat

    var midAngle: CGFloat { (startAngle + endAngle) / 2 }
    var midRadius: CGFloat { (innerRadius + outerRadius) / 2 }
    var centroid: CGPoint { SectorGeometry.polar(midRadius, midAngle) }
}

/// Polar-to-screen conversion and angle helpers for wheel sectors.
enum SectorGeometry {
    /// Screen coordinates (y down), relative to the wheel centre.
    static func polar(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
        CGPoint(x: radius * sin(angle), y: -radius * cos(angle))
    }

    private static func radial(_ a: CGFloat) -> CGVector { CGVector(dx: sin(a), dy: -cos(a)) }
    private static func tangent(_ a: CGFloat) -> CGVector { CGVector(dx: cos(a), dy: sin(a)) }
    private static func neg(_ v: CGVector) -> CGVector { CGVector(dx: -v.dx, dy: -v.dy) }

    /// Closed outline with a constant-width gap (`gap`) to the neighbouring sectors and rounded corners.
    static func outline(sector: WheelSector, gap: CGFloat, cornerRadius: CGFloat) -> [CGPoint] {
        let g = gap / 2
        let inner = sector.innerRadius, outer = sector.outerRadius
        let rc = max(0, min(cornerRadius, (outer - inner) / 2))
        let dOuter = outer - rc, dInner = inner + rc
        let offOuter = asin(min(1, (g + rc) / dOuter))
        let offInner = asin(min(1, (g + rc) / dInner))
        let aOS = sector.startAngle + offOuter, aOE = sector.endAngle - offOuter
        let aIS = sector.startAngle + offInner, aIE = sector.endAngle - offInner

        var pts: [CGPoint] = []

        func corner(_ centre: CGPoint, from: CGVector, to: CGVector) {
            let a0 = atan2(from.dy, from.dx), a1 = atan2(to.dy, to.dx)
            let diff = atan2(sin(a1 - a0), cos(a1 - a0)) // (−π, π]
            let steps = 8
            for i in 0...steps {
                let a = a0 + diff * CGFloat(i) / CGFloat(steps)
                pts.append(CGPoint(x: centre.x + rc * cos(a), y: centre.y + rc * sin(a)))
            }
        }

        func arc(radius: CGFloat, from: CGFloat, to: CGFloat) {
            let n = max(2, Int((abs(to - from) / 0.03).rounded(.up)))
            for i in 1..<n { pts.append(polar(radius, from + (to - from) * CGFloat(i) / CGFloat(n))) }
        }

        corner(polar(dOuter, aOS), from: neg(tangent(sector.startAngle)), to: radial(aOS))
        arc(radius: outer, from: aOS, to: aOE)
        corner(polar(dOuter, aOE), from: radial(aOE), to: tangent(sector.endAngle))
        corner(polar(dInner, aIE), from: tangent(sector.endAngle), to: neg(radial(aIE)))
        arc(radius: inner, from: aIE, to: aIS)
        corner(polar(dInner, aIS), from: neg(radial(aIS)), to: neg(tangent(sector.startAngle)))
        return pts
    }
}

/// Shape of one wheel sector, with a gap and rounded corners.
struct SectorShape: Shape {
    var sector: WheelSector
    var gap: CGFloat = 6
    var cornerRadius: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let pts = SectorGeometry.outline(sector: sector, gap: gap, cornerRadius: cornerRadius)
        guard let first = pts.first else { return path }
        func at(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + rect.midX, y: p.y + rect.midY) }
        path.move(to: at(first))
        for p in pts.dropFirst() { path.addLine(to: at(p)) }
        path.closeSubpath()
        return path
    }
}
