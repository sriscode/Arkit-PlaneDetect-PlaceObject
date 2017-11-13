//
//  ViewController.swift
//  ArkitPlaneDetect&PlaceObject
//
//  Created by SA on 6/20/17.
//  Copyright © 2017 Sris. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var cameraStatusLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!

    var configuration : ARWorldTrackingConfiguration?
    let planeIdentifiers = [UUID]()
    var anchors = [ARAnchor]()
    var nodes = [SCNNode]()
    // keep track of number of anchor nodes that are added into the scene
    var planeNodesCount = 0
    let planeHeight: CGFloat = 0.01
    // set isPlaneSelected to true when user taps on the anchor plane to select.
    var isPlaneSelected = false
    // set isSessionPaused to true when user taps on Pause button
    var isSessionPaused = false
    
    // lampNode holds the object from scene. Clone this object and place it on the tapped location on the selected plane
    var lampNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeSceneView()
        initializeMenuButtonStatus()
        loadNodeObject()
        initiateTracking()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseSession()
    }
    
    func initializeSceneView() {
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create new scene and attach the scene to the sceneView
        sceneView.scene = SCNScene()
        
        sceneView.autoenablesDefaultLighting = true
        
        // Add the SCNDebugOptions options
        // showConstraints, showLightExtents are SCNDebugOptions
        // showFeaturePoints and showWorldOrigin are ARSCNDebugOptions
        sceneView.debugOptions  = [SCNDebugOptions.showConstraints, SCNDebugOptions.showLightExtents, ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        
        //shows fps rate
        sceneView.showsStatistics = true
        
        sceneView.automaticallyUpdatesLighting = true
    }
    
    func loadNodeObject() {
        // get access to scene from scene assets and parse for the lamp model 
        let tempScene = SCNScene(named: "art.scnassets/Petroleum_Lamp/Petroleum_Lamp.dae")!
        lampNode = tempScene.rootNode.childNode(withName: "Lamp", recursively: true)!
    }
    
    func startSession() {
        configuration = ARWorldTrackingConfiguration()
        //currenly only planeDetection available is horizontal.
        configuration!.planeDetection = ARWorldTrackingConfiguration.PlaneDetection.horizontal
        sceneView.session.run(configuration!, options: [ARSession.RunOptions.removeExistingAnchors,
                                                       ARSession.RunOptions.resetTracking])
        
    }
    
    func pauseSession() {
        sceneView.session.pause()
    }
    
    func continueSession() {
        sceneView.session.run(configuration!)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first!
        let location = touch.location(in: sceneView)
        if !isPlaneSelected {
            selectExistingPlane(location: location)
        } else {
            addNodeAtLocation(location: location)
        }
    }
    
    // selects the anchor at the specified location and removes all other unused anchors
    func selectExistingPlane(location: CGPoint) {
        // Hit test result from intersecting with an existing plane anchor, taking into account the plane’s extent.
        let hitResults = sceneView.hitTest(location, types: .existingPlaneUsingExtent)
        if hitResults.count > 0 {
            let result: ARHitTestResult = hitResults.first!
            if let planeAnchor = result.anchor as? ARPlaneAnchor {
                for var index in 0...anchors.count - 1 {
                    // remove all the nodes from the scene except for the one that is selected
                    if anchors[index].identifier != planeAnchor.identifier {
                        sceneView.node(for: anchors[index])?.removeFromParentNode()
                        sceneView.session.remove(anchor: anchors[index])
                    }
                    index += 1
                }
                // keep track of selected anchor only
                anchors = [planeAnchor]
                // set isPlaneSelected to true
                isPlaneSelected = true
                setPlaneTexture(node: sceneView.node(for: planeAnchor)!)
            }
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
        }
    }
    
    // checks if anchors are already created. If created, clones the node and adds it the anchor at the specified location
    func addNodeAtLocation(location: CGPoint) {
        guard anchors.count > 0 else {
            print("anchors are not created yet")
            return
        }
        
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
    
    // removes all the nodes, anchors and resets the isPlaneSelected to false
    func reset() {
        isPlaneSelected = false
        isSessionPaused = false
        planeNodesCount = 0
        if anchors.count > 0 {
            for index in 0...anchors.count - 1 {
                sceneView.node(for: anchors[index])?.removeFromParentNode()
            }
        }
        anchors.removeAll()
        for node in sceneView.scene.rootNode.childNodes {
            node.removeFromParentNode()
        }
    }
    
    
    // MARK: session delegates
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
            cameraStatusLabel.text = "Normal"
        case .notAvailable:
            cameraStatusLabel.text = "Not Available"
        case .limited(let reason):
            cameraStatusLabel.text = "Limited with reason: "
            switch reason {
            case .excessiveMotion:
                cameraStatusLabel.text = cameraStatusLabel.text! + "excessive camera movement"
            case .insufficientFeatures:
                cameraStatusLabel.text = cameraStatusLabel.text! + "insufficient features"
            case .initializing:
                cameraStatusLabel.text = cameraStatusLabel.text! + "camera initializing in progress"
            }
            
        }
    }
    
    // MARK: Menu Buttons' Status and Actions
    func initializeMenuButtonStatus() {
        pauseButton.isHidden = false
        resetButton.isHidden = false
        infoLabel.text = ""
        pauseButton.setTitle("Pause", for: .normal)
    }
    
    func initiateTracking() {
        // information to "select plane and tap on plane to place object" is visible for 10 seconds
        infoLabel.text = "Once planes are detected, tap on any of the plane to select and then tap on the selected plane to place objects"
        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { (s) in
            DispatchQueue.main.async {
                self.infoLabel.text = ""
            }
        }
        startSession()
    }
    
    @IBAction func pauseButtonTapped(_ sender: Any) {
        pauseButton.isHidden = false
        resetButton.isHidden = false
        
        // toggle button title to continue or pause
        let buttonTitle = isSessionPaused ? "Pause" : "Continue"
        self.pauseButton.setTitle(buttonTitle, for: .normal)
      
        if isSessionPaused {
            isSessionPaused = false
            continueSession()
        } else {
            isSessionPaused = true
            pauseSession()
        }
        
    }
    
    @IBAction func resetButtonTapped(_ sender: Any) {
        pauseButton.isHidden = false
        resetButton.isHidden = false
        pauseButton.setTitle("Pause", for: .normal)
        infoLabel.text = ""
        reset()
        initiateTracking()
    }
    
   
    
}

