//
//  ViewController.swift
//  ArkitPlaneDetect&PlaceObject
//
//  Created by SA on 6/20/17.
//  Copyright © 2017 SA. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

enum menuButtonState: String {
    case start = "Tap here to start AR"
    case stop = "Stop tracking more planes"
    case select = "Tap plane to select"
    case reset = "Reset"
}

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    var arState = menuButtonState.start
    var scene = SCNScene()
    var configuration = ARWorldTrackingSessionConfiguration()
    
    var planeIdentifiers = [UUID]()
    var anchors = [ARAnchor]()
    var nodes = [SCNNode]()
    var planeNodesCount = 0
    var planeHeight: CGFloat = 0.01
    var disableTracking = false
    var isPlaneSelected = false
    
    var lampNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Set the scene to the view
        self.sceneView.scene = scene
        self.sceneView.autoenablesDefaultLighting = true
        
        self.sceneView.debugOptions  = [.showConstraints, .showLightExtents, ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        
        //shows fps rate
        self.sceneView.showsStatistics = true
        
        self.sceneView.automaticallyUpdatesLighting = true
        menuButton.setTitle(arState.rawValue , for: .normal)
        setUpScenesAndNodes()
    }
    
    func setUpScenesAndNodes() {
        // load the lamp model from scene
        let tempScene = SCNScene(named: "art.scnassets/Petroleum_Lamp/Petroleum_Lamp.dae")!
        lampNode = tempScene.rootNode.childNode(withName: "Lamp", recursively: true)!
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
    
    func setSessionConfiguration(pd : ARWorldTrackingSessionConfiguration.PlaneDetection,
                                 runOPtions: ARSession.RunOptions) {
        //currenly only planeDetection available is horizontal.
        configuration.planeDetection = pd
        sceneView.session.run(configuration, options: runOPtions)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    /*Implement this to provide a custom node for the given anchor.
     
     @discussion This node will automatically be added to the scene graph.
     If this method is not implemented, a node will be automatically created.
     If nil is returned the anchor will be ignored.
     @param renderer The renderer that will render the scene.
     @param anchor The added anchor.
     @return Node that will be mapped to the anchor or nil.
     */
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        if disableTracking {
            return nil
        }
        var node:  SCNNode?
        if let planeAnchor = anchor as? ARPlaneAnchor {
            node = SCNNode()
            //            let planeGeometry = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
            let planeGeometry = SCNBox(width: CGFloat(planeAnchor.extent.x), height: planeHeight, length: CGFloat(planeAnchor.extent.z), chamferRadius: 0.0)
            planeGeometry.firstMaterial?.diffuse.contents = UIColor.green
            planeGeometry.firstMaterial?.specular.contents = UIColor.white
            let planeNode = SCNNode(geometry: planeGeometry)
            planeNode.position = SCNVector3Make(planeAnchor.center.x, Float(planeHeight / 2), planeAnchor.center.z)
            //            since SCNPlane is vertical, needs to be rotated -90 degress on X axis to make a plane
            //            planeNode.transform = SCNMatrix4MakeRotation(Float(-CGFloat.pi/2), 1, 0, 0)
            node?.addChildNode(planeNode)
            anchors.append(planeAnchor)
            
        } else {
            // haven't encountered this scenario yet
            print("not plane anchor \(anchor)")
        }
        return node
    }
    
    // Called when a new node has been mapped to the given anchor
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        planeNodesCount += 1
        if node.childNodes.count > 0 && planeNodesCount % 2 == 0 {
            node.childNodes[0].geometry?.firstMaterial?.diffuse.contents = UIColor.yellow
        }
    }
    
    // Called when a node has been updated with data from the given anchor
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if disableTracking {
            return
        }
        if let planeAnchor = anchor as? ARPlaneAnchor {
            if anchors.contains(planeAnchor) {
                if node.childNodes.count > 0 {
                    let planeNode = node.childNodes.first!
                    planeNode.position = SCNVector3Make(planeAnchor.center.x, Float(planeHeight / 2), planeAnchor.center.z)
                    if let plane = planeNode.geometry as? SCNBox {
                        plane.width = CGFloat(planeAnchor.extent.x)
                        plane.length = CGFloat(planeAnchor.extent.z)
                        plane.height = planeHeight
                    }
                }
            }
        }
    }
    
    /* Called when a mapped node has been removed from the scene graph for the given anchor.
     This delegate did not got called for every node removal in this app. Still need to rearch on what I am missing.
     */
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        print("remove node delegate called")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let location = touch.location(in: sceneView)
        
        if arState == .select {
            selectExistinPlane(location: location)
        }
        if arState == .reset && anchors.count > 0 {
            let hitResults = sceneView.hitTest(location, types: .existingPlaneUsingExtent)
            if hitResults.count > 0 {
                let result: ARHitTestResult = hitResults.first!
                
                let newLocation = SCNVector3Make(result.worldTransform.columns.3.x, result.worldTransform.columns.3.y, result.worldTransform.columns.3.z)
                let newLampNode = lampNode?.clone()
                if let newLampNode = newLampNode {
                    newLampNode.position = newLocation
                    sceneView.scene.rootNode.addChildNode(newLampNode)
                }
            }
        }
    }
    
    func selectExistinPlane(location: CGPoint) {
        let hitResults = sceneView.hitTest(location, types: .existingPlaneUsingExtent)
        if hitResults.count > 0 {
            let result: ARHitTestResult = hitResults.first!
            if let planeAnchor = result.anchor as? ARPlaneAnchor {
                for var index in 0...anchors.count - 1 {
                    if anchors[index].identifier != planeAnchor.identifier {
                        sceneView.node(for: anchors[index])?.removeFromParentNode()
                    }
                    index += 1
                }
                anchors = [planeAnchor]
                setPlaneTexture(node: sceneView.node(for: anchors[0])!)
            }
        }
        
    }
    
    func resetTapped() {
        if anchors.count > 0 {
            for index in 0...anchors.count - 1 {
                sceneView.node(for: anchors[index])?.removeFromParentNode()
            }
            anchors.removeAll()
        }
        
        for node in sceneView.scene.rootNode.childNodes {
            node.removeFromParentNode()
        }
        
    }
    
    func setPlaneTexture(node: SCNNode) {
        if let geometryNode = node.childNodes.first {
            if node.childNodes.count > 0 {
                geometryNode.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "./art.scnassets/wood.png")
                geometryNode.geometry?.firstMaterial?.locksAmbientWithDiffuse = true
                geometryNode.geometry?.firstMaterial?.diffuse.wrapS = SCNWrapMode.repeat
                geometryNode.geometry?.firstMaterial?.diffuse.wrapT = SCNWrapMode.repeat
                geometryNode.geometry?.firstMaterial?.diffuse.mipFilter = SCNFilterMode.linear
            }
            arState = menuButtonState.reset
            menuButton.setTitle(menuButtonState.reset.rawValue, for: .normal)
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            statusLabel.text = "Normal"
        case .notAvailable:
            statusLabel.text = "Not Available"
        case .limited(let reason):
            statusLabel.text = "Limited with reason: "
            switch reason {
            case .excessiveMotion:
                statusLabel.text = statusLabel.text! + "excessive camera movement"
            case .insufficientFeatures:
                statusLabel.text = statusLabel.text! + "insufficient features"
            }
            
        }
    }
    
    @IBAction func menuButtonTapped(_ sender: Any) {
        switch arState {
        case .start:
            disableTracking = false
            setSessionConfiguration(pd: ARWorldTrackingSessionConfiguration.PlaneDetection.horizontal, runOPtions: ARSession.RunOptions.resetTracking)
            arState = .stop
            menuButton.setTitle(menuButtonState.stop.rawValue, for: .normal)
            
        case .stop:
            disableTracking = true
            arState = menuButtonState.select
            menuButton.setTitle(menuButtonState.select.rawValue, for: .normal)
            
        case .select:
            arState = menuButtonState.reset
            menuButton.setTitle(menuButtonState.reset.rawValue, for: .normal)
            break
        case .reset:
            disableTracking = false
            arState = .start
            menuButton.setTitle(menuButtonState.start.rawValue, for: .normal)
            resetTapped()
            configuration = ARWorldTrackingSessionConfiguration()
            break
            
        }
    }
    
}

