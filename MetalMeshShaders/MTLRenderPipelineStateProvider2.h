//
//  RendererPipelineStateMeshDescriptor.h
//  MetalMeshShaders
//
//  Created by Dayo Banjo on 3/21/23.
//


#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTLRenderPipelineStateProvider2 : NSObject

@property (nonatomic, strong) id<MTLDevice> mtDevice;
- (nullable id<MTLRenderPipelineState>)newShaderRenderPipelineStateWithMeshDescriptor:(MTLMeshRenderPipelineDescriptor *)descriptor
                                                                              options:(MTLPipelineOption)options
                                                                           reflection:(MTLAutoreleasedRenderPipelineReflection * __nullable)reflection
                                                                                error:(NSError **)error;

- (instancetype)initWithDevice:(id<MTLDevice>)device;
@end

NS_ASSUME_NONNULL_END
