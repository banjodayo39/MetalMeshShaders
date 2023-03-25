//
//  MeshShaderRenderer.swift
//  MetalMeshShaders
//
//  Created by Dayo Banjo on 3/21/23.
//

import Foundation
import simd
import Metal
import MetalKit
import simd

class MeshShaderRenderer {
    private var depthStencilState: MTLDepthStencilState?
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var viewport: MTLViewport
    private var meshRenderPipeline: MTLRenderPipelineState?
    var mesh: MSMesh?
    var time: Float = 0
  var resolution: Float = 0.7
  var buffer : MTLBuffer!
  
  struct Constants {
    var animatedBy: Float = 0.0
    var resolution = simd_float2(repeating: 0)
  }
  
  var constant: Constants = Constants()
    
    init(device: MTLDevice, commandQueue: MTLCommandQueue, view: MTKView) {
        self.device = device
        self.commandQueue = commandQueue
        self.viewport = MTLViewport(originX: 0.0, originY: 0.0, width: Double(view.drawableSize.width), height: Double(view.drawableSize.height), znear: 0.0, zfar: 1.0)
        view.depthStencilPixelFormat = .depth32Float
        self.makeMeshRenderPipeline(with: view)
      let screenSize = UIScreen.main.bounds.size
      let screenScale = UIScreen.main.scale
      let resolution = simd_float2(Float(screenSize.width * screenScale), Float(screenSize.height * screenScale))
      constant.resolution = resolution
      buffer = device.makeBuffer(bytes: &constant, length: MemoryLayout<Constants>.stride, options: [])

    }
    
    private func makeMeshRenderPipeline(with view: MTKView) {
        var error: NSError?
        
        guard let library = device.makeDefaultLibrary() else {
            return
        }
        
        guard let objectFunction = library.makeFunction(name: "object_main"),
              let meshFunction = library.makeFunction(name: "mesh_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            return
        }
        
        let pipelineDescriptor = MTLMeshRenderPipelineDescriptor()        
        pipelineDescriptor.objectFunction = objectFunction
        pipelineDescriptor.meshFunction = meshFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        let stateDescriptor = MTLRenderPipelineStateProvider2()
        stateDescriptor.mtDevice = MTLCreateSystemDefaultDevice()!
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        
        let options: MTLPipelineOption = []
        do {
            
            meshRenderPipeline =  try stateDescriptor.newShaderRenderPipelineState(withMeshDescriptor: pipelineDescriptor, options: options, reflection: nil) 
            
        } catch let pipelineError as NSError {
            error = pipelineError
        }
        
        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: depthDescriptor)

    }

    func draw(renderCommandEncoder: MTLRenderCommandEncoder) {
        guard let mesh = self.mesh,
              let meshRenderPipeline = meshRenderPipeline
        else {
            return
        }
        time += 1 / Float(60)
      constant.animatedBy = abs(sin(time)/2 + 0.5)
      
        renderCommandEncoder.setDepthStencilState(self.depthStencilState)
        renderCommandEncoder.setRenderPipelineState(meshRenderPipeline)
    
        renderCommandEncoder.setFrontFacing(.counterClockwise)
        renderCommandEncoder.setCullMode(.back)
        
        let maxMeshThreads = max(mesh.meshletMaxVertexCount, mesh.meshletMaxTriangleCount)
        
        let vertexBuffer = mesh.vertexBuffers.first!
        renderCommandEncoder.setMeshBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 0)
      renderCommandEncoder.setFragmentBuffer(buffer, offset: 0, index: 5)

        renderCommandEncoder.setMeshBuffer(mesh.meshletVertexBuffer.buffer, offset:0, index: 2)
        
        let aspect = self.viewport.width / self.viewport.height
                
        let modelMatrix = simd_float4x4_rotation_axis_angle(axisX: 0, axisY: 1, axisZ: 0, angle: time)
        
        let viewMatrix = simd_float4x4_translation(tx: 0, ty: -0.5, tz: -2.0)
        let projectionMatrix = simd_float4x4_perspective_rh(fovyRadians: 65.0 * (Float.pi / 180), aspect: Float(aspect), nearZ: 0.1, farZ: 150.0)
        let modelViewMatrix = viewMatrix * modelMatrix
        let mvpMatrix = projectionMatrix * modelViewMatrix
        let normalMatrix = simd_inverse(simd_transpose(modelViewMatrix))
        
        var instance = InstanceData(
            modelViewProjectionMatrix: mvpMatrix,
            inverseModelViewMatrix: simd_inverse(modelViewMatrix),
            normalMatrix: normalMatrix
        )
        
        renderCommandEncoder.setObjectBytes(&instance, length: MemoryLayout<InstanceData>.stride, index: 1)
        
        renderCommandEncoder.setMeshBytes(&instance, length: MemoryLayout<InstanceData>.stride, index: 4)
        
        for submesh in mesh.submeshes {
            renderCommandEncoder.setObjectBuffer(submesh.meshletBuffer?.buffer, offset:(submesh.meshletBuffer?.offset ?? 0), index: 0)
            
            renderCommandEncoder.setMeshBuffer(submesh.meshletBuffer?.buffer, offset: submesh.meshletBuffer?.offset ?? 0, index: 1)
            renderCommandEncoder.setMeshBuffer(submesh.meshletTriangleBuffer?.buffer, offset: submesh.meshletTriangleBuffer?.offset ?? 0, index: 3)

            // TODO: Set fragment resources (material data, etc.)
            
            let meshThreadCount = MTLSize(width: submesh.meshletCount, height: 1, depth: 1)
            let threadsPerObjectThreadgroup = MTLSize(width: 16, height: 1, depth: 1)
            let threadsPerMeshThreadgroup = MTLSize(width: Int(maxMeshThreads), height: 1, depth: 1)
            renderCommandEncoder.drawMeshThreads(meshThreadCount,
                                                 threadsPerObjectThreadgroup: threadsPerObjectThreadgroup,
                                                 threadsPerMeshThreadgroup: threadsPerMeshThreadgroup)
        }
    }

}
