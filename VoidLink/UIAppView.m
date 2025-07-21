//
//  UIAppView.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/22/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Created by True砖家 on 2025.7.20.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//


#import "UIAppView.h"
#import "AppAssetManager.h"
#import "ThemeManager.h"

static const float REFRESH_CYCLE = 1.0f;

@implementation UIAppView {
    TemporaryApp* _app;
    UILabel* _appLabel;
    UIImageView* _appOverlay;
    UIImageView* _appImage;
    NSCache* _artCache;
    id<AppCallback> _callback;
}

static UIImage* noImage;

- (id) initWithApp:(TemporaryApp*)app cache:(NSCache*)cache andCallback:(id<AppCallback>)callback {
    self = [super init];
    _app = app;
    _callback = callback;
    _artCache = cache;
    
    self.layer.cornerRadius = 16;
    self.clipsToBounds = YES;
    
    // Cache the NoAppImage ourselves to avoid
    // having to load it each time
    if (noImage == nil) {
        noImage = [UIImage imageNamed:@"NoAppImage"];
    }
        
#if TARGET_OS_TV
    self.frame = CGRectMake(0, 0, 200, 265);
#else
    self.frame = CGRectMake(0, 0, 150, 200);
#endif
    
    [self setAlpha:app.hidden ? 0.4 : 1.0];
    
    _appImage = [[UIImageView alloc] initWithFrame:self.frame];
    [_appImage setImage:noImage];
    
    [self addSubview:_appImage];
    
    // Use UIContextMenuInteraction on iOS 13.0+ and a standard UILongPressGestureRecognizer
    // for tvOS devices and iOS prior to 13.0.
#if !TARGET_OS_TV
    if (@available(iOS 13.0, *)) {
        UIContextMenuInteraction* rightClickInteraction = [[UIContextMenuInteraction alloc] initWithDelegate:self];
        [self addInteraction:rightClickInteraction];
    }
    else
#endif
    {
        UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(appLongClicked:)];
        [self addGestureRecognizer:longPressRecognizer];
    }
    
    [self addTarget:self action:@selector(appClicked:) forControlEvents:UIControlEventPrimaryActionTriggered];
    
    [self addTarget:self action:@selector(buttonSelected:) forControlEvents:UIControlEventTouchDown];
    [self addTarget:self action:@selector(buttonDeselected:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchCancel | UIControlEventTouchDragExit];
    
#if TARGET_OS_TV
    _appImage.adjustsImageWhenAncestorFocused = YES;
#else
    // Rasterizing the cell layer increases rendering performance by quite a bit
    // but we want it unrasterized for tvOS where it must be scaled.
    self.layer.shouldRasterize = YES;
    self.layer.rasterizationScale = [UIScreen mainScreen].scale;
    
    if (@available(iOS 13.4.1, *)) {
        // Allow the button style to change when moused over
        self.pointerInteractionEnabled = YES;
    }
#endif
    
    [self updateAppImage];
    
    return self;
}

- (void)didMoveToSuperview {
    // Start our update loop when we are added to our cell
    if (self.superview != nil) {
        [self updateLoop];
    }
}

- (void) appClicked:(UIView *)view {
    [_callback appClicked:_app view:view];
}

- (void) appLongClicked:(UILongPressGestureRecognizer*)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        [_callback appLongClicked:_app view:self];
    }
}

#if !TARGET_OS_TV
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location {
    // We don't want to trigger the primary action at this point, so cancel
    // tracking touch on this view now. This will also have the (intended)
    // effect of removing the touch highlight on this view.
    [self cancelTrackingWithEvent:nil];
    
    [_callback appLongClicked:_app view:self];
    return nil;
}
#endif

- (bool)isCurrentApp{
    return [_app.id isEqualToString:_app.host.currentGame];
}

- (void) updateAppImage {

    if (_appOverlay != nil) {
        [_appOverlay removeFromSuperview];
        _appOverlay = nil;
    }
    if (_appLabel != nil) {
        [_appLabel removeFromSuperview];
        _appLabel = nil;
    }
    
    BOOL noAppImage = false;
    
    // First check the memory cache
    //UIImage* appImage = [_artCache objectForKey:_app];
    UIImage* appImage = nil;
    // NSLog(@"appImage instance: %lu", (uintptr_t)appImage);
    if (appImage == nil) {
        // Next try to load from the on disk cache
        appImage = [UIImage imageWithContentsOfFile:[AppAssetManager boxArtPathForApp:_app]];
        if (appImage != nil) {
            [_artCache setObject:appImage forKey:_app];
        }
    }
    
    
    // [_artCache setObject:appImage forKey:_app];

    if (appImage != nil) {
        // This size of image might be blank image received from GameStream.
        
        // TODO: Improve no-app image detection
        if (!(appImage.size.width == 130.f && appImage.size.height == 180.f) && // GFE 2.0
            !(appImage.size.width == 628.f && appImage.size.height == 888.f)){
        
        // if(true){ // GFE 3.0
            [_appImage setImage:appImage];
        } else {
            noAppImage = true;
        }
    } else {
        noAppImage = true;
    }
    
    
    if([self isCurrentApp]) {
        // Only create the app overlay if needed
        
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:23];
            UIImageView* playIcon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"play.circle.fill" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
            //playIcon.tintColor = [[ThemeManager widgetBackgroundColor] colorWithAlphaComponent:0.85];
            playIcon.tintColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];

            _appOverlay = playIcon;
        } else {
            _appOverlay = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Play"]];
            
        }

        
        //_appOverlay.layer.shadowColor = [UIColor blackColor].CGColor;
        //_appOverlay.layer.shadowOffset = CGSizeMake(1, 1);
        //_appOverlay.layer.shadowOpacity = 1;
        //_appOverlay.layer.shadowRadius = 1.3;
        //_appOverlay.contentMode = UIViewContentModeScaleAspectFit;
    }
    else if(noAppImage){
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:70];
            UIImage* appIconImage = [[UIImage imageNamed:@"icon-pc-app"] imageWithConfiguration:config];
            UIImageView* appIcon = [[UIImageView alloc] initWithImage:[appIconImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
            
            //layIcon.tintColor = [[ThemeManager widgetBackgroundColor] colorWithAlphaComponent:0.85];
            appIcon.tintColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];

            _appOverlay = appIcon;
        }
    }
    
    if(true) {
        _appLabel = [[UILabel alloc] init];
        _appLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
        [_appLabel setTextColor:[[UIColor whiteColor] colorWithAlphaComponent:1]];
        //_appLabel.shadowColor = [UIColor blackColor];
        [_appLabel setText:[_app.name isEqualToString:@"Steam Big Picture"] ? @"Steam" : _app.name];
        [_appLabel setFont:[UIFont systemFontOfSize:15]];
        [_appLabel setBaselineAdjustment:UIBaselineAdjustmentAlignCenters];
        [_appLabel setTextAlignment:NSTextAlignmentCenter];
        [_appLabel setLineBreakMode:NSLineBreakByWordWrapping];
        [_appLabel setNumberOfLines:2];
        _appLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    }
    
    [self positionSubviews];
    
#if TARGET_OS_TV
    [_appImage.overlayContentView addSubview:_appLabel];
    [_appImage.overlayContentView addSubview:_appOverlay];
#else
    [self addSubview:_appOverlay];
    [self addSubview:_appLabel];
#endif
}

- (void) buttonSelected:(id)sender {
    _appImage.layer.opacity = 0.5f;
}
- (void) buttonDeselected:(id)sender {
    _appImage.layer.opacity = [self isCurrentApp] ? 0.75 : 1.0f;
}

- (void) positionSubviews {
   // CGFloat padding = 28;
    CGFloat verticalPadding = 10;
    CGSize frameSize = _appImage.frame.size;
   //  CGPoint center = _appImage.center;
    
    [_appLabel setFrame:CGRectMake(0, frameSize.height-43, frameSize.width, 43)];
    //[_appLabel setFrame:CGRectMake(0, 0, 30, 12)];

    
        if (_appOverlay != nil) {
            _appOverlay.frame = [self isCurrentApp] ? CGRectMake(0, 0, frameSize.width / 2.39, frameSize.width / 2.39) : CGRectMake(0, 0, frameSize.width / 2, frameSize.width / 2);
            _appOverlay.center = CGPointMake(frameSize.width/2,  frameSize.height/2 - 2 * verticalPadding);
            if([self isCurrentApp]) _appImage.layer.opacity = 0.75f;

            //[_appLabel setFrame:CGRectMake(padding, _appOverlay.frame.size.height + padding, frameSize.width - 2 * padding, frameSize.height - _appOverlay.frame.size.height - 2 * padding)];
        }
}

- (void) updateLoop {
    // Stop immediately if the view has been detached
    if (self.superview == nil) {
        return;
    }
    
    NSLog(@"appview update loop %f", CACurrentMediaTime());
    
    // Update the app image if neccessary
    if ((_appOverlay != nil && ![_app.id isEqualToString:_app.host.currentGame]) ||
        (_appOverlay == nil && [_app.id isEqualToString:_app.host.currentGame])) {
        [self updateAppImage];
    }
    
    // Show no shadow for hidden apps. Because we adjust the opacity of the
    // cells for hidden apps, it makes them look bad when the shadow draws
    // through the app tile.
    // self.superview.layer.shadowOpacity = _app.hidden ? 0.0f : 0.5f;
    self.superview.layer.shadowOpacity = 0;

    // Update opacity if neccessary
    [self setAlpha:_app.hidden ? 0.4 : 1.0];
    
    // Queue the next refresh cycle
    if([self.updateLoopDelegate isInAppView]) [self performSelector:@selector(updateLoop) withObject:self afterDelay:REFRESH_CYCLE];
}

@end
