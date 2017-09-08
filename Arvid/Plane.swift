//
//  Plane.swift
//  Arvid
//
//  Created by Pär Majholm on 2017-09-08.
//  Copyright © 2017 Mayholm. All rights reserved.
//

import Foundation
import ARKit

class Plane: SCNNode {
    
    var plane: SCNNode
    
    let planeLength: Float = 3
    
    let planeWidth: Float = 1.5
    
    let selectionWidth: Float = 0.5
    
    override init() {
        let geo = SCNPlane(width: 3, height: 2)
        plane = SCNNode(geometry: geo)
        geo.firstMaterial?.transparency = 0.2
        plane.eulerAngles = SCNVector3(-Double.pi/2, 0, 0)
        super.init()
        
        self.addChildNode(plane)
        addSelections()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func insertSelectionArea(position: SCNVector3) {
        let geo = SCNPlane(width: 0.4, height: 0.4)
        let selectionNode = SCNNode(geometry: geo)
        plane.addChildNode(selectionNode)
        selectionNode.position = position
    }
    
    func addSelections() {
        
        for i in 0...11 {
            var offsetX = Float(i) * 0.5
            var positionZ: Float = -(planeWidth/2) + (0.5/2)
            if i > 4  {
                offsetX = Float(i - 5) * 0.5
                positionZ = (planeWidth/2) - (0.5/2)
            }

            let positionX = planeLength/2 - (offsetX) - 0.5
            
            let geo = SCNPlane(width: 0.4, height: 0.4)
            let node = SCNNode(geometry: geo)
            geo.firstMaterial?.diffuse.contents = UIColor.gray
            self.addChildNode(node)
            node.position = SCNVector3(positionX, 0.1, positionZ)
            node.eulerAngles = SCNVector3(-Double.pi/2, 0, 0)
        }
    }
}
