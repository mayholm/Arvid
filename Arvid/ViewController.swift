//
//  ViewController.swift
//  Arvid
//
//  Created by Pär Majholm on 2017-09-08.
//  Copyright © 2017 Mayholm. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, GameEnginePointsDelegate {
    @IBOutlet weak var goldLabel: UILabel!
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    
    @IBOutlet var sceneView: ARSCNView!
    
    var dragOnInfinitePlanesEnabled = false
    
    let session = ARSession()
    let configuration: ARConfiguration = ARWorldTrackingConfiguration()
    
    let world = World()
    
    var initGame = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session = session
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        world.isHidden = true
        
      
        DispatchQueue.main.async {
            self.screenCenter = self.sceneView.bounds.mid
        }
        
        scene.rootNode.addChildNode(world)
        
        // FocusSquare
        setupFocusSquare()
        focusSquare?.isHidden = false
        
        GameEngine.sharedInstance.pointsDelegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        if let worldSessionConfig = configuration as? ARWorldTrackingConfiguration {
            worldSessionConfig.planeDetection = .horizontal
            worldSessionConfig.isLightEstimationEnabled = true
            session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*
     // Override to create and configure nodes for anchors added to the view's session.
     func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
     let node = SCNNode()
     
     return node
     }
     */
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.updateFocusSquare()
        }
        if GameEngine.sharedInstance.isPlaying{
            
            for updatable in self.world.updatables {
                updatable.update(time: time)
            }
        }
    }
    
    @IBAction func startPressed(_ sender: Any) {
        if GameEngine.sharedInstance.isPlaying{
            GameEngine.sharedInstance.pauseEngine()
        }else{
            if GameEngine.sharedInstance.hasStartedFirstGame{
                GameEngine.sharedInstance.resumeEngine()
            }else{
                GameEngine.sharedInstance.startGame()
            }
        }
    }
    
    @IBAction func tapped(_ sender: UITapGestureRecognizer) {
        let point = sender.location(in: self.view)
          if !initGame {
            let planeHitTestResults = sceneView.hitTest(point, types: .existingPlaneUsingExtent)
            if let result = planeHitTestResults.first {
                focusSquare?.hide()
                world.isHidden = false
                let transform = result.worldTransform
                world.position = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
                initGame = true
            }
          } else {
            var hitTestOptions = [SCNHitTestOption: Any]()
            hitTestOptions[SCNHitTestOption.boundingBoxOnly] = true
            
            let results: [SCNHitTestResult] = sceneView.hitTest(point, options: hitTestOptions)
            for result in results {
                if let name = result.node.name, name.contains("selection") {
                    world.addTower(selectionName: name)
                }
            }
        }
    }
    
    var focusSquare: FocusSquare?

    var screenCenter: CGPoint?
    
    func setupFocusSquare() {
        focusSquare?.isHidden = true
        focusSquare?.removeFromParentNode()
        focusSquare = FocusSquare()
        sceneView.scene.rootNode.addChildNode(focusSquare!)
    }
    
    func updateFocusSquare() {
        guard let screenCenter = screenCenter else { return }
        if world.isHidden != true {
            focusSquare?.hide()
        } else {
            focusSquare?.unhide()
            let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: focusSquare?.position)
            if let worldPos = worldPos {
                focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
            }
        }
    }
    
    func worldPositionFromScreenPosition(_ position: CGPoint,
                                         objectPos: SCNVector3?,
                                         infinitePlane: Bool = false) -> (position: SCNVector3?, planeAnchor: ARPlaneAnchor?, hitAPlane: Bool){
        
        // -------------------------------------------------------------------------------
        // 1. Always do a hit test against exisiting world anchors first.
        //    (If any such anchors exist & only within their extents.)
        
        let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
        if let result = planeHitTestResults.first {
            
            let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
            let planeAnchor = result.anchor
            
            // Return immediately - this is the best possible outcome.
            return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
        }
        
        // -------------------------------------------------------------------------------
        // 2. Collect more information about the environment by hit testing against
        //    the feature point cloud, but do not return the result yet.
        
        var featureHitTestPosition: SCNVector3?
        var highQualityFeatureHitTestResult = false
        
        let highQualityfeatureHitTestResults = sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)
        
        if !highQualityfeatureHitTestResults.isEmpty {
            let result = highQualityfeatureHitTestResults[0]
            featureHitTestPosition = result.position
            highQualityFeatureHitTestResult = true
        }
        
        // -------------------------------------------------------------------------------
        // 3. If desired or necessary (no good feature hit test result): Hit test
        //    against an infinite, horizontal plane (ignoring the real world).
        
        if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {
            
            let pointOnPlane = objectPos ?? SCNVector3Zero
            
            let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
            if pointOnInfinitePlane != nil {
                return (pointOnInfinitePlane, nil, true)
            }
        }
        
        // -------------------------------------------------------------------------------
        // 4. If available, return the result of the hit test against high quality
        //    features if the hit tests against infinite planes were skipped or no
        //    infinite plane was hit.
        
        if highQualityFeatureHitTestResult {
            return (featureHitTestPosition, nil, false)
        }
        
        // -------------------------------------------------------------------------------
        // 5. As a last resort, perform a second, unfiltered hit test against features.
        //    If there are no features in the scene, the result returned here will be nil.
        
        let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
        if !unfilteredFeatureHitTestResults.isEmpty {
            let result = unfilteredFeatureHitTestResults[0]
            return (result.position, nil, false)
        }
        
        return (nil, nil, false)
    }
    
    //MARK: GameEnginePointsDelegate
    func pointsValueUpdated(points: Int) {
        self.pointsLabel.text = "\(points) points"
    }
    
    func goldValueUpdated(gold: Int) {
        self.goldLabel.text = "\(gold) gold"
    }
    
    func gameDidStart() {
        //Change start button to stop button?
        self.startButton.setTitle("Stop", for: .normal)
        
    }
    
    func gameEngineDidPause() {
        //Change stop button to start button?
        self.startButton.setTitle("Start", for: .normal)
    }
}

extension UIViewController: SCNPhysicsContactDelegate {
    
    public func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
    }
}
