//
//  RendererPipelineStateMeshDescriptor.m
//  MetalMeshShaders
//
//  Created by Dayo Banjo on 3/21/23.
//

#import "MTLRenderPipelineStateProvider2.h"

@interface MTLRenderPipelineStateProvider2()

//+ (nullable id<MTLRenderPipelineState>)newShaderRenderPipelineStateWithMeshDescriptor:(MTLMeshRenderPipelineDescriptor *)descriptor
//                                                                              options:(MTLPipelineOption)options
//                                                                           reflection:(MTLAutoreleasedRenderPipelineReflection **)reflection
//                                                                                error:(NSError **)error
@end

@implementation MTLRenderPipelineStateProvider2

- (instancetype)initWithDevice:(id<MTLDevice>)device {
    if (self = [super init]) {
        self.mtDevice = device;
    }
    return self;
}

- (nullable id<MTLRenderPipelineState>)newShaderRenderPipelineStateWithMeshDescriptor:(MTLMeshRenderPipelineDescriptor *)descriptor
                                                                              options:(MTLPipelineOption)options
                                                                           reflection:(MTLAutoreleasedRenderPipelineReflection * __nullable)reflection
                                                                                error:(NSError **)error {
    
    return [self.mtDevice newRenderPipelineStateWithMeshDescriptor:descriptor
                                                         options:options
                                                  reflection:reflection
                                                           error:error];
}

@end
