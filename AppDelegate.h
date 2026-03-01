//
//  AppDelegate.h
//  Metal4C
//
//  Created by Michael Larson on 2/10/26.
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#import "M4CView.h"
#import "Renderer.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate, MTKViewDelegate, NSTabViewDelegate>

- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size NS_SWIFT_UI_ACTOR;
- (void)drawInMTKView:(nonnull MTKView *)view NS_SWIFT_UI_ACTOR;

- (void)buttonClick:(nullable id)sender;
- (void)colorWellClick:(nullable id)sender;
@end

