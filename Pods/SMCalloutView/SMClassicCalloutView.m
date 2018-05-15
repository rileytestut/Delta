#import "SMClassicCalloutView.h"
#import <QuartzCore/QuartzCore.h>

//
// UIView frame helpers - we do a lot of UIView frame fiddling in this class; these functions help keep things readable.
//

@interface UIView (SMFrameAdditions)
@property (nonatomic, assign) CGPoint frameOrigin;
@property (nonatomic, assign) CGSize frameSize;
@property (nonatomic, assign) CGFloat frameX, frameY, frameWidth, frameHeight; // normal rect properties
@property (nonatomic, assign) CGFloat frameLeft, frameTop, frameRight, frameBottom; // these will stretch/shrink the rect
@end

//
// Callout View.
//

#define CALLOUT_DEFAULT_MIN_WIDTH 75 // our image-based background graphics limit us to this minimum width...
#define CALLOUT_DEFAULT_HEIGHT 70 // ...and allow only for this exact height.
#define CALLOUT_DEFAULT_WIDTH 153 // default "I give up" width when we are asked to present in a space less than our min width
#define TITLE_MARGIN 17 // the title view's normal horizontal margin from the edges of our callout view
#define TITLE_TOP 11 // the top of the title view when no subtitle is present
#define TITLE_SUB_TOP 3 // the top of the title view when a subtitle IS present
#define TITLE_HEIGHT 22 // title height, fixed
#define SUBTITLE_TOP 25 // the top of the subtitle, when present
#define SUBTITLE_HEIGHT 16 // subtitle height, fixed
#define TITLE_ACCESSORY_MARGIN 6 // the margin between the title and an accessory if one is present (on either side)
#define ACCESSORY_MARGIN 14 // the accessory's margin from the edges of our callout view
#define ACCESSORY_TOP 8 // the top of the accessory "area" in which accessory views are placed
#define ACCESSORY_HEIGHT 32 // the "suggested" maximum height of an accessory view. shorter accessories will be vertically centered
#define BETWEEN_ACCESSORIES_MARGIN 7 // if we have no title or subtitle, but have two accessory views, then this is the space between them
#define ANCHOR_MARGIN 39 // the smallest possible distance from the edge of our control to the "tip" of the anchor, from either left or right
#define TOP_ANCHOR_MARGIN 13 // all the above measurements assume a bottom anchor! if we're pointing "up" we'll need to add this top margin to everything.
#define BOTTOM_ANCHOR_MARGIN 10 // if using a bottom anchor, we'll need to account for the shadow below the "tip"
#define REPOSITION_MARGIN 10 // when we try to reposition content to be visible, we'll consider this margin around your target rect

#define TOP_SHADOW_BUFFER 2 // height offset buffer to account for top shadow
#define BOTTOM_SHADOW_BUFFER 5 // height offset buffer to account for bottom shadow
#define OFFSET_FROM_ORIGIN 5 // distance to offset vertically from the rect origin of the callout
#define ANCHOR_HEIGHT 14 // height to use for the anchor
#define ANCHOR_MARGIN_MIN 24 // the smallest possible distance from the edge of our control to the edge of the anchor, from either left or right

@interface SMCalloutView (PrivateMethods)
@property (nonatomic, strong) UILabel *titleLabel, *subtitleLabel;
@property (nonatomic, assign) SMCalloutArrowDirection currentArrowDirection;
@property (nonatomic, assign) BOOL popupCancelled;
//@property (nonatomic, strong) UIImageView *leftCap, *rightCap, *topAnchor, *bottomAnchor, *leftBackground, *rightBackground;
@end

@interface SMClassicCalloutView ()

@end

@implementation SMClassicCalloutView

- (UIView *)titleViewOrDefault {
    if (self.titleView)
        // if you have a custom title view defined, return that.
        return self.titleView;
    else {
        if (!self.titleLabel) {
            // create a default titleView
            self.titleLabel = [UILabel new];
            self.titleLabel.frameHeight = TITLE_HEIGHT;
            self.titleLabel.opaque = NO;
            self.titleLabel.backgroundColor = [UIColor clearColor];
            self.titleLabel.font = [UIFont boldSystemFontOfSize:17];
            self.titleLabel.textColor = [UIColor whiteColor];
            self.titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.5];
            self.titleLabel.shadowOffset = CGSizeMake(0, -1);
        }
        return self.titleLabel;
    }
}

- (UIView *)subtitleViewOrDefault {
    if (self.subtitleView)
        // if you have a custom subtitle view defined, return that.
        return self.subtitleView;
    else {
        if (!self.subtitleLabel) {
            // create a default subtitleView
            self.subtitleLabel = [UILabel new];
            self.subtitleLabel.frameHeight = SUBTITLE_HEIGHT;
            self.subtitleLabel.opaque = NO;
            self.subtitleLabel.backgroundColor = [UIColor clearColor];
            self.subtitleLabel.font = [UIFont systemFontOfSize:12];
            self.subtitleLabel.textColor = [UIColor whiteColor];
            self.subtitleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.5];
            self.subtitleLabel.shadowOffset = CGSizeMake(0, -1);
        }
        return self.subtitleLabel;
    }
}

- (SMCalloutBackgroundView *)defaultBackgroundView {
    return [SMCalloutDrawnBackgroundView new];
}

- (void)rebuildSubviews {
    // remove and re-add our appropriate subviews in the appropriate order
    [self.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self setNeedsDisplay];
    
    [self addSubview:self.backgroundView];
    
    if (self.contentView) {
        [self addSubview:self.contentView];
    }
    else {
        if (self.titleViewOrDefault) [self addSubview:self.titleViewOrDefault];
        if (self.subtitleViewOrDefault) [self addSubview:self.subtitleViewOrDefault];
    }
    if (self.leftAccessoryView) [self addSubview:self.leftAccessoryView];
    if (self.rightAccessoryView) [self addSubview:self.rightAccessoryView];
}

- (CGFloat)innerContentMarginLeft {
    if (self.leftAccessoryView)
        return ACCESSORY_MARGIN + self.leftAccessoryView.frameWidth + TITLE_ACCESSORY_MARGIN;
    else
        return TITLE_MARGIN;
}

- (CGFloat)innerContentMarginRight {
    if (self.rightAccessoryView)
        return ACCESSORY_MARGIN + self.rightAccessoryView.frameWidth + TITLE_ACCESSORY_MARGIN;
    else
        return TITLE_MARGIN;
}

- (CGFloat)calloutHeight {
    if (self.contentView)
        return self.contentView.frameHeight + TITLE_TOP*2 + ANCHOR_HEIGHT + BOTTOM_ANCHOR_MARGIN;
    else
        return CALLOUT_DEFAULT_HEIGHT;
}

- (CGSize)sizeThatFits:(CGSize)size {
    
    // odd behavior, but mimicking the system callout view
    if (size.width < CALLOUT_DEFAULT_MIN_WIDTH)
        return CGSizeMake(CALLOUT_DEFAULT_WIDTH, self.calloutHeight);
    
    // calculate how much non-negotiable space we need to reserve for margin and accessories
    CGFloat margin = self.innerContentMarginLeft + self.innerContentMarginRight;
    
    // how much room is left for text?
    CGFloat availableWidthForText = size.width - margin;
    
    // no room for text? then we'll have to squeeze into the given size somehow.
    if (availableWidthForText < 0)
        availableWidthForText = 0;
    
    CGSize preferredTitleSize = [self.titleViewOrDefault sizeThatFits:CGSizeMake(availableWidthForText, TITLE_HEIGHT)];
    CGSize preferredSubtitleSize = [self.subtitleViewOrDefault sizeThatFits:CGSizeMake(availableWidthForText, SUBTITLE_HEIGHT)];
    
    // total width we'd like
    CGFloat preferredWidth;
    
    if (self.contentView) {
        
        // if we have a content view, then take our preferred size directly from that
        preferredWidth = self.contentView.frameWidth + margin;
    }
    else if (preferredTitleSize.width >= 0.000001 || preferredSubtitleSize.width >= 0.000001) {
        
        // if we have a title or subtitle, then our assumed margins are valid, and we can apply them
        preferredWidth = fmaxf(preferredTitleSize.width, preferredSubtitleSize.width) + margin;
    }
    else {
        // ok we have no title or subtitle to speak of. In this case, the system callout would actually not display
        // at all! But we can handle it.
        preferredWidth = self.leftAccessoryView.frameWidth + self.rightAccessoryView.frameWidth + ACCESSORY_MARGIN*2;
        
        if (self.leftAccessoryView && self.rightAccessoryView)
            preferredWidth += BETWEEN_ACCESSORIES_MARGIN;
    }
    
    // ensure we're big enough to fit our graphics!
    preferredWidth = fmaxf(preferredWidth, CALLOUT_DEFAULT_MIN_WIDTH);
    
    // ask to be smaller if we have space, otherwise we'll fit into what we have by truncating the title/subtitle.
    return CGSizeMake(fminf(preferredWidth, size.width), self.calloutHeight);
}

- (CGSize)offsetToContainRect:(CGRect)innerRect inRect:(CGRect)outerRect {
    CGFloat nudgeRight = fmaxf(0, CGRectGetMinX(outerRect) - CGRectGetMinX(innerRect));
    CGFloat nudgeLeft = fminf(0, CGRectGetMaxX(outerRect) - CGRectGetMaxX(innerRect));
    CGFloat nudgeTop = fmaxf(0, CGRectGetMinY(outerRect) - CGRectGetMinY(innerRect));
    CGFloat nudgeBottom = fminf(0, CGRectGetMaxY(outerRect) - CGRectGetMaxY(innerRect));
    return CGSizeMake(nudgeLeft ? nudgeLeft : nudgeRight, nudgeTop ? nudgeTop : nudgeBottom);
}

- (void)presentCalloutFromRect:(CGRect)rect inView:(UIView *)view constrainedToView:(UIView *)constrainedView animated:(BOOL)animated {
    [self presentCalloutFromRect:rect inLayer:view.layer ofView:view constrainedToLayer:constrainedView.layer animated:animated];
}

- (void)presentCalloutFromRect:(CGRect)rect inLayer:(CALayer *)layer constrainedToLayer:(CALayer *)constrainedLayer animated:(BOOL)animated {
    [self presentCalloutFromRect:rect inLayer:layer ofView:nil constrainedToLayer:constrainedLayer animated:animated];
}

// this private method handles both CALayer and UIView parents depending on what's passed.
- (void)presentCalloutFromRect:(CGRect)rect inLayer:(CALayer *)layer ofView:(UIView *)view constrainedToLayer:(CALayer *)constrainedLayer animated:(BOOL)animated {
    
    // Sanity check: dismiss this callout immediately if it's displayed somewhere
    if (self.layer.superlayer) [self dismissCalloutAnimated:NO];
    
    // figure out the constrained view's rect in our popup view's coordinate system
    CGRect constrainedRect = [constrainedLayer convertRect:constrainedLayer.bounds toLayer:layer];
    
    // apply our edge constraints
    constrainedRect = UIEdgeInsetsInsetRect(constrainedRect, self.constrainedInsets);
    
    // form our subviews based on our content set so far
    [self rebuildSubviews];
    
    // apply title/subtitle (if present
    self.titleLabel.text = self.title;
    self.subtitleLabel.text = self.subtitle;
    
    // size the callout to fit the width constraint as best as possible
    self.frameSize = [self sizeThatFits:CGSizeMake(constrainedRect.size.width, self.calloutHeight)];
    
    // how much room do we have in the constraint box, both above and below our target rect?
    CGFloat topSpace = CGRectGetMinY(rect) - CGRectGetMinY(constrainedRect);
    CGFloat bottomSpace = CGRectGetMaxY(constrainedRect) - CGRectGetMaxY(rect);
    
    // we prefer to point our arrow down.
    SMCalloutArrowDirection bestDirection = SMCalloutArrowDirectionDown;
    
    // we'll point it up though if that's the only option you gave us.
    if (self.permittedArrowDirection == SMCalloutArrowDirectionUp)
        bestDirection = SMCalloutArrowDirectionUp;
    
    // or, if we don't have enough space on the top and have more space on the bottom, and you
    // gave us a choice, then pointing up is the better option.
    if (self.permittedArrowDirection == SMCalloutArrowDirectionAny && topSpace < self.calloutHeight && bottomSpace > topSpace)
        bestDirection = SMCalloutArrowDirectionUp;
    
    // we want to point directly at the horizontal center of the given rect. calculate our "anchor point" in terms of our
    // target view's coordinate system. make sure to offset the anchor point as requested if necessary.
    CGFloat anchorX = self.calloutOffset.x + CGRectGetMidX(rect);
    CGFloat anchorY = self.calloutOffset.y + (bestDirection == SMCalloutArrowDirectionDown ? CGRectGetMinY(rect) : CGRectGetMaxY(rect));
    
    // we prefer to sit in the exact center of our constrained view, so we have visually pleasing equal left/right margins.
    CGFloat calloutX = roundf(CGRectGetMidX(constrainedRect) - self.frameWidth / 2);
    
    // what's the farthest to the left and right that we could point to, given our background image constraints?
    CGFloat minPointX = calloutX + ANCHOR_MARGIN;
    CGFloat maxPointX = calloutX + self.frameWidth - ANCHOR_MARGIN;
    
    // we may need to scoot over to the left or right to point at the correct spot
    CGFloat adjustX = 0;
    if (anchorX < minPointX) adjustX = anchorX - minPointX;
    if (anchorX > maxPointX) adjustX = anchorX - maxPointX;
    
    // add the callout to the given layer (or view if possible, to receive touch events)
    if (view)
        [view addSubview:self];
    else
        [layer addSublayer:self.layer];
    
    CGPoint calloutOrigin = {
        .x = calloutX + adjustX,
        .y = bestDirection == SMCalloutArrowDirectionDown ? (anchorY - self.calloutHeight + BOTTOM_ANCHOR_MARGIN) : anchorY
    };
    
    self.currentArrowDirection = bestDirection;
    
    self.frameOrigin = calloutOrigin;
    
    // now set the *actual* anchor point for our layer so that our "popup" animation starts from this point.
    CGPoint anchorPoint = [layer convertPoint:CGPointMake(anchorX, anchorY) toLayer:self.layer];
    
    // pass on the anchor point to our background view so it knows where to draw the arrow
    self.backgroundView.arrowPoint = anchorPoint;
    
    // adjust it to unit coordinates for the actual layer.anchorPoint property
    anchorPoint.x /= self.frameWidth;
    anchorPoint.y /= self.frameHeight;
    self.layer.anchorPoint = anchorPoint;
    
    // setting the anchor point moves the view a bit, so we need to reset
    self.frameOrigin = calloutOrigin;
    
    // make sure our frame is not on half-pixels or else we may be blurry!
    self.frame = CGRectIntegral(self.frame);
    
    // layout now so we can immediately start animating to the final position if needed
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    // if we're outside the bounds of our constraint rect, we'll give our delegate an opportunity to shift us into position.
    // consider both our size and the size of our target rect (which we'll assume to be the size of the content you want to scroll into view.
    CGRect contentRect = CGRectUnion(self.frame, CGRectInset(rect, -REPOSITION_MARGIN, -REPOSITION_MARGIN));
    CGSize offset = [self offsetToContainRect:contentRect inRect:constrainedRect];
    
    NSTimeInterval delay = 0;
    self.popupCancelled = NO; // reset this before calling our delegate below
    
    if ([self.delegate respondsToSelector:@selector(calloutView:delayForRepositionWithSize:)] && !CGSizeEqualToSize(offset, CGSizeZero))
        delay = [self.delegate calloutView:(id)self delayForRepositionWithSize:offset];
    
    // there's a chance that user code in the delegate method may have called -dismissCalloutAnimated to cancel things; if that
    // happened then we need to bail!
    if (self.popupCancelled) return;
    
    // if we need to delay, we don't want to be visible while we're delaying, so hide us in preparation for our popup
    self.hidden = YES;
    
    // create the appropriate animation, even if we're not animated
    CAAnimation *animation = [self animationWithType:self.presentAnimation presenting:YES];
    
    // nuke the duration if no animation requested - we'll still need to "run" the animation to get delays and callbacks
    if (!animated)
        animation.duration = 0.0000001; // can't be zero or the animation won't "run"
    
    animation.beginTime = CACurrentMediaTime() + delay;
    animation.delegate = self;
    
    [self.layer addAnimation:animation forKey:@"present"];
}

- (void)animationDidStart:(CAAnimation *)anim {
    BOOL presenting = [[anim valueForKey:@"presenting"] boolValue];
    
    if (presenting) {
        if ([self.delegate respondsToSelector:@selector(calloutViewWillAppear:)])
            [self.delegate calloutViewWillAppear:(id)self];
        
        // ok, animation is on, let's make ourselves visible!
        self.hidden = NO;
    }
    else if (!presenting) {
        if ([self.delegate respondsToSelector:@selector(calloutViewWillDisappear:)])
            [self.delegate calloutViewWillDisappear:(id)self];
    }
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)finished {
    BOOL presenting = [[anim valueForKey:@"presenting"] boolValue];
    
    if (presenting) {
        if ([self.delegate respondsToSelector:@selector(calloutViewDidAppear:)])
            [self.delegate calloutViewDidAppear:(id)self];
    }
    else if (!presenting) {
        
        [self removeFromParent];
        [self.layer removeAnimationForKey:@"dismiss"];
        
        if ([self.delegate respondsToSelector:@selector(calloutViewDidDisappear:)])
            [self.delegate calloutViewDidDisappear:(id)self];
    }
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    // we want to match the system callout view, which doesn't "capture" touches outside the accessory areas. This way you can click on other pins and things *behind* a translucent callout.
    return
    [self.leftAccessoryView pointInside:[self.leftAccessoryView convertPoint:point fromView:self] withEvent:nil] ||
    [self.rightAccessoryView pointInside:[self.rightAccessoryView convertPoint:point fromView:self] withEvent:nil] ||
    [self.contentView pointInside:[self.contentView convertPoint:point fromView:self] withEvent:nil] ||
    (!self.contentView && [self.titleView pointInside:[self.titleView convertPoint:point fromView:self] withEvent:nil]) ||
    (!self.contentView && [self.subtitleView pointInside:[self.subtitleView convertPoint:point fromView:self] withEvent:nil]);
}

- (void)dismissCalloutAnimated:(BOOL)animated {
    [self.layer removeAnimationForKey:@"present"];
    
    self.popupCancelled = YES;
    
    if (animated) {
        CAAnimation *animation = [self animationWithType:self.dismissAnimation presenting:NO];
        animation.delegate = self;
        [self.layer addAnimation:animation forKey:@"dismiss"];
    }
    else [self removeFromParent];
}

- (void)removeFromParent {
    if (self.superview)
        [self removeFromSuperview];
    else {
        // removing a layer from a superlayer causes an implicit fade-out animation that we wish to disable.
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        [self.layer removeFromSuperlayer];
        [CATransaction commit];
    }
}

- (CAAnimation *)animationWithType:(SMCalloutAnimation)type presenting:(BOOL)presenting {
    CAAnimation *animation = nil;
    
    if (type == SMCalloutAnimationBounce) {
        CAKeyframeAnimation *bounceAnimation = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        CAMediaTimingFunction *easeInOut = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        bounceAnimation.values = @[@0.05, @1.11245, @0.951807, @1.0];
        bounceAnimation.keyTimes = @[@0, @(4.0/9.0), @(4.0/9.0+5.0/18.0), @1.0];
        bounceAnimation.duration = 1.0/3.0; // the official bounce animation duration adds up to 0.3 seconds; but there is a bit of delay introduced by Apple using a sequence of callback-based CABasicAnimations rather than a single CAKeyframeAnimation. So we bump it up to 0.33333 to make it feel identical on the device
        bounceAnimation.timingFunctions = @[easeInOut, easeInOut, easeInOut, easeInOut];
        
        if (!presenting)
            bounceAnimation.values = [[bounceAnimation.values reverseObjectEnumerator] allObjects]; // reverse values
        
        animation = bounceAnimation;
    }
    else if (type == SMCalloutAnimationFade) {
        CABasicAnimation *fadeAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        fadeAnimation.duration = 1.0/3.0;
        fadeAnimation.fromValue = presenting ? @0.0 : @1.0;
        fadeAnimation.toValue = presenting ? @1.0 : @0.0;
        animation = fadeAnimation;
    }
    else if (type == SMCalloutAnimationStretch) {
        CABasicAnimation *stretchAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
        stretchAnimation.duration = 0.1;
        stretchAnimation.fromValue = presenting ? @0.0 : @1.0;
        stretchAnimation.toValue = presenting ? @1.0 : @0.0;
        animation = stretchAnimation;
    }
    
    // CAAnimation is KVC compliant, so we can store whether we're presenting for lookup in our delegate methods
    [animation setValue:@(presenting) forKey:@"presenting"];
    
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;
    return animation;
}

- (CGFloat)centeredPositionOfView:(UIView *)view ifSmallerThan:(CGFloat)height {
    return view.frameHeight < height ? floorf(height/2 - view.frameHeight/2) : 0;
}

- (CGFloat)centeredPositionOfView:(UIView *)view relativeToView:(UIView *)parentView {
    return roundf((parentView.frameHeight - view.frameHeight) / 2);
}

- (void)layoutSubviews {
    
    self.backgroundView.frame = self.bounds;
    
    // if we're pointing up, we'll need to push almost everything down a bit
    CGFloat dy = self.currentArrowDirection == SMCalloutArrowDirectionUp ? TOP_ANCHOR_MARGIN : 0;
    
    self.titleViewOrDefault.frameX = self.innerContentMarginLeft;
    self.titleViewOrDefault.frameY = (self.subtitleView || self.subtitle.length ? TITLE_SUB_TOP : TITLE_TOP) + dy;
    self.titleViewOrDefault.frameWidth = self.frameWidth - self.innerContentMarginLeft - self.innerContentMarginRight;
    
    self.subtitleViewOrDefault.frameX = self.titleViewOrDefault.frameX;
    self.subtitleViewOrDefault.frameY = SUBTITLE_TOP + dy;
    self.subtitleViewOrDefault.frameWidth = self.titleViewOrDefault.frameWidth;
    
    self.leftAccessoryView.frameX = ACCESSORY_MARGIN;
    if (self.contentView)
        self.leftAccessoryView.frameY = TITLE_TOP + [self centeredPositionOfView:self.leftAccessoryView relativeToView:self.contentView] + dy;
    else
        self.leftAccessoryView.frameY = ACCESSORY_TOP + [self centeredPositionOfView:self.leftAccessoryView ifSmallerThan:ACCESSORY_HEIGHT] + dy;
    
    self.rightAccessoryView.frameX = self.frameWidth-ACCESSORY_MARGIN-self.rightAccessoryView.frameWidth;
    if (self.contentView)
        self.rightAccessoryView.frameY = TITLE_TOP + [self centeredPositionOfView:self.rightAccessoryView relativeToView:self.contentView] + dy;
    else
        self.rightAccessoryView.frameY = ACCESSORY_TOP + [self centeredPositionOfView:self.rightAccessoryView ifSmallerThan:ACCESSORY_HEIGHT] + dy;
    
    
    if (self.contentView) {
        self.contentView.frameX = self.innerContentMarginLeft;
        self.contentView.frameY = TITLE_TOP + dy;
    }
}

@end

// import this known "private API" from SMCalloutView.m
@interface SMCalloutBackgroundView (EmbeddedImages)
+ (UIImage *)embeddedImageNamed:(NSString *)name;
@end

//
// Callout background assembled from predrawn stretched images.
//
@implementation SMCalloutImageBackgroundView {
    UIImageView *leftCap, *rightCap, *topAnchor, *bottomAnchor, *leftBackground, *rightBackground;
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        leftCap = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 17, 57)];
        rightCap = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 17, 57)];
        topAnchor = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 41, 70)];
        bottomAnchor = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 41, 70)];
        leftBackground = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 1, 57)];
        rightBackground = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 1, 57)];
        [self addSubview:leftCap];
        [self addSubview:rightCap];
        [self addSubview:topAnchor];
        [self addSubview:bottomAnchor];
        [self addSubview:leftBackground];
        [self addSubview:rightBackground];
    }
    return self;
}

- (UIImage *)leftCapImage { return _leftCapImage ? _leftCapImage : [[SMCalloutBackgroundView embeddedImageNamed:@"SMCalloutViewLeftCap"] stretchableImageWithLeftCapWidth:16 topCapHeight:20]; }
- (UIImage *)rightCapImage { return _rightCapImage ? _rightCapImage : [[SMCalloutBackgroundView embeddedImageNamed:@"SMCalloutViewRightCap"] stretchableImageWithLeftCapWidth:0 topCapHeight:20]; }
- (UIImage *)topAnchorImage { return _topAnchorImage ? _topAnchorImage : [[SMCalloutBackgroundView embeddedImageNamed:@"SMCalloutViewTopAnchor"] stretchableImageWithLeftCapWidth:0 topCapHeight:33]; }
- (UIImage *)bottomAnchorImage { return _bottomAnchorImage ? _bottomAnchorImage : [[SMCalloutBackgroundView embeddedImageNamed:@"SMCalloutViewBottomAnchor"] stretchableImageWithLeftCapWidth:0 topCapHeight:20]; }
- (UIImage *)backgroundImage { return _backgroundImage ? _backgroundImage : [[SMCalloutBackgroundView embeddedImageNamed:@"SMCalloutViewBackground"] stretchableImageWithLeftCapWidth:0 topCapHeight:20]; }

// Make sure we relayout our images when our arrow point changes!
- (void)setArrowPoint:(CGPoint)arrowPoint {
    [super setArrowPoint:arrowPoint];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    
    // apply our background graphics
    leftCap.image = self.leftCapImage;
    rightCap.image = self.rightCapImage;
    topAnchor.image = self.topAnchorImage;
    bottomAnchor.image = self.bottomAnchorImage;
    leftBackground.image = self.backgroundImage;
    rightBackground.image = self.backgroundImage;
    
    // stretch the images to fill our vertical space. The system background images aren't really stretchable,
    // but that's OK because you'll probably be using title/subtitle rather than contentView if you're using the
    // system images, and in that case the height will match the system background heights exactly and no stretching
    // will occur. However, if you wish to define your own custom background using prerendered images, you could
    // define stretchable images using -stretchableImageWithLeftCapWidth:TopCapHeight and they'd get stretched
    // properly here if necessary.
    leftCap.frameHeight = rightCap.frameHeight = leftBackground.frameHeight = rightBackground.frameHeight = self.frameHeight - 13;
    topAnchor.frameHeight = bottomAnchor.frameHeight = self.frameHeight;
    
    BOOL pointingUp = self.arrowPoint.y < self.frameHeight/2;
    
    // show the correct anchor based on our direction
    topAnchor.hidden = !pointingUp;
    bottomAnchor.hidden = pointingUp;
    
    // if we're pointing up, we'll need to push almost everything down a bit
    CGFloat dy = pointingUp ? TOP_ANCHOR_MARGIN : 0;
    leftCap.frameY = rightCap.frameY = leftBackground.frameY = rightBackground.frameY = dy;
    
    leftCap.frameX = 0;
    rightCap.frameX = self.frameWidth - rightCap.frameWidth;
    
    // move both anchors, only one will have been made visible in our -popup method
    CGFloat anchorX = roundf(self.arrowPoint.x - bottomAnchor.frameWidth / 2);
    topAnchor.frameOrigin = CGPointMake(anchorX, 0);
    
    // make sure the anchor graphic isn't overlapping with an endcap
    if (topAnchor.frameLeft < leftCap.frameRight) topAnchor.frameX = leftCap.frameRight;
    if (topAnchor.frameRight > rightCap.frameLeft) topAnchor.frameX = rightCap.frameLeft - topAnchor.frameWidth; // don't stretch it
    
    bottomAnchor.frameOrigin = topAnchor.frameOrigin; // match
    
    leftBackground.frameLeft = leftCap.frameRight;
    leftBackground.frameRight = topAnchor.frameLeft;
    rightBackground.frameLeft = topAnchor.frameRight;
    rightBackground.frameRight = rightCap.frameLeft;
}

@end

@implementation SMCalloutBackgroundView (ClassicEmbeddedImages)

//
// I didn't want this class to require adding any images to your Xcode project. So instead the images needed are embedded below.
//

+ (NSString *)SMCalloutViewBackground { return @"iVBORw0KGgoAAAANSUhEUgAAAAEAAAA5CAYAAAD3PEFJAAAAHGlET1QAAAACAAAAAAAAAB0AAAAoAAAAHQAAABwAAACkF8Y1LgAAAHBJREFUGBlMy6ENQyEARdGXJh2CBEZAgAABhoQgEASDQBCWYqy3wt/lt80XFfe4CwCvT3gjpXThnEPsvYm1FjHnJMYYRO+daK0RtVailELknPndiBjjQwiB8N4TzrkHay3xwxhDaK0JpRQhpfxHCMEbAAD//2TbkE8AAAA9SURBVGOQlJQ8w0AJIScnd4ZBQ0PjDIOysvJdBiCIARFhIMIPRLiACEsQoQMiFEGEBIgQABFcIIIVRDABAL6ePTfutWY6AAAAAElFTkSuQmCC"; }
+ (NSString *)SMCalloutViewBackground_2x { return @"iVBORw0KGgoAAAANSUhEUgAAAAIAAAByCAYAAAB5lADlAAAACXBIWXMAABYlAAAWJQFJUiTwAAAAHGlET1QAAAACAAAAAAAAADkAAAAoAAAAOQAAADkAAAD3bjNTjgAAAMNJREFUOBGkz72JhGAAhOGpwyZUVESFVfAPFFRcFfypwmJsa4KNtxaPucAvuuiCZ3jTwX3fkN/5I7Iso2Acx4/guq6v4DzPj+A4Dgr2faeY2LaNgifWdaVgWRYK5nmmmJimiYL3+03BMAwU9H1PMdF1HQVt21LQNA3FRF3XFFRVRUFZlhQURUFBnucUPJfTNKXgidfrRUGSJBTEcUwxEUURBWEYUhAEAcWE7/sUeJ5HMeG6LgWO41Bg2zbFhGVZFPwvfgAAAP//7zgpOQAAAGxJREFU5cYhCkJBAEXRqyAYLJOECTLFaDXafjNZDIKgLniWNL73eXxwDYZzudRau/HP01rrxjKllG4sA3yCt8Z4BU+N8QjuGuMWXDXGFFw0xjk4aYxjcNAY+6BojF2w1RibYK0xVrMxBjbnZ75mdyKsdyBPxAAAAABJRU5ErkJggg=="; }
+ (NSString *)SMCalloutViewBottomAnchor { return @"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"; }
+ (NSString *)SMCalloutViewBottomAnchor_2x { return @"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"; }
+ (NSString *)SMCalloutViewLeftCap { return @"iVBORw0KGgoAAAANSUhEUgAAABEAAAA5CAYAAADQksChAAAAHGlET1QAAAACAAAAAAAAAB0AAAAoAAAAHQAAABwAAAKS6krCNQAAAl5JREFUSA2klNmKGkEUhs0yM9nIglnctQc3zKioqOCKwQVXFBRUcLnxwvtci88gPkpeIlATEshVSM2rmP9UUo3dajuQi49TVX3OZ3mquk273c50DpPJ9OAID7H2l2MCXYFMfoT1xzouML842MU/gabQ4XAUo9Ho10KhcFcqlbgejWRPIH/10ul0fq7X67/X6/X3zWZzu91umR5VohPQNq/MZvOndrv9a7VafVssFmw+n7PZbKYi50JyTIC1Zz6f78tyufwxnU7ZZDI5iV5CjbsiAXiZy+V+jsfjW8BGo9FJ9iXUh0vwlATAnEwm74bDIRsMBoZICZ2G3MULjN8ASzgc5v1+n3W73QN6vR4j6BlyxUUiCTVT7uIdxo5QKMQpqdPpaGi1WmIuI3KFRP6V55iLXSAqgUCAUyKOmDWbTdZoNESUY5oT+xJqKP0VM7ADL06HU0GtVlOpVqtMIteRK3ZC/XgCqKFvgRMEvF4vp4JyuWwIcg8k77HmBiFFUXilUmG45oaQRJ4MNfUV+AA84KPH46H3hBWLRZbP50WUY5pLkKuRvMbcAhRwQxIqwqUzBLlCQsdLt1QjcblcnASZTEZDNptV5zQ+JbnGgxuSUFI6nTbESBLGZ4DTLlKplGBfJtconpVQId4hVUTj/flZCb5oPBaLsXg8LkgkEuwYhjux2+0cF06VkExKZaS1sxJcOOb3+0UxFR7DUGK1WjlJcEqMYjAYZPg8sEgkouGsxO12M5wSQ380kdYk95KQwIj/kthsNiE3lFgsFk79oGRZIMcy0g7vJUGDVZEslpGe/QEAAP//KqClBgAAAfBJREFU7ZTRatNQHIfjdFaj1El1prW2Sbti2aZeKEMFB+pAEFREFAa79d5n8YF8gkzUi93M7VXq9x08I82y7QH04iNpOP34/37nJEmSJAuwCCksQQYjuJdl2cFgMCh7vV6g2+2WVXzub9aeLan+sen+v2S+3H+12Hioms7IWZ2ss+AwntiTBKdJCk6hkr08z3f7/f7cca8L44m9wM1liO9OkHQ6nW/j8fjncDgsFZ0Uqy65xoNbkMNamqafEexPJpPvo9GoNFoTrE3OgZNcgjYswxBWYaPdbn9lmt/T6fQH7EJZh3XHJDd4dgfuwkPYbLVaX4jyqyiKQ4QHdVgTJOe5tuAqdOA2rMADeAov4DW8h0+wDTsVjiQXeXgFroMfJstdg0fwDLZA0Tv4AB9BoQRJ/Lq5Q/ZyE/owgfuwAYpewitQ9gbeBmazGdfwdbPcGClOY8F2o8iJjLYJz0Gh020lfyXukL0YKU5jN11Q5ERGsyPLdrLH8CRQkRgpTpNybyxF9mM0O1oBJ1sFpeuBmsRp/PIbK4qMZkfK3DW33+lyUFyEOKeIjOa2O5UyJ1O4DJ5sxdmRpEFkNDvyJCtz+6NQqa+I79rSnKQmsiPjKTOiQmMqjWLl6TFJReSOibKqUGlE+WKjRFEVFkZh9RrlC38A3S8C8jPZQY0AAAAASUVORK5CYII="; }
+ (NSString *)SMCalloutViewLeftCap_2x { return @"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"; }
+ (NSString *)SMCalloutViewRightCap { return @"iVBORw0KGgoAAAANSUhEUgAAABEAAAA5CAYAAADQksChAAAAHGlET1QAAAACAAAAAAAAAB0AAAAoAAAAHQAAABwAAAKdevXfpAAAAmlJREFUSA2UlNlqWlEUhredJzpgB41zcAi2JiRiBE0UiwNxQsGACibeeJH7XovPEPIofYnCSmmhV6XJq6T/f3SfHg/xmF58rH22rm+vvfY+Ryml7llwYbzEzc2NWgdy1MMFDxCt3MezXsAU3yZUpVLpyk6hULje2dn55vf7iwvxktAuUhcXF2Ln/Pz8cjab/Tg6OvoTCAS+QPTIJnNZRer09FTG47Ewavg8mUxkOp1+b7Vav91u92dIHgNuXVdlitRoNJJVnJycyNnZ2c9YLPYVyc9WidRgMJBVDIdDAZcHBwe/IHhpEfEA2HSjGnV8fCxO9Pt9yWQy10hwA4qeAvaI25pLOp2OdLtdA47t9Ho9SaVSV0jwgDfgBWB/jGrYYNVut6XZbIo1cqyhNJlMUuIH74Cuhk02tqTq9bpoGo2GED4z4oiNBRKJBCURoKt5jrG5JVWr1YRUq1UTPcdIGU6HkijwAfZGb8noiyqXy+IE5dFolJIECIC3gFt6AtgXF6+9OFGpVCQSiVCSBCHwHixLDg8PxUqxWBTCOUYuEA6HKfkIwuADeAV41PP7goskTlC0kHxCkm7u6yVJPp+XXC5nYB3rOS4QDAZZiV3C12B+zNlsVpyg2CLZRCKPmZX8k+zv74vGKtNzrAifA1aSAusleEf4nphSjileK0mn03Ibe3t7QnZ3dwVfOOdKrH/WSXqOERdNfD6fs4QrrSIej/OirZdsb2+LFbz2srW1ZSTjVIzo9XqdK0HT2DgT7N8Y6xgKhWSthH924s6SjY2NlaL/klCkYWV6zL54PB7nnmC/ZoJO1JG/3UXyFwAA//9HuzCQAAAB80lEQVTtlc1qU1EURk9iNXqVqERrEmNykzQY/B0oooKCPyAIbRGpIDh17rP4QD7BragDJ9q+SlwrZsd7NRQFhx0szulhf9/Z+7uHJnU6naLb7RauZTyTfr9ftNvtvZTSdRhBG85ABkehnsrCVftDk2q4ZnSYSTWT//LYwoSA93mZ1+DfX2yv1yvyPN/F5OvCZMj6d8/eDjQYDAbFeDz+3Gq1PqwwOcHZGtST72AVo9GomEwmHzH6lmXZW4qvQg4X4DT8MplOp8UKdjn7RBffm83mewR34AoMYB2acBzspJYo3Pud4XC4z0hfGo3GO4oewi24DJfgHFRNOHhT4jX7V/ACnsNjuA83YQMuQgtOQQOOQA3mIoU78BK2QYOn8ABug3nElznL/iQcg6XJFn/IJih+Bk9AA7O4ARPowXlwFEP9+V9t0Yk3isJHYAaOYAcamIWB+j7sIkZZY1+fzWYsKd1bcJfVmw3RDBzBDjTogFlEF8tRwsTnLIr8jN68AWbgCHYQBhl7A513wVoLE4slB2/1M/oVFJuBI9hBGJiFgdZhaWKx+BLXQaE3h9gMDNIO/jCITvwNEZ+yN4pCP6NiX6YZOEKlAw3CxDYtDoEib1XozWXxcoQwCBMLo1hBELfOhZzXpCyOPefzgCysFCuQKDxo/QHd3ALyX+9lLwAAAABJRU5ErkJggg=="; }
+ (NSString *)SMCalloutViewRightCap_2x { return @"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"; }
+ (NSString *)SMCalloutViewTopAnchor { return @"iVBORw0KGgoAAAANSUhEUgAAACkAAABGCAYAAABRwr15AAAAHGlET1QAAAACAAAAAAAAACMAAAAoAAAAIwAAACMAAAQYDCloiwAAA+RJREFUaAXMVslKHFEUfSaaaPIFunDaulJj2/QQBxxwVtCFC9GFCxVRUHHAARVx1pWf9QKVNCGb5FvMPUWf5vazqu0qFVwc7nTuvaeedr0yj4+P5qUwxlQoVCq/4qWz0R9boBLyQXwfzc3N31paWn7CMpe3/kPEFRxLZF4gxX2UuLKpqSkxOTn56/T09DcsYuQFqJMb62Qji5SFOBUs9cWJ/dTY2JiEsPv7e+/s7OwHLGLkURdosZGFRhIpyygQS6sE1Q0NDampqakchMkpWgIx8qiDl+ejDw8YSWjZIjE4vwCLcDrV9fX1aQi5u7vzBZ6cnBREQiyFggd+vi+y0LJEynBXYI0szsif1BcIccfHx0+APB4APPBlTk0coc+KDBM4MTGRu7299SDk6OgoFKiDB35coSVFhgkcGxvLXV1deRB3eHhoDw4OiixyGjjlm5sbD31xhIaKDBM4Ojqau7y89AXu7+/bvb09C/sc8EDoQ39UoYEiwwQODw/nLi4uPJzc7u5uZKAP/SMjI5GEPhEZJnBoaCh3fn7uQdzW1pbd3t72resjZg4cgnn0Yw7mlXuiRSKDBNbV1WUwUF4p3s7Ojt3Y2CjC5uamH8NqHzzmXIs5mIe5mC97S/7qpV64svQt8lnyX2pra7MDAwO+QCxaW1vzsb6+bgk3FxSTqy3myS/fw3zswT4B9uI9qq9S6PJvDtweeEGDhKf6Ko3f+/v7c/LL9DB8dXX11YG5mI892Ie9+f3QAT3QVWV6enr+uejt7f07PT39R14j3srKil1aWirC8vJyUezW3bgUH/OxB/uw19WC2Dw8PNggXF9f+0IWFxftWwMPhX1BOpAzCwsL1sX8/LwFmKdPyzxsGJecoB7Wwix7aM3c3Jx97zCzs7P2vcPMzMxY+ae1sHERpd/lunGQBiOfUVa+CS2si7C85mlOmB+2o1y+GR8ft4Bc/EXWzSOWz60iDnuCuMwFWfbBBvnoYR6+kY8GqyGXvx/D0medsVuT660wgxy3h7Fr2cs+WvJQN3It2cHBQR/wCZ2DX4rHGnvd2J3lztN13Uue6evrs4C87X0bFjP/mtbdGTYb16Iluru7C36pHGvavqRXz6Gv55lsNmuJrq4uq4E8YteSwz7WycUCnWMeljW3l3zWdY/JZDL2vcOkUikbhGQyWcin0+mCH8SNmtPz6Ot97jzT2dlpCRDpw7qxrr2l7+41iUTCamA5Y/raUhw5sMyR59Y0R9eYD8txXpHIjo4OXyCtbg7K6Tr953il6m6NsWlvb7floq2trWyunhm3jzMMBgShtbXVAlFq5MfpxR7dz73I/QcAAP//R6Pt0AAAASZJREFU7VK7asNAEBwCblKltISkImrUWEhl+tQuU+WT7xfyL94TjNksdzIkZ7yGMwyzj9m9YWWs6xpuYVmWm5rcjhKzmOc55BAfYE/HrO2x1ut4b4Y9rY8x+r4PFl3XhQjWGVtmX/M9ZsGlnnkz2bbtdjkaZU5mPcVWY/PUDGvUWmafjCjQIuY5joO2l6pZTcxTulTNzl5NNk0TiCjKxXaB1sYZndv4r7PQi/VSmiTzAeZkzpBZ1/zf2c0kF+49RE2O7zn7y2TOwKPr1WSpL1AvWS9Z6gKl9tT/ZL1kqQuU2oNhGIJ3YJqm4B0Yx/HHOyC/7ycAvsSkd+AsJr0Dn2LSO/AhJr0DJzHpHXgXk96Bo5j0DryJSe/Aq5j0DhzEpHfgRUy6xgX1iUkAQX47jAAAAABJRU5ErkJggg=="; }
+ (NSString *)SMCalloutViewTopAnchor_2x { return @"iVBORw0KGgoAAAANSUhEUgAAAFIAAACMCAYAAADvGP7EAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyRpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMy1jMDExIDY2LjE0NTY2MSwgMjAxMi8wMi8wNi0xNDo1NjoyNyAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNiAoTWFjaW50b3NoKSIgeG1wTU06SW5zdGFuY2VJRD0ieG1wLmlpZDo5QUY0RkNERjZENDMxMUUyQTAzNEREMUIxRjIzOEVCNSIgeG1wTU06RG9jdW1lbnRJRD0ieG1wLmRpZDo5QUY0RkNFMDZENDMxMUUyQTAzNEREMUIxRjIzOEVCNSI+IDx4bXBNTTpEZXJpdmVkRnJvbSBzdFJlZjppbnN0YW5jZUlEPSJ4bXAuaWlkOjdFQUM5NTk0NkJGQjExRTJBMDM0REQxQjFGMjM4RUI1IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjlBRjRGQ0RFNkQ0MzExRTJBMDM0REQxQjFGMjM4RUI1Ii8+IDwvcmRmOkRlc2NyaXB0aW9uPiA8L3JkZjpSREY+IDwveDp4bXBtZXRhPiA8P3hwYWNrZXQgZW5kPSJyIj8+zk9a9AAABhtJREFUeNrsnclO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"; }

@end

//
// Custom-drawn flexible-height background implementation.
// Contributed by Nicholas Shipes: https://github.com/u10int
//
@implementation SMCalloutDrawnBackgroundView

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
    }
    return self;
}

// Make sure we redraw our graphics when the arrow point changes!
- (void)setArrowPoint:(CGPoint)arrowPoint {
    [super setArrowPoint:arrowPoint];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    
    BOOL pointingUp = self.arrowPoint.y < self.frameHeight/2;
    CGSize anchorSize = CGSizeMake(27, ANCHOR_HEIGHT);
    CGFloat anchorX = roundf(self.arrowPoint.x - anchorSize.width / 2);
    CGRect anchorRect = CGRectMake(anchorX, 0, anchorSize.width, anchorSize.height);
    
    // make sure the anchor is not too close to the end caps
    if (anchorRect.origin.x < ANCHOR_MARGIN_MIN)
        anchorRect.origin.x = ANCHOR_MARGIN_MIN;
    
    else if (anchorRect.origin.x + anchorRect.size.width > self.frameWidth - ANCHOR_MARGIN_MIN)
        anchorRect.origin.x = self.frameWidth - anchorRect.size.width - ANCHOR_MARGIN_MIN;
    
    // determine size
    CGFloat stroke = 1.0;
    CGFloat radius = [UIScreen mainScreen].scale == 1 ? 4.5 : 6.0;
    
    rect = CGRectMake(self.bounds.origin.x, self.bounds.origin.y + TOP_SHADOW_BUFFER, self.bounds.size.width, self.bounds.size.height - ANCHOR_HEIGHT);
    rect.size.width -= stroke + 14;
    rect.size.height -= stroke * 2 + TOP_SHADOW_BUFFER + BOTTOM_SHADOW_BUFFER + OFFSET_FROM_ORIGIN;
    rect.origin.x += stroke / 2.0 + 7;
    rect.origin.y += pointingUp ? ANCHOR_HEIGHT - stroke / 2.0 : stroke / 2.0;
    
    
    // General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Color Declarations
    UIColor* fillBlack = [UIColor colorWithRed: 0.11 green: 0.11 blue: 0.11 alpha: 1];
    UIColor* shadowBlack = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.47];
    UIColor* glossBottom = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 0.2];
    UIColor* glossTop = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 0.85];
    UIColor* strokeColor = [UIColor colorWithRed: 0.199 green: 0.199 blue: 0.199 alpha: 1];
    UIColor* innerShadowColor = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 0.4];
    UIColor* innerStrokeColor = [UIColor colorWithRed: 0.821 green: 0.821 blue: 0.821 alpha: 0.04];
    UIColor* outerStrokeColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: 0.35];
    
    // Gradient Declarations
    NSArray* glossFillColors = [NSArray arrayWithObjects:
                                (id)glossBottom.CGColor,
                                (id)glossTop.CGColor, nil];
    CGFloat glossFillLocations[] = {0, 1};
    CGGradientRef glossFill = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)glossFillColors, glossFillLocations);
    
    // Shadow Declarations
    UIColor* baseShadow = shadowBlack;
    CGSize baseShadowOffset = CGSizeMake(0.1, 6.1);
    CGFloat baseShadowBlurRadius = 6;
    UIColor* innerShadow = innerShadowColor;
    CGSize innerShadowOffset = CGSizeMake(0.1, 1.1);
    CGFloat innerShadowBlurRadius = 1;
    
    CGFloat backgroundStrokeWidth = 1;
    CGFloat outerStrokeStrokeWidth = 1;
    
    // Frames
    CGRect frame = rect;
    CGRect innerFrame = CGRectMake(frame.origin.x + backgroundStrokeWidth, frame.origin.y + backgroundStrokeWidth, frame.size.width - backgroundStrokeWidth * 2, frame.size.height - backgroundStrokeWidth * 2);
    CGRect glossFrame = CGRectMake(frame.origin.x - backgroundStrokeWidth / 2, frame.origin.y - backgroundStrokeWidth / 2, frame.size.width + backgroundStrokeWidth, frame.size.height / 2 + backgroundStrokeWidth + 0.5);
    
    //// CoreGroup ////
    {
        CGContextSaveGState(context);
        CGContextSetAlpha(context, 0.83);
        CGContextBeginTransparencyLayer(context, NULL);
        
        // Background Drawing
        UIBezierPath* backgroundPath = [UIBezierPath bezierPath];
        [backgroundPath moveToPoint:CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + radius)];
        [backgroundPath addLineToPoint:CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - radius)]; // left
        [backgroundPath addArcWithCenter:CGPointMake(CGRectGetMinX(frame) + radius, CGRectGetMaxY(frame) - radius) radius:radius startAngle:M_PI endAngle:M_PI / 2 clockwise:NO]; // bottom-left corner
        
        // pointer down
        if (!pointingUp) {
            [backgroundPath addLineToPoint:CGPointMake(CGRectGetMinX(anchorRect), CGRectGetMaxY(frame))];
            [backgroundPath addLineToPoint:CGPointMake(CGRectGetMinX(anchorRect) + anchorRect.size.width / 2, CGRectGetMaxY(frame) + anchorRect.size.height)];
            [backgroundPath addLineToPoint:CGPointMake(CGRectGetMaxX(anchorRect), CGRectGetMaxY(frame))];
        }
        
        [backgroundPath addLineToPoint:CGPointMake(CGRectGetMaxX(frame) - radius, CGRectGetMaxY(frame))]; // bottom
        [backgroundPath addArcWithCenter:CGPointMake(CGRectGetMaxX(frame) - radius, CGRectGetMaxY(frame) - radius) radius:radius startAngle:M_PI / 2 endAngle:0.0f clockwise:NO]; // bottom-right corner
        [backgroundPath addLineToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + radius)]; // right
        [backgroundPath addArcWithCenter:CGPointMake(CGRectGetMaxX(frame) - radius, CGRectGetMinY(frame) + radius) radius:radius startAngle:0.0f endAngle:-M_PI / 2 clockwise:NO]; // top-right corner
        
        // pointer up
        if (pointingUp) {
            [backgroundPath addLineToPoint:CGPointMake(CGRectGetMaxX(anchorRect), CGRectGetMinY(frame))];
            [backgroundPath addLineToPoint:CGPointMake(CGRectGetMinX(anchorRect) + anchorRect.size.width / 2, CGRectGetMinY(frame) - anchorRect.size.height)];
            [backgroundPath addLineToPoint:CGPointMake(CGRectGetMinX(anchorRect), CGRectGetMinY(frame))];
        }
        
        [backgroundPath addLineToPoint:CGPointMake(CGRectGetMinX(frame) + radius, CGRectGetMinY(frame))]; // top
        [backgroundPath addArcWithCenter:CGPointMake(CGRectGetMinX(frame) + radius, CGRectGetMinY(frame) + radius) radius:radius startAngle:-M_PI / 2 endAngle:M_PI clockwise:NO]; // top-left corner
        [backgroundPath closePath];
        CGContextSaveGState(context);
        CGContextSetShadowWithColor(context, baseShadowOffset, baseShadowBlurRadius, baseShadow.CGColor);
        [fillBlack setFill];
        [backgroundPath fill];
        
        // Background Inner Shadow
        CGRect backgroundBorderRect = CGRectInset([backgroundPath bounds], -innerShadowBlurRadius, -innerShadowBlurRadius);
        backgroundBorderRect = CGRectOffset(backgroundBorderRect, -innerShadowOffset.width, -innerShadowOffset.height);
        backgroundBorderRect = CGRectInset(CGRectUnion(backgroundBorderRect, [backgroundPath bounds]), -1, -1);
        
        UIBezierPath* backgroundNegativePath = [UIBezierPath bezierPathWithRect: backgroundBorderRect];
        [backgroundNegativePath appendPath: backgroundPath];
        backgroundNegativePath.usesEvenOddFillRule = YES;
        
        CGContextSaveGState(context);
        {
            CGFloat xOffset = innerShadowOffset.width + round(backgroundBorderRect.size.width);
            CGFloat yOffset = innerShadowOffset.height;
            CGContextSetShadowWithColor(context,
                                        CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                        innerShadowBlurRadius,
                                        innerShadow.CGColor);
            
            [backgroundPath addClip];
            CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(backgroundBorderRect.size.width), 0);
            [backgroundNegativePath applyTransform: transform];
            [[UIColor grayColor] setFill];
            [backgroundNegativePath fill];
        }
        CGContextRestoreGState(context);
        
        CGContextRestoreGState(context);
        
        [strokeColor setStroke];
        backgroundPath.lineWidth = backgroundStrokeWidth;
        [backgroundPath stroke];
        
        
        // Inner Stroke Drawing
        CGFloat innerRadius = radius - 1.0;
        CGRect anchorInnerRect = anchorRect;
        anchorInnerRect.origin.x += backgroundStrokeWidth / 2;
        anchorInnerRect.origin.y -= backgroundStrokeWidth / 2;
        anchorInnerRect.size.width -= backgroundStrokeWidth;
        anchorInnerRect.size.height -= backgroundStrokeWidth / 2;
        
        UIBezierPath* innerStrokePath = [UIBezierPath bezierPath];
        [innerStrokePath moveToPoint:CGPointMake(CGRectGetMinX(innerFrame), CGRectGetMinY(innerFrame) + innerRadius)];
        [innerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(innerFrame), CGRectGetMaxY(innerFrame) - innerRadius)]; // left
        [innerStrokePath addArcWithCenter:CGPointMake(CGRectGetMinX(innerFrame) + innerRadius, CGRectGetMaxY(innerFrame) - innerRadius) radius:innerRadius startAngle:M_PI endAngle:M_PI / 2 clockwise:NO]; // bottom-left corner
        
        // pointer down
        if (!pointingUp) {
            [innerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(anchorInnerRect), CGRectGetMaxY(innerFrame))];
            [innerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(anchorInnerRect) + anchorInnerRect.size.width / 2, CGRectGetMaxY(innerFrame) + anchorInnerRect.size.height)];
            [innerStrokePath addLineToPoint:CGPointMake(CGRectGetMaxX(anchorInnerRect), CGRectGetMaxY(innerFrame))];
        }
        
        [innerStrokePath addLineToPoint:CGPointMake(CGRectGetMaxX(innerFrame) - innerRadius, CGRectGetMaxY(innerFrame))]; // bottom
        [innerStrokePath addArcWithCenter:CGPointMake(CGRectGetMaxX(innerFrame) - innerRadius, CGRectGetMaxY(innerFrame) - innerRadius) radius:innerRadius startAngle:M_PI / 2 endAngle:0.0f clockwise:NO]; // bottom-right corner
        [innerStrokePath addLineToPoint: CGPointMake(CGRectGetMaxX(innerFrame), CGRectGetMinY(innerFrame) + innerRadius)]; // right
        [innerStrokePath addArcWithCenter:CGPointMake(CGRectGetMaxX(innerFrame) - innerRadius, CGRectGetMinY(innerFrame) + innerRadius) radius:innerRadius startAngle:0.0f endAngle:-M_PI / 2 clockwise:NO]; // top-right corner
        
        // pointer up
        if (pointingUp) {
            [innerStrokePath addLineToPoint:CGPointMake(CGRectGetMaxX(anchorInnerRect), CGRectGetMinY(innerFrame))];
            [innerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(anchorInnerRect) + anchorRect.size.width / 2, CGRectGetMinY(innerFrame) - anchorInnerRect.size.height)];
            [innerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(anchorInnerRect), CGRectGetMinY(innerFrame))];
        }
        
        [innerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(innerFrame) + innerRadius, CGRectGetMinY(innerFrame))]; // top
        [innerStrokePath addArcWithCenter:CGPointMake(CGRectGetMinX(innerFrame) + innerRadius, CGRectGetMinY(innerFrame) + innerRadius) radius:innerRadius startAngle:-M_PI / 2 endAngle:M_PI clockwise:NO]; // top-left corner
        [innerStrokePath closePath];
        
        [innerStrokeColor setStroke];
        innerStrokePath.lineWidth = backgroundStrokeWidth;
        [innerStrokePath stroke];
        
        
        //// GlossGroup ////
        {
            CGContextSaveGState(context);
            CGContextSetAlpha(context, 0.45);
            CGContextBeginTransparencyLayer(context, NULL);
            
            CGFloat glossRadius = radius + 0.5;
            
            // Gloss Drawing
            UIBezierPath* glossPath = [UIBezierPath bezierPath];
            [glossPath moveToPoint:CGPointMake(CGRectGetMinX(glossFrame), CGRectGetMinY(glossFrame))];
            [glossPath addLineToPoint:CGPointMake(CGRectGetMinX(glossFrame), CGRectGetMaxY(glossFrame) - glossRadius)]; // left
            [glossPath addArcWithCenter:CGPointMake(CGRectGetMinX(glossFrame) + glossRadius, CGRectGetMaxY(glossFrame) - glossRadius) radius:glossRadius startAngle:M_PI endAngle:M_PI / 2 clockwise:NO]; // bottom-left corner
            [glossPath addLineToPoint:CGPointMake(CGRectGetMaxX(glossFrame) - glossRadius, CGRectGetMaxY(glossFrame))]; // bottom
            [glossPath addArcWithCenter:CGPointMake(CGRectGetMaxX(glossFrame) - glossRadius, CGRectGetMaxY(glossFrame) - glossRadius) radius:glossRadius startAngle:M_PI / 2 endAngle:0.0f clockwise:NO]; // bottom-right corner
            [glossPath addLineToPoint: CGPointMake(CGRectGetMaxX(glossFrame), CGRectGetMinY(glossFrame) - glossRadius)]; // right
            [glossPath addArcWithCenter:CGPointMake(CGRectGetMaxX(glossFrame) - glossRadius, CGRectGetMinY(glossFrame) + glossRadius) radius:glossRadius startAngle:0.0f endAngle:-M_PI / 2 clockwise:NO]; // top-right corner
            
            // pointer up
            if (pointingUp) {
                [glossPath addLineToPoint:CGPointMake(CGRectGetMaxX(anchorRect), CGRectGetMinY(glossFrame))];
                [glossPath addLineToPoint:CGPointMake(CGRectGetMinX(anchorRect) + roundf(anchorRect.size.width / 2), CGRectGetMinY(glossFrame) - anchorRect.size.height)];
                [glossPath addLineToPoint:CGPointMake(CGRectGetMinX(anchorRect), CGRectGetMinY(glossFrame))];
            }
            
            [glossPath addLineToPoint:CGPointMake(CGRectGetMinX(glossFrame) + glossRadius, CGRectGetMinY(glossFrame))]; // top
            [glossPath addArcWithCenter:CGPointMake(CGRectGetMinX(glossFrame) + glossRadius, CGRectGetMinY(glossFrame) + glossRadius) radius:glossRadius startAngle:-M_PI / 2 endAngle:M_PI clockwise:NO]; // top-left corner
            [glossPath closePath];
            
            CGContextSaveGState(context);
            [glossPath addClip];
            CGRect glossBounds = glossPath.bounds;
            CGContextDrawLinearGradient(context, glossFill,
                                        CGPointMake(CGRectGetMidX(glossBounds), CGRectGetMaxY(glossBounds)),
                                        CGPointMake(CGRectGetMidX(glossBounds), CGRectGetMinY(glossBounds)),
                                        0);
            CGContextRestoreGState(context);
            
            CGContextEndTransparencyLayer(context);
            CGContextRestoreGState(context);
        }
        
        CGContextEndTransparencyLayer(context);
        CGContextRestoreGState(context);
    }
    
    // Outer Stroke Drawing
    UIBezierPath* outerStrokePath = [UIBezierPath bezierPath];
    [outerStrokePath moveToPoint:CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + radius)];
    [outerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - radius)]; // left
    [outerStrokePath addArcWithCenter:CGPointMake(CGRectGetMinX(frame) + radius, CGRectGetMaxY(frame) - radius) radius:radius startAngle:M_PI endAngle:M_PI / 2 clockwise:NO]; // bottom-left corner
    
    // pointer down
    if (!pointingUp) {
        [outerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(anchorRect), CGRectGetMaxY(frame))];
        [outerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(anchorRect) + anchorRect.size.width / 2, CGRectGetMaxY(frame) + anchorRect.size.height)];
        [outerStrokePath addLineToPoint:CGPointMake(CGRectGetMaxX(anchorRect), CGRectGetMaxY(frame))];
    }
    
    [outerStrokePath addLineToPoint:CGPointMake(CGRectGetMaxX(frame) - radius, CGRectGetMaxY(frame))]; // bottom
    [outerStrokePath addArcWithCenter:CGPointMake(CGRectGetMaxX(frame) - radius, CGRectGetMaxY(frame) - radius) radius:radius startAngle:M_PI / 2 endAngle:0.0f clockwise:NO]; // bottom-right corner
    [outerStrokePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + radius)]; // right
    [outerStrokePath addArcWithCenter:CGPointMake(CGRectGetMaxX(frame) - radius, CGRectGetMinY(frame) + radius) radius:radius startAngle:0.0f endAngle:-M_PI / 2 clockwise:NO]; // top-right corner
    
    // pointer up
    if (pointingUp) {
        [outerStrokePath addLineToPoint:CGPointMake(CGRectGetMaxX(anchorRect), CGRectGetMinY(frame))];
        [outerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(anchorRect) + anchorRect.size.width / 2, CGRectGetMinY(frame) - anchorRect.size.height)];
        [outerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(anchorRect), CGRectGetMinY(frame))];
    }
    
    [outerStrokePath addLineToPoint:CGPointMake(CGRectGetMinX(frame) + radius, CGRectGetMinY(frame))]; // top
    [outerStrokePath addArcWithCenter:CGPointMake(CGRectGetMinX(frame) + radius, CGRectGetMinY(frame) + radius) radius:radius startAngle:-M_PI / 2 endAngle:M_PI clockwise:NO]; // top-left corner
    [outerStrokePath closePath];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, baseShadowOffset, baseShadowBlurRadius, baseShadow.CGColor);
    CGContextRestoreGState(context);
    
    [outerStrokeColor setStroke];
    outerStrokePath.lineWidth = outerStrokeStrokeWidth;
    [outerStrokePath stroke];
    
    //// Cleanup
    CGGradientRelease(glossFill);
    CGColorSpaceRelease(colorSpace);
}

@end
