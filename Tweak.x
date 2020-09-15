#import <notify.h>
#import <substrate.h>
#import <notify.h>
#import <readmem/readmem.h>
#import <libcolorpicker/libcolorpicker.h>
#import <objc/runtime.h>
@import MetalKit;

extern intptr_t _dyld_get_image_vmaddr_slide(uint32_t image_index);

enum FPSMode{
	kModePerFrame,
	kModeAverage,
	kModePerSecond
};

BOOL enabled;
uint64_t main_address;
long main_size;
enum FPSMode fpsMode;

long aslr;
dispatch_source_t _timer;
UILabel *fpsLabel;

BOOL loadPref(){
	NSLog(@"loadPref..........");
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.brend0n.unityfpsindicator.plist"];
	if(!prefs) prefs=[NSMutableDictionary new];
	enabled=prefs[@"enabled"]?[prefs[@"enabled"] boolValue]:YES;
	fpsMode=prefs[@"fpsMode"]?[prefs[@"fpsMode"] intValue]:0;

	NSString *colorString = prefs?(prefs[@"color"]?:@"#ffff00"):@"#ffff00"; 
    UIColor *color = LCPParseColorString(colorString, nil);

	[fpsLabel setHidden:!enabled];
	[fpsLabel setTextColor:color];
	return enabled;
}
BOOL is_enabled_app(){
	NSString* bundleIdentifier=[[NSBundle mainBundle] bundleIdentifier];
	// NSArray *fgo_ids=@[@"com.xiaomeng.fategrandorder",@"com.bilibili.fatego",@"com.aniplex.fategrandorder",@"com.aniplex.fategrandorder.en"];
	// if([fgo_ids containsObject:bundleIdentifier])return true;
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.brend0n.unityfpsindicator.plist"];
	NSArray *apps=prefs?prefs[@"apps"]:nil;
	if(!apps) return NO;
	if([apps containsObject:bundleIdentifier]) return YES;
	
	return NO;
}
static inline uint64_t get_page_address_64(uint64_t addr, uint32_t pagesize)
{
	return addr&~0xfff;
}
static inline bool is_adrp(int32_t ins){
    return (((ins>>24)&0b11111)==0b10000) && (ins>>31);
}
static inline bool is_64add(int32_t ins){
    return ((ins>>23)&0b111111111)==0b100100010;
}


static inline uint64_t get_adrp_address(uint32_t ins,long pc){
	uint32_t instr, immlo, immhi;
    int32_t value;
    bool is_adrp=((ins>>31)&0b1)?1:0;


    instr = ins;
    immlo = (0x60000000 & instr) >> 29;
    immhi = (0xffffe0 & instr) >> 3;
    value = (immlo | immhi)|(1<<31);
    if((value>>20)&1) value|=0xffe00000;
    else value&=~0xffe00000;
    if(is_adrp) value<<= 12;
    //sign extend value to 64 bits
	if(is_adrp) return get_page_address_64(pc, PAGE_SIZE) + (int64_t)value;
	else return pc + (int64_t)value;
}
// static inline uint64_t get_b_address(uint32_t ins,long pc){
// 	int32_t imm26=ins&(0x3ffffff);
// 	if((ins>>25)&0b1) imm26|=0xfc000000;
// 	else imm26&=~0xfc000000;
// 	imm26<<=2;
// 	return pc+(int64_t)imm26;
// }
static inline uint64_t get_add_value(uint32_t ins){
	uint32_t instr2=ins;

    //imm12 64 bits if sf = 1, else 32 bits
    uint64_t imm12;
    
    //get the imm value from add instruction
    instr2 = ins;
    imm12 = (instr2 & 0x3ffc00) >> 10;
    if(instr2 & 0xc00000)
    {
            imm12 <<= 12;

    }
    return imm12;
}
// static inline uint64_t get_str_imm12(uint32_t ins){
// 	return 4*((ins&0x3ffc00)>>10);
// }
//end

static float (*orig_getDeltaTime)(void)=0;

double FPSPerSecond = 0;
double FPSPerFrame =0;
double FPSavg = 0;

void start(){
	_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), (1.0/5.0) * NSEC_PER_SEC, 0);

    dispatch_source_set_event_handler(_timer, ^{
    	if(orig_getDeltaTime){
			double delteTime=orig_getDeltaTime();
			FPSPerFrame=1.0/delteTime;
		}
    	switch(fpsMode){
    		case kModePerFrame:
		    	[fpsLabel setText:[NSString stringWithFormat:@"%.1lf",FPSPerFrame]];
		    	break;
		    case kModeAverage:
		    	[fpsLabel setText:[NSString stringWithFormat:@"%.1lf",FPSavg]];
		    	break;
		    case kModePerSecond:
		    	[fpsLabel setText:[NSString stringWithFormat:@"%.1lf",FPSPerSecond]];
		    	break;
		    default:
		    	break;
    	}
#if DEBUG
    	NSLog(@"%.1lf %.1lf %.1lf",FPSPerFrame,FPSavg,FPSPerSecond);
#endif
    });
    dispatch_resume(_timer); 
}

long search_targetins(long ad_str){
	for(long ad=main_address;ad<main_address+main_size;ad++){
		int32_t ins=*(int32_t*)ad;
		int32_t ins2=*(int32_t*)(ad+4);
		if(is_adrp(ins)&&is_64add(ins2)){
			uint64_t ad_t=get_adrp_address(ins,ad)+get_add_value(ins2);;
			if(ad_t==ad_str) return ad;
		}
	}
	return false;
}
long search_targetstr(){
	for(long ad=main_address;ad<main_address+main_size;ad++){
			static const char *t="UnityEngine.Time::get_unscaledDeltaTime()";
			if(!strcmp((const char*)(ad),t)) return ad;
	}
	return false;
}
void search(){
	long ad_str=search_targetstr();
    NSLog(@"ad_str:0x%lx",ad_str-aslr);

    if(!ad_str) return;
    long ad_ref=search_targetins(ad_str);
    NSLog(@"ad_ref:0x%lx",ad_ref-aslr);
    long ad_t=ad_ref;
    while((*(int32_t*)ad_t)!=0xd61f0000&&ad_t&&(*(int32_t*)ad_t)!=0xd65f03c0){
    	ad_t-=0x4;
    }
    ad_t+=0x4;
    NSLog(@"ad_t:0x%lx",ad_t-aslr);
    orig_getDeltaTime=(float (*)(void))ad_t;
}
@interface UnityView:UIView
@end
#define kFPSLabelWidth 50
#define kFPSLabelHeight 20
%group unity
%hook UIWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect bounds=[self bounds];
        fpsLabel= [[UILabel alloc] initWithFrame:CGRectMake(bounds.size.width-kFPSLabelWidth,0,kFPSLabelWidth,kFPSLabelHeight)];
        // fpsLabel.adjustsFontSizeToFitWidth=YES;
        fpsLabel.font=[UIFont fontWithName:@"Helvetica-Bold" size:16];
        
        [self addSubview:fpsLabel];
        loadPref();
        start();
    });
	return %orig;
}
%end
%end//unity


void a(){
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
%group gl
%hook EAGLContext 
- (BOOL)presentRenderbuffer:(NSUInteger)target{
	BOOL ret=%orig;
	a();
#if DEBUG
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		NSLog(@"gl hooked");
		});
#endif
	// NSLog(@"%f",FPSavg);
	// [fpsLabel setText:[NSString stringWithFormat:@"%.2f",FPSavg]];
	return ret;
}
%end
%end//gl

#pragma mark metal
%group MTLCommandBufferClass
%hook MTLCommandBufferClass
- (void)presentDrawable:(id <MTLDrawable>)drawable{
	// NSLog(@"UnityFPSIndicator presentDrawable");
	a();
	// NSLog(@"%f",FPSavg);
	return %orig;
}
- (void)commit{
	// NSLog(@"UnityFPSIndicator commit");
	return %orig;
}
%end
%end
%group MTLCommandQueueClass
%hook MTLCommandQueueClass
- (id <MTLCommandBuffer>)commandBuffer{
	// NSLog(@"commandBuffer");
	id ret=%orig;
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		%init(MTLCommandBufferClass,MTLCommandBufferClass=[ret class]);
		NSLog(@"metal hooked");
		});
	return ret;
}
%end
%end
%group MTLDeviceClass
%hook MTLDeviceClass
- (id )newCommandQueue{
	// NSLog(@"newCommandQueue");
	id ret=%orig;
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		%init(MTLCommandQueueClass,MTLCommandQueueClass=[ret class]);
		});
	return ret;
}
%end
%end

%group metal
%hookf(id,MTLCreateSystemDefaultDevice){
	// NSLog(@"");
	id ret=%orig;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		%init(MTLDeviceClass,MTLDeviceClass=[ret class]);
		});
	return ret;
}
%end//metal
%ctor{
	if(!is_enabled_app()) return;
	NSLog(@"ctor: UnityFPSIndicator1");

	aslr=_dyld_get_image_vmaddr_slide(0);
	find_main_binary(mach_task_self(),&main_address);
	main_size=get_image_size(main_address,mach_task_self());

	%init(unity);
	%init(gl);
	%init(metal);
	// MSHookFunction((void *)0x102c8ddf4+aslr, (void *)mygetDeltaTime, (void **)&orig_getDeltaTime);

	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{

	});
	search();
	int token = 0;
	notify_register_dispatch("com.brend0n.unityfpsindicator/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
		loadPref();
	});
}
