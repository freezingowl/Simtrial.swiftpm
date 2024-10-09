import SwiftUI
import SpriteKit
import AVFoundation  // Add this import

@MainActor
class GameScene: SKScene, SKPhysicsContactDelegate {
    private var balls: [SKShapeNode] = []
    private(set) var isMoving = false
    private let ballRadius: CGFloat = 10
    private let ballCategoryBitMask: UInt32 = 0x1 << 0
    private let wallCategoryBitMask: UInt32 = 0x1 << 1
    private let holeCategoryBitMask: UInt32 = 0x1 << 2
    private(set) var elapsedTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval?
    private let initialSpeed: CGFloat = 600
    private let maxSpeed: CGFloat = 10000
    private let speedIncreaseFactor: CGFloat = 1.01
    private(set) var redScore: Int = 0
    private(set) var greenScore: Int = 0
    private let gameDuration: TimeInterval = 30.0
    private(set) var isGameOver: Bool = false
    private var bounceSound: SKAction?
    var isGapWidening: Bool = false
    private var gapWidth: CGFloat
    private let initialGapWidth: CGFloat
    private var gapWidenFactor: CGFloat = 1.1
    private var maxGapWidth: CGFloat
    private var gapWideningSpeed: CGFloat = 1.0
    private var gapNarrowingSpeed: CGFloat = 0.5

    override init(size: CGSize) {
        self.initialGapWidth = self.ballRadius * 2.5
        self.gapWidth = self.initialGapWidth
        self.maxGapWidth = size.width * 0.8 // 80% of screen width
        super.init(size: size)
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.initialGapWidth = 25 // Assuming ballRadius is 10
        self.gapWidth = self.initialGapWidth
        self.maxGapWidth = 240 // Assuming screen width is 300
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        backgroundColor = .white
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        createWalls()
        
        // Create one red ball and one green ball
        createBall(color: .red)
        createBall(color: .green)
        
        // Set up bounce sound
        bounceSound = SKAction.playSoundFileNamed("Montagem Mysterious Game start 7.mp3", waitForCompletion: false)
    }
    
    private func createBall(color: UIColor) {
        let ball = SKShapeNode(circleOfRadius: ballRadius)
        ball.fillColor = color
        ball.position = CGPoint(x: CGFloat.random(in: ballRadius...(size.width - ballRadius)),
                                y: CGFloat.random(in: ballRadius...(size.height - ballRadius)))
        ball.physicsBody = SKPhysicsBody(circleOfRadius: ballRadius)
        ball.physicsBody?.restitution = 1
        ball.physicsBody?.friction = 0
        ball.physicsBody?.linearDamping = 0
        ball.physicsBody?.affectedByGravity = false
        ball.physicsBody?.allowsRotation = false
        ball.physicsBody?.categoryBitMask = ballCategoryBitMask
        ball.physicsBody?.contactTestBitMask = wallCategoryBitMask | holeCategoryBitMask | ballCategoryBitMask
        ball.physicsBody?.collisionBitMask = wallCategoryBitMask | ballCategoryBitMask
        addChild(ball)
        balls.append(ball)
    }
    
    private func createWalls() {
        let gapCenter = size.width / 2
        
        let leftWall = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 1, height: size.height))
        let rightWall = SKShapeNode(rect: CGRect(x: size.width - 1, y: 0, width: 1, height: size.height))
        let bottomWall = SKShapeNode(rect: CGRect(x: 0, y: 0, width: size.width, height: 1))
        
        for wall in [leftWall, rightWall, bottomWall] {
            wall.fillColor = .black
            wall.strokeColor = .black
            wall.physicsBody = SKPhysicsBody(edgeLoopFrom: wall.frame)
            wall.physicsBody?.isDynamic = false
            wall.physicsBody?.restitution = 1
            wall.physicsBody?.friction = 0
            wall.physicsBody?.categoryBitMask = wallCategoryBitMask
            addChild(wall)
        }

        updateTopWalls()
    }
    
    func updateTopWalls() {
        // Remove existing top walls and hole
        children.filter { $0.name == "topWall" || $0.name == "topHole" }.forEach { $0.removeFromParent() }

        let gapCenter = size.width / 2
        let currentGapWidth = isGapWidening ? gapWidth : initialGapWidth
        
        let topLeftWall = SKShapeNode(rect: CGRect(x: 0, y: size.height - 1, width: gapCenter - currentGapWidth / 2, height: 1))
        let topRightWall = SKShapeNode(rect: CGRect(x: gapCenter + currentGapWidth / 2, y: size.height - 1, width: size.width - (gapCenter + currentGapWidth / 2), height: 1))
        
        for wall in [topLeftWall, topRightWall] {
            wall.fillColor = .black
            wall.strokeColor = .black
            wall.physicsBody = SKPhysicsBody(edgeLoopFrom: wall.frame)
            wall.physicsBody?.isDynamic = false
            wall.physicsBody?.restitution = 1
            wall.physicsBody?.friction = 0
            wall.physicsBody?.categoryBitMask = wallCategoryBitMask
            wall.name = "topWall"
            addChild(wall)
        }

        let topGap = SKShapeNode(rect: CGRect(x: gapCenter - currentGapWidth / 2, y: size.height - 3, width: currentGapWidth, height: 3))
        topGap.fillColor = .red
        topGap.strokeColor = .red
        topGap.name = "topWall"
        addChild(topGap)

        let topHole = SKNode()
        topHole.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: gapCenter - currentGapWidth / 2, y: size.height),
                                            to: CGPoint(x: gapCenter + currentGapWidth / 2, y: size.height))
        topHole.physicsBody?.isDynamic = false
        topHole.physicsBody?.categoryBitMask = holeCategoryBitMask
        topHole.name = "topHole"
        addChild(topHole)
    }
    
    private func widenGap() {
        if isGapWidening {
            gapWidth = min(gapWidth * gapWidenFactor, maxGapWidth)
        } else {
            gapWidth = max(gapWidth / gapWidenFactor, initialGapWidth)
        }
        updateTopWalls()
    }
    
    func startMoving() {
        isMoving = true
        isGameOver = false
        redScore = 0
        greenScore = 0
        elapsedTime = 0
        lastUpdateTime = nil
        gapWidth = initialGapWidth
        updateTopWalls()
        for ball in balls {
            resetBall(ball)
        }
    }
    
    func stopMoving() {
        isMoving = false
        for ball in balls {
            ball.physicsBody?.velocity = .zero
        }
    }
    
    nonisolated func didBegin(_ contact: SKPhysicsContact) {
        let bodyACategory = contact.bodyA.categoryBitMask
        let bodyBCategory = contact.bodyB.categoryBitMask
        let nodeA = contact.bodyA.node
        let nodeB = contact.bodyB.node

        Task { [weak self] in
            await self?.handleContact(bodyACategory: bodyACategory, bodyBCategory: bodyBCategory, nodeA: nodeA, nodeB: nodeB)
        }
    }

    private func handleContact(bodyACategory: UInt32, bodyBCategory: UInt32, nodeA: SKNode?, nodeB: SKNode?) {
        if isMoving {
            // Play bounce sound
            if let bounceSound = bounceSound {
                run(bounceSound)
            }
            
            if bodyACategory == holeCategoryBitMask || bodyBCategory == holeCategoryBitMask {
                if let ball = (nodeA as? SKShapeNode) ?? (nodeB as? SKShapeNode),
                   balls.contains(ball) {
                    incrementScore(for: ball)
                    resetBall(ball)
                    widenGap()
                }
            } else {
                // Increase speed for ball-wall or ball-ball collisions
                if bodyACategory == ballCategoryBitMask {
                    increaseSpeed(for: nodeA as? SKShapeNode)
                }
                if bodyBCategory == ballCategoryBitMask {
                    increaseSpeed(for: nodeB as? SKShapeNode)
                }
            }
        }
    }

    private func incrementScore(for ball: SKShapeNode) {
        if ball.fillColor == .red {
            redScore += 1
        } else if ball.fillColor == .green {
            greenScore += 1
        }
    }

    private func increaseSpeed(for ball: SKShapeNode?) {
        guard let ball = ball, let physicsBody = ball.physicsBody else { return }
        
        let currentVelocity = physicsBody.velocity
        let currentSpeed = sqrt(currentVelocity.dx * currentVelocity.dx + currentVelocity.dy * currentVelocity.dy)
        let newSpeed = min(currentSpeed * speedIncreaseFactor, maxSpeed)
        
        if currentSpeed > 0 {
            let newVelocity = CGVector(dx: currentVelocity.dx / currentSpeed * newSpeed,
                                       dy: currentVelocity.dy / currentSpeed * newSpeed)
            physicsBody.velocity = newVelocity
        }
    }

    private func resetBall(_ ball: SKShapeNode) {
        ball.position = CGPoint(x: CGFloat.random(in: ballRadius...(size.width - ballRadius)),
                                y: CGFloat.random(in: ballRadius...(size.height - ballRadius)))
        let angle = CGFloat.random(in: 0...2 * .pi)
        ball.physicsBody?.velocity = CGVector(dx: cos(angle) * initialSpeed, dy: sin(angle) * initialSpeed)
    }
    
    private func multiplyVector(_ vector: CGVector, by scalar: CGFloat) -> CGVector {
        return CGVector(dx: vector.dx * scalar, dy: vector.dy * scalar)
    }
    
    override func update(_ currentTime: TimeInterval) {
        if isMoving && !isGameOver {
            if let lastUpdateTime = lastUpdateTime {
                elapsedTime += currentTime - lastUpdateTime
            }
            lastUpdateTime = currentTime
            
            if elapsedTime >= gameDuration {
                isGameOver = true
                stopMoving()
            }
            
            for ball in balls {
                var position = ball.position
                position.x = min(max(position.x, ballRadius), size.width - ballRadius)
                position.y = min(max(position.y, ballRadius), size.height - ballRadius)
                ball.position = position
            }

            // Gradually widen or narrow the gap
            if isGapWidening {
                gapWidth = min(gapWidth + gapWideningSpeed, maxGapWidth)
            } else {
                gapWidth = max(gapWidth - gapNarrowingSpeed, initialGapWidth)
            }
            updateTopWalls()
        } else {
            lastUpdateTime = nil
        }
    }

    func setGapWideningFactor(_ factor: CGFloat) {
        gapWidenFactor = max(1.0, factor)
    }

    func setMaxGapWidth(_ width: CGFloat) {
        maxGapWidth = min(max(width, initialGapWidth), size.width)
    }

    func setGapWideningSpeed(_ speed: CGFloat) {
        gapWideningSpeed = max(0.1, speed)
    }

    func setGapNarrowingSpeed(_ speed: CGFloat) {
        gapNarrowingSpeed = max(0.1, speed)
    }
}

extension CGVector {
    func normalized() -> CGVector {
        let length = sqrt(dx * dx + dy * dy)
        return CGVector(dx: dx / length, dy: dy / length)
    }
}

class CircularSimulationScene: SKScene {
    private var ball: SKShapeNode?
    private var boundary: SKShapeNode?
    private let ballRadius: CGFloat = 10
    private let initialSpeed: CGFloat = 300

    override func didMove(to view: SKView) {
        backgroundColor = .white
        physicsWorld.gravity = .zero
        
        createBoundary()
        createBall()
    }
    
    private func createBoundary() {
        let size = min(self.size.width, self.size.height) - ballRadius * 2
        let radius = size / 2
        
        boundary = SKShapeNode(circleOfRadius: radius)
        boundary?.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        boundary?.strokeColor = .black
        boundary?.lineWidth = 2
        
        let physicsBody = SKPhysicsBody(circleOfRadius: radius)
        physicsBody.isDynamic = false
        boundary?.physicsBody = physicsBody
        
        addChild(boundary!)
    }
    
    private func createBall() {
        ball = SKShapeNode(circleOfRadius: ballRadius)
        ball?.fillColor = .blue
        ball?.position = CGPoint(x: size.width / 2, y: size.height / 2)
        
        let physicsBody = SKPhysicsBody(circleOfRadius: ballRadius)
        physicsBody.affectedByGravity = false
        physicsBody.linearDamping = 0
        physicsBody.restitution = 1
        physicsBody.friction = 0
        ball?.physicsBody = physicsBody
        
        addChild(ball!)
        
        // Set initial velocity
        let angle = CGFloat.random(in: 0...2 * .pi)
        ball?.physicsBody?.velocity = CGVector(dx: cos(angle) * initialSpeed, dy: sin(angle) * initialSpeed)
    }
}

struct ContentView: View {
    @State private var currentSimulation = 0
    
    var scenes: [SKScene] {
        let squareScene = GameScene(size: CGSize(width: 300, height: 300))
        squareScene.scaleMode = .resizeFill
        
        let circleScene = CircularSimulationScene(size: CGSize(width: 300, height: 300))
        circleScene.scaleMode = .resizeFill
        
        return [squareScene, circleScene]
    }
    
    var body: some View {
        VStack {
            TabView(selection: $currentSimulation) {
                ForEach(0..<scenes.count, id: \.self) { index in
                    SpriteView(scene: scenes[index])
                        .frame(width: 300, height: 300)
                        .border(Color.blue, width: 2)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 320)
            
            Text(currentSimulation == 0 ? "Square Simulation" : "Circle Simulation")
                .font(.headline)
                .padding()
        }
    }
}