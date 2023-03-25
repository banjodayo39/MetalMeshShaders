//
//  MetalShaderController.swift
//  MetalMeshShaders
//
//  Created by Dayo Banjo on 3/21/23.
//
import UIKit
import MetalKit

class MetalShaderController: UIViewController, MTKViewDelegate {
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var renderer: MeshShaderRenderer!
    var mtkView: MTKView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        let mtkView = MTKView(frame: view.bounds, device: device)
        mtkView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mtkView)
        
        self.mtkView = mtkView
        self.mtkView.delegate = self
        
        renderer = MeshShaderRenderer(device: device, commandQueue: commandQueue, view: mtkView)
        
        guard let assetURL = Bundle.main.url(forResource: "dragon", withExtension: "mbemesh") else {
            fatalError("Could not find mesh asset")
        }
        renderer.mesh = MSMesh(with: assetURL, device: device)
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
       // renderer.viewport = MTLViewport(originX: 0, originY: 0, width: Double(size.width), height: Double(size.height), znear: 0, zfar: 1)
    }
    
    func draw(in view: MTKView) {
        guard let renderPass = view.currentRenderPassDescriptor else {
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        guard let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            return
        }
        
        renderer.draw(renderCommandEncoder: renderCommandEncoder)
        
        renderCommandEncoder.endEncoding()
        commandBuffer.present(view.currentDrawable!)
        commandBuffer.commit()
    }
}
