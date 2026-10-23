//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
//Mac OS X 10.6 Snow Leopard to 10.11 El Capitan port: Copyright (c) 2026, Cole. MIT License Applies.
//Objective-C with manual retain/release on purpose: Swift and ARC cannot target Snow Leopard with today's Xcode.
#import <dlfcn.h>
#import "Shared.h"

//true for the login window banner, started by the LoginWindow launchd agent (the macOS counterpart of /winlogon)
static BOOL loginWindow;

static CGFloat BannerHeight(NSScreen *screen)
{
    return NSHeight([screen frame]) < 1441 ? 17 : 25; //same sizes as the Windows banner, in points
}

//true when a window of another app covers the whole screen (fullscreen video, presentation, fullscreen Space)
static BOOL ScreenHasFullscreenApp(NSScreen *screen)
{
    NSRect frame = [screen frame];
    //window list coordinates start at the top left of the main screen, AppKit ones at its bottom left
    CGFloat mainHeight = NSHeight([[[NSScreen screens] objectAtIndex:0] frame]);
    CGRect target = CGRectMake(NSMinX(frame), mainHeight - NSMaxY(frame), NSWidth(frame), NSHeight(frame));
    CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    if (windows == NULL)
    {
        return NO;
    }
    BOOL found = NO;
    int ownPid = [[NSProcessInfo processInfo] processIdentifier];
    for (NSDictionary *info in (NSArray *)windows)
    {
        //only normal app windows: the Dock, Notification Center and others own invisible screen sized windows on higher layers
        if ([[info objectForKey:(id)kCGWindowLayer] intValue] != 0 || [[info objectForKey:(id)kCGWindowOwnerPID] intValue] == ownPid)
        {
            continue;
        }
        CGRect bounds;
        if (CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)[info objectForKey:(id)kCGWindowBounds], &bounds) && CGRectEqualToRect(bounds, target))
        {
            found = YES;
            break;
        }
    }
    CFRelease(windows);
    return found;
}

static NSRect BannerFrame(NSScreen *screen, BOOL bottom, BOOL fullscreen)
{
    NSRect frame = [screen frame];
    //the visible frame leaves out the menu bar and the Dock, like the WorkingArea leaves out the taskbar on Windows;
    //there is no menu bar nor Dock on the login window, and a fullscreen app hides them
    NSRect area = (loginWindow || fullscreen) ? frame : [screen visibleFrame];
    if (loginWindow && screen == [[NSScreen screens] objectAtIndex:0])
    {
        //the login window shows its status icons (battery, Wi-Fi, user switching) at the top of the main screen, in a strip as high as the menu bar
        area.size.height -= MAX([[NSStatusBar systemStatusBar] thickness], NSMaxY(frame) - NSMaxY([screen visibleFrame]));
    }
    CGFloat height = BannerHeight(screen);
    return NSMakeRect(NSMinX(frame), bottom ? NSMinY(area) : NSMaxY(area) - height, NSWidth(frame), height);
}

//Accessibility access, needed to move the windows of other apps: on 10.9 and later the app itself is allowed in
//Security & Privacy (the system prompt is shown once per launch), before that "Enable access for assistive devices"
static BOOL AccessibilityAllowed(void)
{
    static BOOL prompted = NO;
    //looked up at run time, the function does not exist before 10.9
    Boolean (*trustedWithOptions)(CFDictionaryRef) = (Boolean (*)(CFDictionaryRef))dlsym(RTLD_DEFAULT, "AXIsProcessTrustedWithOptions");
    if (trustedWithOptions != NULL)
    {
        //"AXTrustedCheckOptionPrompt" is the value of kAXTrustedCheckOptionPrompt, also 10.9 only
        NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:!prompted] forKey:@"AXTrustedCheckOptionPrompt"];
        prompted = YES;
        return trustedWithOptions((CFDictionaryRef)options);
    }
    return AXAPIEnabled() || AXIsProcessTrusted();
}

//the Accessibility element of a window of pid, found by its frame: the Accessibility API has no window numbers
static AXUIElementRef CopyWindowElement(pid_t pid, CGRect frame)
{
    AXUIElementRef app = AXUIElementCreateApplication(pid);
    CFArrayRef windows = NULL;
    AXUIElementRef found = NULL;
    if (AXUIElementCopyAttributeValue(app, kAXWindowsAttribute, (CFTypeRef *)&windows) == kAXErrorSuccess && windows != NULL)
    {
        for (CFIndex i = 0; i < CFArrayGetCount(windows) && found == NULL; i++)
        {
            AXUIElementRef window = (AXUIElementRef)CFArrayGetValueAtIndex(windows, i);
            CFTypeRef position = NULL;
            CFTypeRef size = NULL;
            CGPoint origin;
            CGSize extent;
            if (AXUIElementCopyAttributeValue(window, kAXPositionAttribute, &position) == kAXErrorSuccess
                && AXUIElementCopyAttributeValue(window, kAXSizeAttribute, &size) == kAXErrorSuccess
                && AXValueGetValue((AXValueRef)position, kAXValueCGPointType, &origin) && AXValueGetValue((AXValueRef)size, kAXValueCGSizeType, &extent)
                && fabs(origin.x - frame.origin.x) < 1 && fabs(origin.y - frame.origin.y) < 1
                && fabs(extent.width - frame.size.width) < 1 && fabs(extent.height - frame.size.height) < 1)
            {
                found = (AXUIElementRef)CFRetain(window);
            }
            if (position != NULL)
            {
                CFRelease(position);
            }
            if (size != NULL)
            {
                CFRelease(size);
            }
        }
        CFRelease(windows);
    }
    CFRelease(app);
    return found;
}

//frames of windows already moved or that could not be moved, not tried again until the mouse is used
static NSMutableSet *triedWindows;

//moves the windows of other apps out from under the banners, the counterpart of the AppBars of Windows;
//rooms: for each screen without a fullscreen app, the room between its banners, screens: the screen itself,
//both in window list coordinates (top left of the main screen)
static void ArrangeWindows(NSArray *rooms, NSArray *screens)
{
    if (triedWindows == nil)
    {
        triedWindows = [[NSMutableSet alloc] init];
    }
    if ([NSEvent pressedMouseButtons] != 0)
    {
        //never fight a window being dragged or resized, and try every window again once the mouse is released
        [triedWindows removeAllObjects];
        return;
    }
    if ([rooms count] == 0 || !AccessibilityAllowed())
    {
        return;
    }
    CFArrayRef windows = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    if (windows == NULL)
    {
        return;
    }
    int ownPid = [[NSProcessInfo processInfo] processIdentifier];
    for (NSDictionary *info in (NSArray *)windows)
    {
        int pid = [[info objectForKey:(id)kCGWindowOwnerPID] intValue];
        CGRect bounds;
        //only the normal windows of other apps
        if ([[info objectForKey:(id)kCGWindowLayer] intValue] != 0 || pid == ownPid
            || !CGRectMakeWithDictionaryRepresentation((CFDictionaryRef)[info objectForKey:(id)kCGWindowBounds], &bounds))
        {
            continue;
        }
        for (NSUInteger i = 0; i < [rooms count]; i++)
        {
            CGRect screen = NSRectToCGRect([[screens objectAtIndex:i] rectValue]);
            if (!CGRectContainsPoint(screen, CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds))))
            {
                continue;
            }
            CGRect room = NSRectToCGRect([[rooms objectAtIndex:i] rectValue]);
            BOOL underTop = CGRectGetMinY(bounds) < CGRectGetMinY(room) - 0.5;
            BOOL underBottom = bannerTopAndBottom && CGRectGetMaxY(bounds) > CGRectGetMaxY(room) + 0.5;
            NSString *key = [NSString stringWithFormat:@"%d %@", pid, NSStringFromRect(NSRectFromCGRect(bounds))];
            if ((underTop || underBottom) && ![triedWindows containsObject:key])
            {
                [triedWindows addObject:key];
                //below the top banner, and shortened to end above the bottom banner, unless that leaves it too small to use
                CGRect target = bounds;
                target.origin.y = MAX(CGRectGetMinY(bounds), CGRectGetMinY(room));
                if (CGRectGetMaxY(target) > CGRectGetMaxY(room) && CGRectGetMaxY(room) - target.origin.y >= 100)
                {
                    target.size.height = CGRectGetMaxY(room) - target.origin.y;
                }
                AXUIElementRef window = CopyWindowElement(pid, bounds);
                if (window != NULL)
                {
                    AXValueRef size = AXValueCreate(kAXValueCGSizeType, &target.size);
                    AXValueRef position = AXValueCreate(kAXValueCGPointType, &target.origin);
                    //size first, so the window fits where it moves, then again in case the move limited it
                    AXUIElementSetAttributeValue(window, kAXSizeAttribute, size);
                    AXUIElementSetAttributeValue(window, kAXPositionAttribute, position);
                    AXUIElementSetAttributeValue(window, kAXSizeAttribute, size);
                    CFRelease(size);
                    CFRelease(position);
                    CFRelease(window);
                    LogString([NSString stringWithFormat:@"ARRANGED %@ (%d) FROM %@ TO %@", [info objectForKey:(id)kCGWindowOwnerName], pid,
                        NSStringFromRect(NSRectFromCGRect(bounds)), NSStringFromRect(NSRectFromCGRect(target))]);
                }
            }
            break;
        }
    }
    CFRelease(windows);
}

@interface BannerView : NSView
{
    int screenIndex;
}
- (id)initWithFrame:(NSRect)frame screenIndex:(int)index;
@end

@implementation BannerView
- (id)initWithFrame:(NSRect)frame screenIndex:(int)index
{
    if ((self = [super initWithFrame:frame]))
    {
        screenIndex = index;
    }
    return self;
}
- (BOOL)isOpaque
{
    return YES;
}
- (void)drawRect:(NSRect)dirtyRect
{
    NSString *left = nil;
    NSString *right = nil;
    if (debug)
    {
        left = [NSString stringWithFormat:@"%@: %d", loginWindow ? @"LOGINWINDOW" : @"SCREEN", screenIndex];
        right = @"DEBUG: True";
    }
    DrawBanner([self bounds], bannerText, ColorFromBytes(bannerColor), ColorFromBytes(bannerColor + 3), left, right);
}
@end

@interface BannerController : NSObject <NSApplicationDelegate>
{
    NSMutableArray *banners;
    NSString *layout; //what the banners were built for, rebuilt when it changes
}
- (void)refresh;
@end

@implementation BannerController
- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    banners = [[NSMutableArray alloc] init];
    [self refresh];
    //1 second, the configuration and the fullscreen state have no change notification that works back to Snow Leopard
    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes]; //keep running while a menu is open
    //react right away to screens plugged in, removed or resized, and to Space changes (fullscreen apps)
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:NSApplicationDidChangeScreenParametersNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(refresh) name:NSWorkspaceActiveSpaceDidChangeNotification object:nil];
}
- (void)killBanners
{
    for (NSWindow *banner in banners)
    {
        [banner orderOut:nil];
        [banner close];
    }
    [banners removeAllObjects];
}
- (void)buildBanner:(NSRect)frame screenIndex:(int)index bottom:(BOOL)bottom
{
    NSWindow *banner = [[NSWindow alloc] initWithContentRect:frame styleMask:0 /* borderless, the constant was renamed in 10.12 */ backing:NSBackingStoreBuffered defer:NO];
    [banner setReleasedWhenClosed:NO];
    [banner setOpaque:YES];
    [banner setHasShadow:NO];
    [banner setHidesOnDeactivate:NO];
    [banner setCanHide:NO]; //"Hide Others" must not hide the banner
    [banner setIgnoresMouseEvents:YES]; //clicks go through to the window below, a title bar under the banner can still be dragged
    //above windows and fullscreen apps; like the bottom banner of Windows sits below the taskbar, the top banner stays
    //below the menu bar (Spotlight and menus open over it) and the bottom banner below the Dock (magnified icons show over it)
    if (loginWindow)
    {
        [banner setLevel:NSScreenSaverWindowLevel];
    }
    else
    {
        [banner setLevel:bottom ? CGWindowLevelForKey(kCGDockWindowLevelKey) - 1 : NSMainMenuWindowLevel - 1];
    }
    NSWindowCollectionBehavior behavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle;
    if (floor(NSAppKitVersionNumber) >= 1138) //Mac OS X 10.7 Lion added fullscreen Spaces
    {
        behavior |= (1 << 8); //NSWindowCollectionBehaviorFullScreenAuxiliary, follow the banner into fullscreen apps
    }
    [banner setCollectionBehavior:behavior];
    if (loginWindow)
    {
        [banner setCanBecomeVisibleWithoutLogin:YES];
    }
    BannerView *view = [[BannerView alloc] initWithFrame:NSMakeRect(0, 0, NSWidth(frame), NSHeight(frame)) screenIndex:index];
    [banner setContentView:view];
    [view release];
    [banner setFrame:frame display:YES];
    [banner orderFrontRegardless];
    [banners addObject:banner];
    [banner release];
}
- (void)refresh
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    ReadPrefs();
    //everything the banners depend on: settings, screens, menu bar, Dock and fullscreen apps
    NSMutableArray *frames = [NSMutableArray array];
    NSMutableArray *rooms = [NSMutableArray array]; //for ArrangeWindows, in window list coordinates
    NSMutableArray *roomScreens = [NSMutableArray array];
    NSArray *screens = [NSScreen screens];
    CGFloat mainHeight = NSHeight([[screens objectAtIndex:0] frame]);
    for (NSUInteger i = 0; i < [screens count]; i++)
    {
        NSScreen *screen = [screens objectAtIndex:i];
        BOOL fullscreen = !loginWindow && ScreenHasFullscreenApp(screen);
        NSRect top = BannerFrame(screen, NO, fullscreen);
        [frames addObject:[NSValue valueWithRect:top]];
        if (bannerTopAndBottom)
        {
            [frames addObject:[NSValue valueWithRect:BannerFrame(screen, YES, fullscreen)]];
        }
        if (arrangeWindows && !loginWindow && !fullscreen)
        {
            //the room between the banners, or between the top banner and the Dock
            NSRect frame = [screen frame];
            CGFloat bottom = bannerTopAndBottom ? NSMaxY(BannerFrame(screen, YES, NO)) : NSMinY([screen visibleFrame]);
            [rooms addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(frame), mainHeight - NSMinY(top), NSWidth(frame), NSMinY(top) - bottom)]];
            [roomScreens addObject:[NSValue valueWithRect:NSMakeRect(NSMinX(frame), mainHeight - NSMaxY(frame), NSWidth(frame), NSHeight(frame))]];
        }
    }
    NSString *newLayout = [NSString stringWithFormat:@"%@ %d %@", lastPrefSummary, debug, frames];
    if (![newLayout isEqualToString:layout])
    {
        LogString([NSString stringWithFormat:@"REBUILDING BANNERS: %@", newLayout]);
        [layout release];
        layout = [newLayout retain];
        [self killBanners];
        for (NSUInteger i = 0; i < [frames count]; i++)
        {
            [self buildBanner:[[frames objectAtIndex:i] rectValue] screenIndex:(int)(bannerTopAndBottom ? i / 2 : i) bottom:bannerTopAndBottom && i % 2 == 1];
        }
    }
    //no periodic reordering: the few windows sharing a banner's level, like Spotlight on Snow Leopard, must stay over it while open
    if (arrangeWindows && !loginWindow)
    {
        ArrangeWindows(rooms, roomScreens);
    }
    [pool release];
}
@end

//"--diag" prints what SystemBanner sees in the preferences, then quits
static void WriteDiagnostics(void)
{
    NSMutableString *report = [NSMutableString string];
    [report appendFormat:@"SystemBanner diagnostics, %@\n", [NSDate date]];
    [report appendFormat:@"macOS: %@, user: %@\n\n", [[NSProcessInfo processInfo] operatingSystemVersionString], NSUserName()];
    [report appendFormat:@"[%@]\n", PREF_DOMAIN];
    NSArray *keys = [NSArray arrayWithObjects:@"Simple", @"0", @"1", @"2", @"3", @"4", @"5", @"Text", @"TopAndBottom", @"Debug", @"ArrangeWindows", nil];
    for (NSString *key in keys)
    {
        id value = PrefValue(key);
        BOOL forced = CFPreferencesAppValueIsForced((CFStringRef)key, PREF_DOMAIN);
        [report appendFormat:@"  %@ = %@ (%@%@)\n", key, value ? value : @"not set", value ? NSStringFromClass([value class]) : @"-", forced ? @", managed" : @""];
    }
    ReadPrefs();
    [report appendFormat:@"\nSystemBanner reads: %@, DEBUG=%d\n", lastPrefSummary, debug];
    printf("%s", [report UTF8String]);
}

int main(int argc, const char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    for (int i = 1; i < argc; i++)
    {
        if (strcmp(argv[i], "--diag") == 0)
        {
            WriteDiagnostics();
            [pool release];
            return 0;
        }
        if (strcmp(argv[i], "--loginwindow") == 0)
        {
            loginWindow = YES;
        }
    }
    [NSApplication sharedApplication];
    BannerController *controller = [[BannerController alloc] init];
    [NSApp setDelegate:controller];
    [NSApp run];
    [controller release];
    [pool release];
    return 0;
}
