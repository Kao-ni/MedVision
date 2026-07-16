import SwiftUI
import SpriteKit

struct WelcomeView: View {
    let onContinue: () -> Void

    @State private var showThai = false

    var body: some View {
        ZStack {
            Color.mvSky.ignoresSafeArea()

            BouncingFlags()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ZStack {
                    Text("hello")
                        .font(.system(size: 72, weight: .bold, design: .serif))
                        .italic()
                        .opacity(showThai ? 0 : 1)

                    Text(verbatim: "สวัสดี")
                        .font(.system(size: 60, weight: .bold))
                        .opacity(showThai ? 1 : 0)
                }
                .foregroundStyle(.white)
                .frame(height: 110)

                Text("Tap to continue")
                    .font(.system(size: 17))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onContinue)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                showThai = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Welcome to MedVision"))
        .accessibilityHint(Text("Tap to continue"))
        .accessibilityAddTraits(.isButton)
    }
}

/// A transparent physics scene gives both flags DVD-style edge bounces while
/// also letting them collide with each other and the greeting in the center.
private struct BouncingFlags: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene = FlagBounceScene()

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .onAppear { scene.isPaused = reduceMotion }
            .onChange(of: reduceMotion) { _, shouldReduceMotion in
                scene.isPaused = shouldReduceMotion
            }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private final class FlagBounceScene: SKScene {
    private let thaiFlag = FlagBounceScene.makeFlag("🇹🇭")
    private let americanFlag = FlagBounceScene.makeFlag("🇺🇸")
    private let greetingObstacle = SKNode()
    private var hasPositionedFlags = false

    override init() {
        super.init(size: .zero)
        scaleMode = .resizeFill
        backgroundColor = .clear
        physicsWorld.gravity = .zero

        addChild(greetingObstacle)
        addChild(thaiFlag)
        addChild(americanFlag)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }

        let screenEdges = SKPhysicsBody(edgeLoopFrom: CGRect(origin: .zero, size: size))
        screenEdges.friction = 0
        screenEdges.restitution = 1
        physicsBody = screenEdges

        // Match only the visible greeting. The prompt beneath it deliberately
        // remains passable so the flags can travel through "Tap to continue".
        // Use the dense letterform area rather than the font's generous line
        // height, keeping collisions visually tight around either greeting.
        let obstacleSize = CGSize(width: min(150, size.width - 32), height: 46)
        greetingObstacle.position = CGPoint(
            x: size.width / 2,
            y: size.height / 2 + 18
        )
        greetingObstacle.physicsBody = SKPhysicsBody(rectangleOf: obstacleSize)
        greetingObstacle.physicsBody?.isDynamic = false
        greetingObstacle.physicsBody?.friction = 0
        greetingObstacle.physicsBody?.restitution = 1

        guard !hasPositionedFlags else { return }
        hasPositionedFlags = true

        thaiFlag.position = CGPoint(x: size.width * 0.22, y: size.height * 0.76)
        thaiFlag.physicsBody?.velocity = CGVector(dx: 112, dy: -91)

        americanFlag.position = CGPoint(x: size.width * 0.78, y: size.height * 0.24)
        americanFlag.physicsBody?.velocity = CGVector(dx: -96, dy: 118)
    }

    private static func makeFlag(_ emoji: String) -> SKLabelNode {
        let flag = SKLabelNode(text: emoji)
        flag.fontName = "AppleColorEmoji"
        flag.fontSize = 64
        flag.horizontalAlignmentMode = .center
        flag.verticalAlignmentMode = .center

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 72, height: 52))
        body.affectedByGravity = false
        body.allowsRotation = false
        body.friction = 0
        body.linearDamping = 0
        body.restitution = 1
        body.usesPreciseCollisionDetection = true
        flag.physicsBody = body

        return flag
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
