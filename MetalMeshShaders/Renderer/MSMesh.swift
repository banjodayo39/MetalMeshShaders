//
//  MSMesh.swift
//  MetalMeshShaders
//
//  Created by Dayo Banjo on 3/21/23.
//

import Metal

class MSMeshBuffer {
    let buffer: MTLBuffer
    let offset: Int
    
    init(buffer: MTLBuffer, offset: Int) {
        self.buffer = buffer
        self.offset = offset
    }
}

class MSSubmesh {
    var meshletTriangleBuffer: MSMeshBuffer?
    var meshletBuffer: MSMeshBuffer?
    var meshletCount: Int = 0
}

class MSMesh {
    var meshletMaxVertexCount: UInt32!
    var meshletMaxTriangleCount: UInt32!
    var vertexDescriptor: MTLVertexDescriptor!
    var submeshes: [MSSubmesh] = []
    var vertexBuffers: [MSMeshBuffer] = []
    var meshletVertexBuffer: MSMeshBuffer!

    
    init?(with url: URL, device: MTLDevice) {
        guard let meshData = try? Data(contentsOf: url)
        else {
            return nil
        }
        let meshNSData = meshData as NSData
        
        var header = meshData.withUnsafeBytes { $0.load(as: MSMeshFileHeader.self) }
        meshletMaxVertexCount = header.meshletMaxVertexCount
        meshletMaxTriangleCount = header.meshletMaxTriangleCount
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 3
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.size * 6
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 8
        self.vertexDescriptor = vertexDescriptor
        
        guard let vertexBuffer = device.makeBuffer(bytes: meshNSData.bytes.advanced(by: Int(header.vertexDataOffset)),
                                             length: Int(header.vertexDataLength),
                                             options: .storageModeShared) 
        else { return }
        vertexBuffer.label = "Mesh Vertices"
        self.vertexBuffers = [MSMeshBuffer(buffer: vertexBuffer, offset: 0)]
        
        self.vertexBuffers = [MSMeshBuffer(buffer: vertexBuffer, offset: 0)]
        
        guard var meshletVertexBuffer = device.makeBuffer(bytes: meshNSData.bytes + Int(header.meshletVertexOffset), 
                                                          length: Int(header.meshletVertexLength),
                                                          options: .storageModeShared)
        else { return }
        meshletVertexBuffer.label = "Meshlet Vertex Map"
        self.meshletVertexBuffer = MSMeshBuffer(buffer: meshletVertexBuffer, offset: 0)
        
        assert(header.submeshCount == 1, "Only meshes with exactly one submesh are currently supported")
        for _ in 0..<header.submeshCount {
            let submesh = MSSubmesh()
            guard let meshletBuffer = device.makeBuffer(bytes: meshNSData.bytes + Int(header.meshletsOffset), 
                                                        length: Int(header.meshletCount) * MemoryLayout<MBEMeshFileMeshlet>.size, 
                                                        options: .storageModeShared) 
            else { return }
            meshletBuffer.label = "Meshlet Descriptors"
            
            guard let meshletTriangleBuffer = device.makeBuffer(bytes: meshNSData.bytes + UnsafeRawPointer.Stride(header.meshletTrianglesOffset), 
                                                                length: Int(header.meshletTrianglesLength),
                                                                options: .storageModeShared) 
            else { return }
            meshletTriangleBuffer.label = "Meshlet Triangles"
            
            submesh.meshletTriangleBuffer = MSMeshBuffer(buffer: meshletTriangleBuffer, offset: 0)
            submesh.meshletBuffer = MSMeshBuffer(buffer: meshletBuffer, offset: 0)
            submesh.meshletCount = Int(header.meshletCount)
            
            submeshes = [submesh]
        }
    }
    
}
