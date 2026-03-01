//
//  M4CView.m
//  Metal4C
//
//  Created by Michael Larson on 2/16/26.
//

#import "M4CView.h"

NS_ASSUME_NONNULL_BEGIN

@implementation M4CView
- (nonnull instancetype)initWithFrame:(CGRect)frameRect device:(nullable id<MTLDevice>)device
{
    return [super initWithFrame:frameRect device:device];
}

- (nonnull instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    return [super initWithCoder:coder];
}

@end

NS_ASSUME_NONNULL_END
