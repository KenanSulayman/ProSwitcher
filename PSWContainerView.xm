
#import "PSWContainerView.h"
#import "PSWPageView.h"
#import "PSWPreferences.h"
#import "PSWResources.h"

%class SBIconModel;
%class SBIconController;

__attribute__((visibility("hidden")))
CGRect PSWProportionalInsetsInsetRect(CGRect rect, PSWProportionalInsets insets)
{
	UIEdgeInsets realInsets;
	realInsets.top = rect.size.height * insets.top;
	realInsets.bottom = rect.size.height * insets.bottom;
	realInsets.left = rect.size.width * insets.left;
	realInsets.right = rect.size.height * insets.right;
	
	CGRect ret = UIEdgeInsetsInsetRect(rect, realInsets); 
	return ret;
}

@implementation PSWContainerView

@synthesize pageControl = _pageControl;
@synthesize pageView = _pageView;
@synthesize doubleTapped = _doubleTapped;

- (id)init
{
	if ((self = [super init])) {
		[self setUserInteractionEnabled:YES];
		
		_pageControl = [[UIPageControl alloc] init];
		[_pageControl setCurrentPage:0];
		[_pageControl setHidesForSinglePage:YES];
		[_pageControl setUserInteractionEnabled:NO];
		[_pageControl setHidden:GetPreference(PSWShowPageControl, BOOL)];
		[self addSubview:_pageControl];
		
		_emptyLabel = [[UILabel alloc] init];
		[_emptyLabel setBackgroundColor:[UIColor clearColor]];
		[_emptyLabel setTextAlignment:UITextAlignmentCenter];
		[_emptyLabel setFont:[UIFont boldSystemFontOfSize:16.0f]];
		[_emptyLabel setTextColor:[UIColor whiteColor]];
		[_emptyLabel setText:@"No Apps Running"];
		[self addSubview:_emptyLabel];
		[_emptyLabel setHidden:YES];
		
		[self setBackgroundColor:[UIColor clearColor]];
		if (GetPreference(PSWDimBackground, BOOL))
			[self setBackgroundColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8]];
			
		if (GetPreference(PSWBackgroundStyle, NSInteger) == PSWBackgroundStyleImage)
			[[self layer] setContents:(id) [PSWImage(@"Background") CGImage]];
		else
			[[self layer] setContents:nil];

		_emptyTapClose = YES; 
		_autoExit = NO;
		
		[self setIsEmpty:YES];
		[self setNeedsLayout];
		[self layoutIfNeeded];
	}
	
	return self;
}

- (void)dealloc
{
	[_emptyLabel release];
	[_pageControl release];
	[_pageView release];
	
	[super dealloc];
}

- (void)_applyInsets
{
	CGRect edge = UIEdgeInsetsInsetRect([self bounds], _pageViewEdgeInsets);
	CGRect proportional = PSWProportionalInsetsInsetRect(edge, _pageViewInsets);
	[_pageView setFrame:proportional];
}

- (void)setFrame:(CGRect)frame {
	[super setFrame:frame];
	[self _applyInsets];
}

- (void)layoutSubviews
{
	CGRect frame;
	frame.size = [[_emptyLabel text] sizeWithFont:_emptyLabel.font];
	CGSize size = [self bounds].size;
	frame.origin.x = (NSInteger) (size.width - frame.size.width) / 2;
	frame.origin.y = (NSInteger) (size.height - frame.size.height) / 2;
	[_emptyLabel setFrame:frame];
	
	// Fix page control positioning by retrieving it from the SpringBoard page control
	SBIconListPageControl *pageControl = MSHookIvar<SBIconListPageControl *>([$SBIconController sharedInstance], "_pageControl");
	frame = [self convertRect:[pageControl frame] fromView:[pageControl superview]];
	[_pageControl setFrame:frame];
	
	PSWApplication *focusedApplication = [_pageView focusedApplication];
	frame.origin.x = 0.0f;
	frame.origin.y = 0.0f;
	frame.size = size;
	[_pageView setFrame:UIEdgeInsetsInsetRect(frame, _pageViewEdgeInsets)];
	[_pageView setFocusedApplication:focusedApplication];
}

- (void)shouldExit
{
	[_pageView shouldExit];
}

- (UIEdgeInsets)pageViewEdgeInsets
{
	return _pageViewEdgeInsets;
}
- (void)setPageViewEdgeInsets:(UIEdgeInsets)pageViewEdgeInsets
{
	_pageViewEdgeInsets = pageViewEdgeInsets;
	[self _applyInsets];
}

- (PSWProportionalInsets)pageViewInsets
{
	return _pageViewInsets;
}
- (void)setPageViewInsets:(PSWProportionalInsets)pageViewInsets
{
	_pageViewInsets = pageViewInsets;
	[self _applyInsets];
}

- (void)setPageView:(PSWPageView *)pageView
{
	if (_pageView != pageView) {
		[_pageView release];
		_pageView = [pageView retain];
		
		[self setNeedsLayout];
	}
}

- (BOOL)isEmpty
{
	return _isEmpty;
}

- (void)setIsEmpty:(BOOL)isEmpty
{
	_isEmpty = isEmpty;
	
	if (_autoExit && _isEmpty)
		[self shouldExit];
		
	[_emptyLabel setHidden:!_isEmpty];
}

- (void)setPageControlCount:(NSInteger)count
{
	[_pageControl setNumberOfPages:count];
	
	[self setIsEmpty:!count];
}

- (NSInteger)pageControlPage
{
	return [_pageControl currentPage];
}

- (void)setPageControlPage:(NSInteger)page
{
	[_pageControl setCurrentPage:page];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	UIView *result = [super hitTest:point withEvent:event];
	if (![self isEmpty] && (result == self))
		result = _pageView;
	return result;
}

- (void)tapPreviousAndContinue
{
	[_pageView movePrevious];
	_shouldScrollOnUp = NO;
}

- (void)tapNextAndContinue
{
	[_pageView moveNext];
	_shouldScrollOnUp = NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{	
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	CGPoint offset = [_pageView frame].origin;

	point.x -= offset.x;
	
	if (point.x <= 0.0f) {
		[self performSelector:@selector(tapPreviousAndContinue) withObject:nil afterDelay:0.1f];
	} else if (point.x > [_pageView bounds].size.width) {
		[self performSelector:@selector(tapNextAndContinue) withObject:nil afterDelay:0.1f];
	}
	
	_shouldScrollOnUp = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
	
	_shouldScrollOnUp = NO;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (_isEmpty && _emptyTapClose)
		[self shouldExit];
	
	UITouch *touch = [touches anyObject];
	NSInteger tapCount = [touch tapCount];
	CGPoint point = [touch locationInView:self];
	CGPoint offset = [_pageView frame].origin;

	point.x -= offset.x;

	_doubleTapped = NO;
	if (tapCount == 2) {
		_doubleTapped = YES;
		
		if (point.x <= 0.0f) {
			[_pageView moveToStart];
		} else {
			[_pageView moveToEnd];
		}
	} else if (_shouldScrollOnUp) {
		if (point.x <= 0.0f) {
			[self tapPreviousAndContinue];
		} else if (point.x > [_pageView bounds].size.width) {
			[self tapNextAndContinue];
		}
	}
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
	_shouldScrollOnUp = NO;
}

@end
