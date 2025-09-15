//
//  PaddedLabel.m
//  Moonlight
//
//  Created by Travis Thieman on 5/6/25.
//  Copyright © 2025 Moonlight Game Streaming Project. All rights reserved.
//

#import "PaddedLabel.h"

@implementation PaddedLabel

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.textInsets = UIEdgeInsetsMake(8, 8, 8, 8); // default insets
    }
    return self;
}

- (void)drawTextInRect:(CGRect)rect {
    UIEdgeInsets insets = self.textInsets;
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, insets)];
}

- (CGSize)intrinsicContentSize {
    CGSize size = [super intrinsicContentSize];
    return CGSizeMake(size.width + self.textInsets.left + self.textInsets.right,
                      size.height + self.textInsets.top + self.textInsets.bottom);
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize fittingSize = [super sizeThatFits:size];
    return CGSizeMake(fittingSize.width + self.textInsets.left + self.textInsets.right,
                      fittingSize.height + self.textInsets.top + self.textInsets.bottom);
}

@end
