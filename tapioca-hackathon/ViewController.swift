//
//  ViewController.swift
//  tapioca-hackathon
//
//  Created by drama on 2019/10/06.
//  Copyright © 2019 1901drama. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity

class ViewController: UIViewController, ARSCNViewDelegate,ARSessionDelegate,SCNPhysicsContactDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    
    var myPeerID:MCPeerID!
    var participantID: MCPeerID!
    private var mpsession: MCSession!
    private var serviceAdvertiser: MCNearbyServiceAdvertiser!
    private var serviceBrowser: MCNearbyServiceBrowser!
    static let serviceType = "tapioca-hack"
    
    let configuration = ARWorldTrackingConfiguration()
    let decoder: JSONDecoder = JSONDecoder()
    let generator_light = UIImpactFeedbackGenerator(style: .light)
    let generator_heavy = UIImpactFeedbackGenerator(style: .heavy)
    
    var TouchFlg = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        myPeerID = MCPeerID(displayName: UIDevice.current.name)
        initMultipeerSession(receivedDataHandler: receivedData)
                
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.scene = SCNScene()
        sceneView.scene.physicsWorld.contactDelegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
         super.viewWillAppear(animated)
         
         configuration.planeDetection = .horizontal
          configuration.environmentTexturing = .automatic
          configuration.isCollaborationEnabled = true
          if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
              configuration.frameSemantics = .personSegmentationWithDepth
          }
          sceneView.session.run(configuration)
          
          let coachingOverlay = ARCoachingOverlayView()
          coachingOverlay.session = sceneView.session
          coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
          coachingOverlay.activatesAutomatically = true
          coachingOverlay.goal = .horizontalPlane
          sceneView.addSubview(coachingOverlay)
          
          NSLayoutConstraint.activate([
              coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
              coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
              coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
              coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
          ])
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if TouchFlg == false {
            guard let touch = touches.first else {return}
            let pos = touch.location(in: sceneView)
            let results = sceneView.hitTest(pos, types: .existingPlaneUsingExtent)
            if !results.isEmpty {
                let hitTestResult = results.first!
                let anchor = ARAnchor(name: "glass", transform: hitTestResult.worldTransform)
                sceneView.session.add(anchor: anchor)
                TouchFlg = true
            }
        }
    }
    
    
    @IBAction func tapioca(_ sender: Any) {
        let sphereGeometry = SCNSphere(radius: CGFloat(0.2))
        sphereGeometry.firstMaterial?.diffuse.contents = UIColor.black
        sphereGeometry.firstMaterial?.transparency = 0.99
        let sphereNode = SCNNode(geometry: sphereGeometry)
        
        let SphereBody = SCNPhysicsBody(type: .dynamic,shape: nil)
        SphereBody.categoryBitMask = 2
        SphereBody.contactTestBitMask = 1
        SphereBody.isAffectedByGravity = true
        sphereNode.physicsBody = SphereBody
        
        if let camera = sceneView.pointOfView {
            sphereNode.position = camera.position
            sphereNode.eulerAngles.y = camera.eulerAngles.y
            let targetPosCamera = SCNVector3Make(0, 0, -10)
            let target = camera.convertPosition(targetPosCamera, to: nil)
            let action = SCNAction.move(to: target, duration: 1.5)
            
            sphereNode.renderingOrder = 1
            sphereNode.name = "tapioca"
            sceneView.scene.rootNode.addChildNode(sphereNode)
            sphereNode.runAction(action)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            sphereNode.removeFromParentNode()
        }
        
    }
    
    
    
    // MARK: - Renderer Delegate

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if anchor.name == "glass" {

            //if anchor.sessionIdentifier == self.sceneView.session.identifier {
               
            guard let scene = SCNScene(named: "glass.scn",inDirectory: "art.scnassets") else { return }
            let glassNode = (scene.rootNode.childNode(withName: "glass", recursively: false))!
            glassNode.name = "glassNode"
                
            for chilednode in glassNode.childNodes {
                if chilednode.name == "cup" {
                    chilednode.opacity = 0.8
                    }
                }
                     
            let glassBody = SCNPhysicsBody(type: .static,shape: nil)
            glassBody.categoryBitMask = 1
            glassBody.contactTestBitMask = 2
            glassBody.collisionBitMask = 2
            //glassBody.isAffectedByGravity = false
            //glassBody.physicsShape = physicsShape

            glassNode.physicsBody = glassBody
            
            node.addChildNode(glassNode)

            //} else {
                
                
            //}


        }

        if anchor is ARParticipantAnchor {
        
            let sphereGeometry = SCNSphere(radius: CGFloat(0.4))
            sphereGeometry.firstMaterial?.diffuse.contents = UIColor.black
            sphereGeometry.firstMaterial?.transparency = 0.6
            let participantNode = SCNNode(geometry: sphereGeometry)
            
            let SphereBody = SCNPhysicsBody(type: .dynamic,shape: nil)
            SphereBody.categoryBitMask = 2
            SphereBody.contactTestBitMask = 1
            //SphereBody.collisionBitMask = 1
            SphereBody.isAffectedByGravity = false
            participantNode.physicsBody = SphereBody
            participantNode.name = "particalNode"
            
            node.addChildNode(participantNode)
        }
    }
    
    
    // MARK: - Collision

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
    
        let firstNode = contact.nodeA
        let secondNode = contact.nodeB
        
        if (firstNode.name == "glassNode" && secondNode.name == "tapioca") ||
        (secondNode.name == "tapioca" && firstNode.name == "glassNode") {
  
            print(" == shoot!!! == ","firstNode:",firstNode.name!,"secondNode:",secondNode.name!)
            
            let sphereGeometry = SCNSphere(radius: CGFloat(0.2))
            sphereGeometry.firstMaterial?.diffuse.contents = UIColor.black
            //sphereGeometry.firstMaterial?.reflective.contents = #imageLiteral(resourceName: "aqua")
            sphereGeometry.firstMaterial?.transparency = 0.99
            
            let physicsShape = SCNPhysicsShape(geometry: sphereGeometry, options: nil)
            let sphereNode = SCNNode(geometry: sphereGeometry)
            
            let SphereBody = SCNPhysicsBody(type: .dynamic,shape: nil)
            SphereBody.categoryBitMask = 1
            SphereBody.contactTestBitMask = 2
            //SphereBody.collisionBitMask = 2
            SphereBody.isAffectedByGravity = false
            SphereBody.restitution = 0.1
            SphereBody.physicsShape = physicsShape
            sphereNode.physicsBody = SphereBody
            
            firstNode.addChildNode(sphereNode)
            
            burn(secondNode,color: UIColor.brown,size: 0.00002)
            //let anchor = ARAnchor(name: "in_tapioka", transform: secondNode.position.worldTransform)
            //sceneView.session.add(anchor: anchor)
        }
    }
    
    func burn(_ node:SCNNode,color:UIColor,size:CGFloat){
        let burnNode = SCNNode()
        burnNode.position = node.position
        sceneView.scene.rootNode.addChildNode(burnNode)

        let particle = SCNParticleSystem(named: "particle/bokeh_heart.scnp", inDirectory: "")!
        let sphere = SCNSphere(radius: CGFloat(size))
        particle.emitterShape = sphere
        particle.particleColor = color
        let particleShapePosition = particle.emitterShape?.boundingSphere.center
        burnNode.pivot = SCNMatrix4MakeTranslation(particleShapePosition!.x, particleShapePosition!.y, particleShapePosition!.z)
        burnNode.addParticleSystem(particle)
        
        let scaleAction = SCNAction.scale(by: 0.2, duration: 0.1)
        let fadeAction = SCNAction.fadeOut(duration: 0.3)
        let groupAction = SCNAction.group([ scaleAction,fadeAction ])
        burnNode.runAction(groupAction)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            burnNode.removeFromParentNode();
        }
    }
    
    
    
    // MARK: - Send and Receive

    //Send collaborationData
    func session(_ session: ARSession, didOutputCollaborationData data:ARSession.CollaborationData) {
        if let collaborationDataEncoded = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true){
            self.sendToAllPeers(collaborationDataEncoded)
        }
    }

    //Receive Data
    func receivedData(_ data:Data, from peer: MCPeerID) {
        //collaborationData受信
        if let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data){
            self.sceneView.session.update(with: collaborationData)
        }
    }

    
}


// MARK: - MultipeerConnectivity

extension ViewController: MCSessionDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate{
    
    func initMultipeerSession(receivedDataHandler: @escaping (Data, MCPeerID) -> Void ) {
        mpsession = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.none)
        mpsession.delegate = self
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: ViewController.serviceType)
        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: ViewController.serviceType)
        serviceBrowser.delegate = self
        serviceBrowser.startBrowsingForPeers()
    }
    
    func sendToAllPeers(_ data: Data) {
         do {
            try mpsession.send(data, toPeers: mpsession.connectedPeers, with: .reliable)
         } catch {
            print("*** error sending data to peers: \(error.localizedDescription)")
        }
     }
    
    var connectedPeers: [MCPeerID] {
        return mpsession.connectedPeers
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        receivedData(data, from: peerID)
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected:
            print("*** estate: \(state)")
        case .connected:
            print("*** estate: \(state)")
            self.participantID = peerID
        case .connecting:
            print("*** estate: \(state)")
        @unknown default:
            fatalError()
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: mpsession, withContext: nil, timeout: 10)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, self.mpsession)
    }
    
}

