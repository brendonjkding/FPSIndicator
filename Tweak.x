#import <notify.h>
#import <substrate.h>
#import <libcolorpicker.h>
#import <objc/runtime.h>


enum FPSMode{
	kModeAverage=1,
	kModePerSecond
};

static BOOL enabled;
static enum FPSMode fpsMode;

static dispatch_source_t _timer;
static UILabel *fpsLabel;

static void loadPref(){
	NSLog(@"loadPref..........");
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];

	enabled=prefs[@"enabled"]?[prefs[@"enabled"] boolValue]:YES;
	fpsMode=prefs[@"fpsMode"]?[prefs[@"fpsMode"] intValue]:0;
	if(fpsMode==0) fpsMode++; //0.0.2 compatibility 

	NSString *colorString = prefs[@"color"]?:@"#ffff00"; 
    UIColor *color = LCPParseColorString(colorString, nil);

	[fpsLabel setHidden:!enabled];
	[fpsLabel setTextColor:color];

}
static BOOL isEnabledApp(){
	NSString* bundleIdentifier=[[NSBundle mainBundle] bundleIdentifier];
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:kPrefPath];
	return [prefs[@"apps"] containsObject:bundleIdentifier];
}


double FPSavg = 0;
double FPSPerSecond = 0;

static void startRefreshTimer(){
	_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), (1.0/5.0) * NSEC_PER_SEC, 0);

    dispatch_source_set_event_handler(_timer, ^{
    	switch(fpsMode){
		    case kModeAverage:
		    	[fpsLabel setText:[NSString stringWithFormat:@"%.1lf",FPSavg]];
		    	break;
		    case kModePerSecond:
		    	[fpsLabel setText:[NSString stringWithFormat:@"%.1lf",FPSPerSecond]];
		    	break;
		    default:
		    	break;
    	}

    	NSLog(@"%.1lf %.1lf",FPSavg,FPSPerSecond);

    });
    dispatch_resume(_timer); 
}

#pragma mark ui
#define kFPSLabelWidth 50
#define kFPSLabelHeight 20
%group ui
%hook UIWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect bounds=[self bounds];
        fpsLabel= [[UILabel alloc] initWithFrame:CGRectMake(bounds.size.width-kFPSLabelWidth-5.,0,kFPSLabelWidth,kFPSLabelHeight)];
        fpsLabel.font=[UIFont fontWithName:@"Helvetica-Bold" size:16];
        fpsLabel.textAlignment=NSTextAlignmentRight;
        
        [self addSubview:fpsLabel];
        loadPref();
        startRefreshTimer();
    });
	return %orig;
}
%end
%end//ui

// credits to https://github.com/masagrator/NX-FPS/blob/master/source/main.cpp#L64
void frameTick(){
	static double FPS_temp = 0;
	static double starttick = 0;
	static double endtick = 0;
	static double deltatick = 0;
	static double frameend = 0;
	static double framedelta = 0;
	static double frameavg = 0;
	
	if (starttick == 0) starttick = CACurrentMediaTime()*1000.0;
	endtick = CACurrentMediaTime()*1000.0;
	framedelta = endtick - frameend;
	frameavg = ((9*frameavg) + framedelta) / 10;
	FPSavg = 1000.0f / (double)frameavg;
	frameend = endtick;
	
	FPS_temp++;
	deltatick = endtick - starttick;
	if (deltatick >= 1000.0f) {
		starttick = CACurrentMediaTime()*1000.0;
		FPSPerSecond = FPS_temp - 1;
		FPS_temp = 0;
	}
	
	return;
}

#pragma mark gl
%group gl
%hook EAGLContext 
- (BOOL)presentRenderbuffer:(NSUInteger)target{
	BOOL ret=%orig;
	frameTick();
	return ret;
}
%end
%end//gl

#pragma mark metal
%group metal
%hook CAMetalDrawable
- (void)present{
	%orig;
	frameTick();
}
- (void)presentAfterMinimumDuration:(CFTimeInterval)duration{
	%orig;
	frameTick();
}
- (void)presentAtTime:(CFTimeInterval)presentationTime{
	%orig;
	frameTick();
}
%end //CAMetalDrawable
%end//metal


%ctor{
	if(!isEnabledApp()) return;
	NSLog(@"ctor: FPSIndicator");

	%init(ui);
	%init(gl);
	%init(metal);

	int token = 0;
	notify_register_dispatch("com.brend0n.fpsindicator/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
		loadPref();
	});
}
