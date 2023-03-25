//
//  MeshUtilities.swift
//  MetalMeshShaders
//
//  Created by Dayo Banjo on 3/21/23.
//

import Foundation
import simd
import Metal

func simd_float4x4_translation(tx: Float, ty: Float, tz: Float) -> simd_float4x4 {
    return simd_matrix(
        simd_float4(1, 0, 0, 0),
        simd_float4(0, 1, 0, 0),
        simd_float4(0, 0, 1, 0),
        simd_float4(tx, ty, tz, 1)
    )
}

func simd_float4x4_perspective_rh(fovyRadians: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
    let ys = 1 / tanf(fovyRadians * 0.5)
    let xs = ys / aspect
    let zs = farZ / (nearZ - farZ)
    
    return simd_matrix(
        simd_float4(xs, 0, 0, 0),
        simd_float4(0, ys, 0, 0),
        simd_float4(0, 0, zs, -1),
        simd_float4(0, 0, nearZ * zs, 0)
    )
}

func simd_float4x4_rotation_axis_angle(axisX: Float, axisY: Float, axisZ: Float, angle: Float) -> simd_float4x4 {
    let unitAxis = simd_normalize(simd_float3(axisX, axisY, axisZ))
    let ct = cosf(angle)
    let st = sinf(angle)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    
    return simd_matrix(
        simd_float4(ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
        simd_float4(x * y * ci - z * st, ct + y * y * ci, z * y * ci + x * st, 0),
        simd_float4(x * z * ci + y * st, y * z * ci - x * st, ct + z * z * ci, 0),
        simd_float4(0, 0, 0, 1)
    )
}


struct MSMeshFileHeader {
    var meshletMaxVertexCount: UInt32
    var meshletMaxTriangleCount: UInt32
    var submeshOffset: UInt32
    var submeshCount: UInt32
    var meshletsOffset: UInt32
    var meshletCount: UInt32
    var vertexDataOffset: UInt32
    var vertexDataLength: UInt32
    var meshletVertexOffset: UInt32
    var meshletVertexLength: UInt32
    var meshletTrianglesOffset: UInt32
    var meshletTrianglesLength: UInt32
}

struct MBEMeshFileSubmesh {
    var meshletsStartIndex: UInt32
    var meshletsCount: UInt32
}

struct MBEMeshFileMeshlet {
    var vertexOffset: UInt32
    var vertexCount: UInt32
    var triangleOffset: UInt32
    var triangleCount: UInt32
    var bounds: (Float, Float, Float, Float)
    var coneApex: (Float, Float, Float)
    var coneAxis: (Float, Float, Float)
    var coneCutoff: Float
    var pad: Float
}

struct InstanceData {
    var modelViewProjectionMatrix: simd_float4x4
    var inverseModelViewMatrix: simd_float4x4
    var normalMatrix: simd_float4x4
}
