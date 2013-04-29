//
// UIScrollView+SVInfiniteScrolling.m
//
// Created by Sam Vermette on 23.04.12.
// Copyright (c) 2012 samvermette.com. All rights reserved.
//
// https://github.com/samvermette/SVPullToRefresh
//

#import <QuartzCore/QuartzCore.h>
#import "UIScrollView+SVInfiniteScrolling.h"

static CGFloat const SVInfiniteScrollingViewHeight = 60;

@interface SVInfiniteScrollingDotView : UIView

@property (nonatomic, strong) UIColor *arrowColor;

@end



@interface SVInfiniteScrollingView ()

@property (nonatomic, copy) void (^infiniteScrollingHandler)(void);

@property (nonatomic, strong) UIActivityIndicatorView *activityIndicatorView;
@property (nonatomic, readwrite) SVInfiniteScrollingState state;
@property (nonatomic, strong) NSMutableArray *viewForState;
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, readwrite) CGFloat originalTopInset;
@property (nonatomic, readwrite) CGFloat originalBottomInset;
@property (nonatomic, assign) BOOL wasTriggeredByUser;
@property (nonatomic, assign) BOOL isObserving;
@property (nonatomic, readwrite) SVInfiniteScrollingPosition position;

- (void)resetScrollViewContentInsetForPosition:(SVInfiniteScrollingPosition)position;
- (void)setScrollViewContentInsetForInfiniteScrollingPosition:(SVInfiniteScrollingPosition)position;
- (void)setScrollViewContentInset:(UIEdgeInsets)insets;

@end



#pragma mark - UIScrollView (SVInfiniteScrollingView)
#import <objc/runtime.h>

static char UIScrollViewInfiniteScrollingViewTop;
static char UIScrollViewInfiniteScrollingViewBottom;
static char kSVInfiniteScrollingUpdatingKey;

UIEdgeInsets scrollViewOriginalContentInsets;

@implementation UIScrollView (SVInfiniteScrolling)



- (void)addInfiniteScrollingWithActionHandler:(void (^)(void))actionHandler forPosition:(SVInfiniteScrollingPosition)position{
    
    if(![self infiniteScrollingViewForPosition:position]) {
        SVInfiniteScrollingView *view = [[SVInfiniteScrollingView alloc] initWithFrame:CGRectMake(0, (position == SVInfiniteScrollingPositionTop) ? -SVInfiniteScrollingViewHeight : self.contentSize.height, self.bounds.size.width, SVInfiniteScrollingViewHeight)];
        view.infiniteScrollingHandler = actionHandler;
        view.scrollView = self;
        view.position = position;
        [self addSubview:view];
        
        if (position == SVInfiniteScrollingPositionTop) {
            
            view.originalTopInset = self.contentInset.top;
            
        }
        else
        {
            view.originalBottomInset = self.contentInset.bottom;
        }
        
        
        
        [self setInfiniteScrollingView:view forPosition:position];
        [self setShowsInfiniteScrolling:YES forPosition:position];
        
    }
    
}

- (void)triggerInfiniteScrollingForPosition:(SVInfiniteScrollingPosition)position{
    SVInfiniteScrollingView *view = [self infiniteScrollingViewForPosition:position];
    view.state = SVInfiniteScrollingStateTriggered;
    [view startAnimating];
}

- (void)setInfiniteScrollingView:(SVInfiniteScrollingView *)infiniteScrollingView forPosition:(SVInfiniteScrollingPosition)position {
    
    switch (position) {
        case SVInfiniteScrollingPositionTop:
        {
            [self willChangeValueForKey:@"UIScrollViewInfiniteScrollingViewTop"];
            objc_setAssociatedObject(self, &UIScrollViewInfiniteScrollingViewTop,
                                     infiniteScrollingView,
                                     OBJC_ASSOCIATION_ASSIGN);
            [self didChangeValueForKey:@"UIScrollViewInfiniteScrollingViewTop"];
        }
            break;
        case SVInfiniteScrollingPositionBottom:
        {
            [self willChangeValueForKey:@"UIScrollViewInfiniteScrollingViewBottom"];
            objc_setAssociatedObject(self, &UIScrollViewInfiniteScrollingViewBottom,
                                     infiniteScrollingView,
                                     OBJC_ASSOCIATION_ASSIGN);
            [self didChangeValueForKey:@"UIScrollViewInfiniteScrollingViewBottom"];
        }
            break;
        default:
            break;
    }
    
}

- (SVInfiniteScrollingView *)infiniteScrollingViewForPosition:(SVInfiniteScrollingPosition)position {
    
    return objc_getAssociatedObject(self, (position == SVInfiniteScrollingPositionTop) ? &UIScrollViewInfiniteScrollingViewTop : &UIScrollViewInfiniteScrollingViewBottom);
}

- (void)setShowsInfiniteScrolling:(BOOL)visible forPosition:(SVInfiniteScrollingPosition)position{
    
    SVInfiniteScrollingView *view = [self infiniteScrollingViewForPosition:position];
    view.hidden = !visible;
    
    if(!visible) {
        if (view.isObserving) {
            [self removeObserver:view forKeyPath:@"contentOffset"];
            [self removeObserver:view forKeyPath:@"contentSize"];
            
            [view resetScrollViewContentInsetForPosition:position];
            view.isObserving = NO;
        }
    }
    else {
        if (!view.isObserving) {
            
            objc_setAssociatedObject(self, &kSVInfiniteScrollingUpdatingKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [self addObserver:view forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
            [self addObserver:view forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
            [view setScrollViewContentInsetForInfiniteScrollingPosition:position];
            view.isObserving = YES;
            [view setNeedsLayout];
            view.frame = CGRectMake(0, (position == SVInfiniteScrollingPositionTop) ? -SVInfiniteScrollingViewHeight : self.contentSize.height, view.bounds.size.width, SVInfiniteScrollingViewHeight);
            
            double delayInSeconds = 0.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                self.contentOffset = CGPointMake(0, 0);
                objc_setAssociatedObject(self, &kSVInfiniteScrollingUpdatingKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            });
        }
    }
    
    
}

- (BOOL)showsInfiniteScrollingForPosition:(SVInfiniteScrollingPosition)position{
    
    return ![self infiniteScrollingViewForPosition:position].hidden;
    
}


@end


#pragma mark - SVInfiniteScrollingView
@implementation SVInfiniteScrollingView

static const CGFloat kAnimationDuration = 0.3f;

- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithFrame:frame]) {
        
        // default styling values
        self.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.state = SVInfiniteScrollingStateStopped;
        self.enabled = YES;
        
        self.viewForState = [NSMutableArray arrayWithObjects:@"", @"", @"", @"", nil];
    }
    
    return self;
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    if (self.superview && newSuperview == nil) {
        UIScrollView *scrollView = (UIScrollView *)self.superview;
        if ([scrollView showsInfiniteScrollingForPosition:self.position]) {
          if (self.isObserving) {
            [scrollView removeObserver:self forKeyPath:@"contentOffset"];
            [scrollView removeObserver:self forKeyPath:@"contentSize"];
            self.isObserving = NO;
          }
        }
    }
}

- (void)layoutSubviews {
    self.activityIndicatorView.center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
}

#pragma mark - Scroll View

- (void)resetScrollViewContentInsetForPosition:(SVInfiniteScrollingPosition)position {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    
    if (position == SVInfiniteScrollingPositionTop) {
        currentInsets.top = self.originalTopInset;
    }
    else
    {
        currentInsets.bottom = self.originalBottomInset;
    }
    
    self.scrollView.contentInset = currentInsets;
}

- (void)setScrollViewContentInsetForInfiniteScrollingPosition:(SVInfiniteScrollingPosition)position {
    UIEdgeInsets currentInsets = self.scrollView.contentInset;
    
    if (position == SVInfiniteScrollingPositionTop) {
        currentInsets.top = self.originalTopInset + SVInfiniteScrollingViewHeight;
        
    }
    else
    {
        currentInsets.bottom = self.originalBottomInset + SVInfiniteScrollingViewHeight;
        
    }
    
    self.scrollView.contentInset = currentInsets;
    
}

- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset{
    [UIView animateWithDuration:kAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
                         self.scrollView.contentInset = contentInset;
                     }
                     completion:NULL];
}

#pragma mark - Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {    
    if([keyPath isEqualToString:@"contentOffset"])
        [self scrollViewDidScroll:[[change valueForKey:NSKeyValueChangeNewKey] CGPointValue]];
    else if([keyPath isEqualToString:@"contentSize"]) {
        [self layoutSubviews];
        
        if (self.position == SVInfiniteScrollingPositionTop) {
            self.frame = CGRectMake(0, -SVInfiniteScrollingViewHeight, self.bounds.size.width, SVInfiniteScrollingViewHeight);
        }
        else
        {
            self.frame = CGRectMake(0, self.scrollView.contentSize.height, self.bounds.size.width, SVInfiniteScrollingViewHeight);
        }
        
        
    }
}

- (void)scrollViewDidScroll:(CGPoint)contentOffset {
    if(self.state != SVInfiniteScrollingStateLoading && self.enabled) {
        CGFloat scrollViewContentHeight = self.scrollView.contentSize.height;
        CGFloat scrollOffsetThreshold = 0;
        
        NSNumber *updating = objc_getAssociatedObject(self.scrollView, &kSVInfiniteScrollingUpdatingKey);
        
        BOOL isUpdating = [updating boolValue];
        
        if (self.position == SVInfiniteScrollingPositionTop){
            scrollOffsetThreshold = 0;
            if(!self.scrollView.isDragging && self.state == SVInfiniteScrollingStateTriggered)
                self.state = SVInfiniteScrollingStateLoading;
            else if(contentOffset.y < scrollOffsetThreshold && self.state == SVInfiniteScrollingStateStopped && !isUpdating)
                self.state = SVInfiniteScrollingStateTriggered;
            else if(contentOffset.y > scrollOffsetThreshold  && self.state != SVInfiniteScrollingStateStopped)
                self.state = SVInfiniteScrollingStateStopped;
        }
        else
        {
            scrollOffsetThreshold = scrollViewContentHeight-self.scrollView.bounds.size.height;
            if(!self.scrollView.isDragging && self.state == SVInfiniteScrollingStateTriggered)
                self.state = SVInfiniteScrollingStateLoading;
            else if(contentOffset.y > scrollOffsetThreshold && self.state == SVInfiniteScrollingStateStopped && !isUpdating)
                self.state = SVInfiniteScrollingStateTriggered;
            else if(contentOffset.y < scrollOffsetThreshold  && self.state != SVInfiniteScrollingStateStopped)
                self.state = SVInfiniteScrollingStateStopped;
        }
    }
}

#pragma mark - Getters

- (UIActivityIndicatorView *)activityIndicatorView {
    if(!_activityIndicatorView) {
        _activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        _activityIndicatorView.hidesWhenStopped = YES;
        [self addSubview:_activityIndicatorView];
    }
    return _activityIndicatorView;
}

- (UIActivityIndicatorViewStyle)activityIndicatorViewStyle {
    return self.activityIndicatorView.activityIndicatorViewStyle;
}

#pragma mark - Setters

- (void)setCustomView:(UIView *)view forState:(SVInfiniteScrollingState)state {
    id viewPlaceholder = view;
    
    if(!viewPlaceholder)
        viewPlaceholder = @"";
    
    if(state == SVInfiniteScrollingStateAll)
        [self.viewForState replaceObjectsInRange:NSMakeRange(0, 3) withObjectsFromArray:@[viewPlaceholder, viewPlaceholder, viewPlaceholder]];
    else
        [self.viewForState replaceObjectAtIndex:state withObject:viewPlaceholder];
    
    self.state = self.state;
}

- (void)setActivityIndicatorViewStyle:(UIActivityIndicatorViewStyle)viewStyle {
    self.activityIndicatorView.activityIndicatorViewStyle = viewStyle;
}

#pragma mark -

- (void)triggerRefresh {
    self.state = SVInfiniteScrollingStateTriggered;
    self.state = SVInfiniteScrollingStateLoading;
}

- (void)startAnimating{
    self.state = SVInfiniteScrollingStateLoading;
}

- (void)stopAnimating {
    self.state = SVInfiniteScrollingStateStopped;
}

- (void)setState:(SVInfiniteScrollingState)newState {
    
    if(_state == newState)
        return;
    
    SVInfiniteScrollingState previousState = _state;
    _state = newState;
    
    for(id otherView in self.viewForState) {
        if([otherView isKindOfClass:[UIView class]])
            [otherView removeFromSuperview];
    }
    
    id customView = [self.viewForState objectAtIndex:newState];
    BOOL hasCustomView = [customView isKindOfClass:[UIView class]];
    
    if(hasCustomView) {
        [self addSubview:customView];
        CGRect viewBounds = [customView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        [customView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
    }
    else {
        CGRect viewBounds = [self.activityIndicatorView bounds];
        CGPoint origin = CGPointMake(roundf((self.bounds.size.width-viewBounds.size.width)/2), roundf((self.bounds.size.height-viewBounds.size.height)/2));
        
        
        [self.activityIndicatorView setFrame:CGRectMake(origin.x, origin.y, viewBounds.size.width, viewBounds.size.height)];
        
        switch (newState) {
            case SVInfiniteScrollingStateStopped:
                [self.activityIndicatorView stopAnimating];
                
                if (self.position == SVInfiniteScrollingPositionTop) {
                    if (!self.scrollView.isDragging) {
                        [UIView animateWithDuration:kAnimationDuration
                                              delay:0
                                            options:0
                                         animations:^{
                                             self.scrollView.contentOffset = CGPointMake(0, self.scrollView.contentOffset.y - SVInfiniteScrollingViewHeight);
                                         }
                                         completion:NULL];
                    }
                    
                }
                
                break;
                
            case SVInfiniteScrollingStateTriggered:
            case SVInfiniteScrollingStateAll:
                break;
                
            case SVInfiniteScrollingStateLoading:
                [self.activityIndicatorView startAnimating];
                break;
            default:
                break;
        }
    }
    
    if(previousState == SVInfiniteScrollingStateTriggered && newState == SVInfiniteScrollingStateLoading && self.infiniteScrollingHandler && self.enabled)
        self.infiniteScrollingHandler();
}

@end
