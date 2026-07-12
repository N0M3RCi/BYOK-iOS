import SwiftUI

// MARK: - Constellation Canvas (Animated Particle Background)

/// Manages particle physics on a timer (like web app's requestAnimationFrame)
final class ParticleSystem: ObservableObject, @unchecked Sendable {
    struct Particle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var size: CGFloat
        let baseSize: CGFloat
        let phase: CGFloat
    }

    @Published var particles: [Particle] = []
    var canvasWidth: CGFloat = 400
    var canvasHeight: CGFloat = 800

    private let particleCount = 100
    let connectionDist: CGFloat = 180
    private var timer: Timer?
    private var lastUpdate: Date = Date()

    func start() {
        lastUpdate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastUpdate), 0.05)
        lastUpdate = now

        if particles.isEmpty {
            var newParticles: [Particle] = []
            for _ in 0..<particleCount {
                let baseSize = CGFloat.random(in: 0.8...2.8)
                newParticles.append(Particle(
                    x: CGFloat.random(in: 0...max(canvasWidth, 400)),
                    y: CGFloat.random(in: 0...max(canvasHeight, 800)),
                    vx: CGFloat.random(in: -0.25...0.25),
                    vy: CGFloat.random(in: -0.25...0.25),
                    size: baseSize,
                    baseSize: baseSize,
                    phase: CGFloat.random(in: 0...(CGFloat.pi * 2))
                ))
            }
            particles = newParticles
            return
        }

        let referenceDate = now.timeIntervalSinceReferenceDate
        let w = canvasWidth
        let h = canvasHeight

        for i in 0..<particles.count {
            var p = particles[i]
            p.vx *= CGFloat(pow(0.99, dt * 60))
            p.vy *= CGFloat(pow(0.99, dt * 60))

            p.x += p.vx * CGFloat(dt * 60)
            p.y += p.vy * CGFloat(dt * 60)

            if p.x < -20 { p.x = w + 20 }
            if p.x > w + 20 { p.x = -20 }
            if p.y < -20 { p.y = h + 20 }
            if p.y > h + 20 { p.y = -20 }

            let pulse = sin(referenceDate * 0.8 + Double(p.phase)) * 0.3 + 0.7
            p.size = p.baseSize * CGFloat(pulse)

            particles[i] = p
        }
    }
}

struct ConstellationCanvas: View {
    @StateObject private var system = ParticleSystem()

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let particles = system.particles

                // Draw particles — NO state mutations here!
                for p in particles {
                    let glowRect = CGRect(x: p.x - p.size * 4, y: p.y - p.size * 4, width: p.size * 8, height: p.size * 8)
                    context.fill(Path(ellipseIn: glowRect), with: .color(.themeYellow.opacity(0.08)))

                    let coreRect = CGRect(x: p.x - p.size, y: p.y - p.size, width: p.size * 2, height: p.size * 2)
                    context.fill(Path(ellipseIn: coreRect), with: .color(.themeYellow.opacity(0.4)))

                    if p.baseSize > 1.8 {
                        let highlightRect = CGRect(x: p.x - p.size * 0.5, y: p.y - p.size * 0.5, width: p.size, height: p.size)
                        context.fill(Path(ellipseIn: highlightRect), with: .color(.themeYellow.opacity(0.5)))
                    }
                }

                for i in 0..<particles.count {
                    for j in (i+1)..<particles.count {
                        let dx = particles[i].x - particles[j].x
                        let dy = particles[i].y - particles[j].y
                        let dist = sqrt(dx * dx + dy * dy)
                        if dist < system.connectionDist {
                            let ratio = dist / system.connectionDist
                            let alpha = (1 - ratio) * 0.2
                            var path = Path()
                            path.move(to: CGPoint(x: particles[i].x, y: particles[i].y))
                            path.addLine(to: CGPoint(x: particles[j].x, y: particles[j].y))
                            context.stroke(path, with: .color(.themeYellow.opacity(alpha * 0.4)), lineWidth: (1 - ratio) * 0.8 + 0.2)
                        }
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                system.canvasWidth = geo.size.width
                system.canvasHeight = geo.size.height
                system.start()
            }
            .onChange(of: geo.size) { newSize in
                system.canvasWidth = newSize.width
                system.canvasHeight = newSize.height
            }
            .onDisappear { system.stop() }
        }
    }
}