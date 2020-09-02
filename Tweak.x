#import <notify.h>
#import <substrate.h>
#import <notify.h>
#import <readmem/readmem.h>
#import <libcolorpicker/libcolorpicker.h>
extern intptr_t _dyld_get_image_vmaddr_slide(uint32_t image_index);

BOOL enabled;
uint64_t main_address;
long main_size;

long aslr;
dispatch_source_t _timer;
UILabel *fpsLabel;

BOOL loadPref(){
	NSLog(@"loadPref..........");
	NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.brend0n.unityfpsindicator.plist"];
	if(!prefs) prefs=[NSMutableDictionary new];
	enabled=prefs[@"enabled"]?[prefs[@"enabled"] boolValue]:YES;

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
// static float mygetDeltaTime(void){
// 	// NSLog(@"orig_getDeltaTime called");
// 	float ret=orig_getDeltaTime();
// 	return ret;
// }


void start(){
	_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), (1.0/5.0) * NSEC_PER_SEC, 0);

    dispatch_source_set_event_handler(_timer, ^{
    	// NSLog(@"???");
    	double delteTime=orig_getDeltaTime();
    	double fps=1.0/delteTime;
    	NSLog(@"%lf %lf",fps,delteTime);
    	[fpsLabel setText:[NSString stringWithFormat:@"%.2lf",fps]];
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
			static const char *t="UnityEngine.Time::get_deltaTime()";
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
%hook UnityView
-(void)touchesBegan:(id)touches withEvent:(id)event{
	static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect bounds=[self bounds];
        fpsLabel= [[UILabel alloc] initWithFrame:CGRectMake(bounds.size.width-kFPSLabelWidth,0,kFPSLabelWidth,kFPSLabelHeight)];
        // fpsLabel.adjustsFontSizeToFitWidth=YES;
        fpsLabel.font=[UIFont fontWithName:@"Helvetica-Bold" size:16];
        
        [self addSubview:fpsLabel];
        loadPref();
        if(!orig_getDeltaTime) return;
        start();
    });
	%orig;
}
%end
%ctor{
	if(!is_enabled_app()) return;
	// if(!loadPref()) return;
	// return;
	NSLog(@"ctor: UnityFPSIndicator");

	aslr=_dyld_get_image_vmaddr_slide(0);
	NSLog(@"ASLR=0x%lx",aslr);
	find_main_binary(mach_task_self(),&main_address);
	main_size=get_image_size(main_address,mach_task_self());

	// MSHookFunction((void *)0x102c8ddf4+aslr, (void *)mygetDeltaTime, (void **)&orig_getDeltaTime);
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		// start();
		
	});
	search();
	int token = 0;
	notify_register_dispatch("com.brend0n.unityfpsindicator/loadPref", &token, dispatch_get_main_queue(), ^(int token) {
		loadPref();
	});
}
