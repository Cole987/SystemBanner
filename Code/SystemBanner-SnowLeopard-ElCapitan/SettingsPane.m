//Copyright (c) 2026, Cole. MIT License Applies.
//SystemBanner preference pane: changes the classification shown by SystemBanner from System Preferences, for administrators only.
//The standard lock asks for an administrator name and password before anything can be changed, since
///Library/Preferences/com.systembanner.plist can only be written as root.
//
//System Preferences of 10.6 and 10.7 is 64 bit with garbage collection, and reopens in 32 bit for a pane that does not support it.
//Today's Xcode cannot build i386 nor garbage collected code, so build.sh marks this pane as supporting garbage collection,
//and the code is written for it: the controls are kept alive by the view they are in, and every other object kept in
//an instance variable or a global is held with CFRetain, which keeps it alive with and without garbage collection.
#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>
#import <Security/Authorization.h>
#import <sys/wait.h>
#import "Shared.h"

//each item of the classification menu is tagged with the code of its classification (the Simple setting), 0 for "Not configured"
#define CUSTOM_TAG -1
#define SEPARATOR_TAG -2

//runs a tool as root with the rights the lock was unlocked with; the arguments go to the tool as they are, no shell is involved.
//Returns nil when it worked, or what went wrong, for the status line and Console.app
static NSString *RunAsRoot(AuthorizationRef authorization, const char *tool, NSArray *arguments)
{
    char *argv[16];
    NSUInteger count = MIN([arguments count], (NSUInteger)15);
    for (NSUInteger i = 0; i < count; i++)
    {
        argv[i] = (char *)[[arguments objectAtIndex:i] UTF8String];
    }
    argv[count] = NULL;
    FILE *pipe = NULL;
    OSStatus result = AuthorizationExecuteWithPrivileges(authorization, tool, kAuthorizationFlagDefaults, argv, &pipe);
    if (result != errAuthorizationSuccess)
    {
        return [NSString stringWithFormat:@"%s could not run as root (error %d)", tool, (int)result];
    }
    char buffer[256];
    while (fread(buffer, 1, sizeof(buffer), pipe) > 0)
    {
        //wait for the tool to finish
    }
    fclose(pipe);
    int status = 0;
    if (wait(&status) > 0 && WIFEXITED(status) && WEXITSTATUS(status) != 0)
    {
        return [NSString stringWithFormat:@"%s %@ failed (exit code %d)", tool, [arguments componentsJoinedByString:@" "], WEXITSTATUS(status)];
    }
    return nil;
}

static void ColorToBytes(NSColor *color, int *rgb)
{
    NSColor *srgb = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
    if (srgb == nil)
    {
        return; //pattern colors have no RGB value, keep the previous one
    }
    //Snow Leopard refuses -redComponent on sRGB colors (allowed since 10.7), -getComponents: works on any RGB color space
    CGFloat components[4];
    [srgb getComponents:components];
    for (int i = 0; i < 3; i++)
    {
        rgb[i] = (int)lround(components[i] * 255);
    }
}

static NSTextField *Label(NSString *text, NSRect frame)
{
    NSTextField *label = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [label setStringValue:text];
    [label setEditable:NO];
    [label setSelectable:NO];
    [label setBezeled:NO];
    [label setDrawsBackground:NO];
    return label;
}

static NSButton *Checkbox(NSString *title, NSRect frame)
{
    NSButton *box = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [box setButtonType:NSSwitchButton];
    [box setTitle:title];
    return box;
}

//class names carry the SystemBanner prefix, every pane shares the System Preferences process
@interface SystemBannerPreviewView : NSView
{
@public
    NSString *text;
    int colors[6];
}
- (void)setText:(NSString *)newText;
@end

@implementation SystemBannerPreviewView
- (void)drawRect:(NSRect)dirtyRect
{
    DrawBanner([self bounds], text, ColorFromBytes(colors), ColorFromBytes(colors + 3), nil, nil);
}
- (void)setText:(NSString *)newText
{
    NSString *copy = [[newText copy] autorelease];
    CFRetain(copy);
    if (text != nil)
    {
        CFRelease(text);
    }
    text = copy;
    [self setNeedsDisplay:YES];
}
- (void)dealloc
{
    if (text != nil)
    {
        CFRelease(text);
    }
    [super dealloc];
}
@end

@interface SystemBannerPane : NSPreferencePane <NSTextFieldDelegate>
{
    NSPopUpButton *classification;
    NSTextField *textField;
    NSColorWell *backgroundWell;
    NSColorWell *textWell;
    NSButton *topAndBottomBox;
    NSButton *debugBox;
    SystemBannerPreviewView *preview;
    NSTextField *status;
    NSButton *revertButton;
    NSButton *applyButton;
    SFAuthorizationView *authView;
    BOOL managed;
}
@end

@implementation SystemBannerPane

- (NSView *)loadMainView
{
    //built in code, no nib, like the rest of SystemBanner
    NSView *view = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 668, 330)] autorelease];

    [view addSubview:Label(@"Classification:", NSMakeRect(20, 285, 115, 17))];
    classification = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(137, 278, 345, 26) pullsDown:NO] autorelease];
    [classification addItemWithTitle:@"Not configured"];
    NSString *system = nil;
    for (int i = 0; i < presetCount; i++)
    {
        if (![presets[i].system isEqualToString:system])
        {
            //a separator before each classification system
            NSMenuItem *separator = [NSMenuItem separatorItem];
            [separator setTag:SEPARATOR_TAG];
            [[classification menu] addItem:separator];
            system = presets[i].system;
        }
        [classification addItemWithTitle:PresetTitle(&presets[i])];
        [[classification lastItem] setTag:presets[i].code];
    }
    NSMenuItem *separator = [NSMenuItem separatorItem];
    [separator setTag:SEPARATOR_TAG];
    [[classification menu] addItem:separator];
    [classification addItemWithTitle:@"Custom"];
    [[classification lastItem] setTag:CUSTOM_TAG];
    [classification setTarget:self];
    [classification setAction:@selector(classificationChanged:)];
    [view addSubview:classification];

    [view addSubview:Label(@"Text:", NSMakeRect(20, 250, 115, 17))];
    textField = [[[NSTextField alloc] initWithFrame:NSMakeRect(140, 247, 508, 22)] autorelease];
    [textField setDelegate:self];
    [view addSubview:textField];

    [view addSubview:Label(@"Background:", NSMakeRect(20, 215, 115, 17))];
    backgroundWell = [[[NSColorWell alloc] initWithFrame:NSMakeRect(140, 209, 52, 28)] autorelease];
    [view addSubview:backgroundWell];
    [view addSubview:Label(@"Text color:", NSMakeRect(230, 215, 80, 17))];
    textWell = [[[NSColorWell alloc] initWithFrame:NSMakeRect(310, 209, 52, 28)] autorelease];
    [view addSubview:textWell];
    for (NSColorWell *well in [NSArray arrayWithObjects:backgroundWell, textWell, nil])
    {
        [well setTarget:self];
        [well setAction:@selector(updatePreview:)];
    }

    topAndBottomBox = Checkbox(@"Show a banner at the top and at the bottom of each screen", NSMakeRect(18, 175, 600, 18));
    [view addSubview:topAndBottomBox];
    debugBox = Checkbox(@"Debug logging (Console)", NSMakeRect(18, 151, 600, 18));
    [view addSubview:debugBox];

    preview = [[[SystemBannerPreviewView alloc] initWithFrame:NSMakeRect(20, 110, 628, 25)] autorelease];
    [view addSubview:preview];

    status = Label(@"", NSMakeRect(20, 80, 628, 17));
    [view addSubview:status];

    //the standard lock of System Preferences, bottom left
    authView = [[[SFAuthorizationView alloc] initWithFrame:NSMakeRect(15, 15, 360, 40)] autorelease];
    [view addSubview:authView];

    revertButton = [[[NSButton alloc] initWithFrame:NSMakeRect(440, 15, 110, 32)] autorelease];
    [revertButton setBezelStyle:NSRoundedBezelStyle];
    [revertButton setTitle:@"Revert"];
    [revertButton setTarget:self];
    [revertButton setAction:@selector(loadSettings:)];
    [view addSubview:revertButton];
    applyButton = [[[NSButton alloc] initWithFrame:NSMakeRect(542, 15, 110, 32)] autorelease];
    [applyButton setBezelStyle:NSRoundedBezelStyle];
    [applyButton setTitle:@"Apply"];
    [applyButton setKeyEquivalent:@"\r"];
    [applyButton setTarget:self];
    [applyButton setAction:@selector(apply:)];
    [view addSubview:applyButton];

    [self setMainView:view];
    [self mainViewDidLoad];
    return view;
}

- (void)mainViewDidLoad
{
    [authView setString:kAuthorizationRightExecute]; //administrators only
    [authView setDelegate:self];
    [authView updateStatus:nil];
    [authView setAutoupdate:YES];
    [self loadSettings:nil];
}

- (void)willSelect
{
    [self loadSettings:nil]; //the settings may have changed since the pane was last shown
}

- (BOOL)isUnlocked
{
    return [authView authorizationState] == SFAuthorizationViewUnlockedState;
}

//nothing can be changed while the lock is closed, or when a profile or MCX manages SystemBanner
- (void)updateEnabled
{
    BOOL editable = [self isUnlocked] && !managed;
    BOOL custom = [classification selectedTag] == CUSTOM_TAG;
    [classification setEnabled:editable];
    [textField setEnabled:editable && custom];
    [backgroundWell setEnabled:editable && custom];
    [textWell setEnabled:editable && custom];
    [topAndBottomBox setEnabled:editable];
    [debugBox setEnabled:editable];
    [revertButton setEnabled:editable];
    [applyButton setEnabled:editable];
}

- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view
{
    [self updateEnabled];
    [self showLockHint];
}

- (void)authorizationViewDidDeauthorize:(SFAuthorizationView *)view
{
    [self updateEnabled];
    [self showLockHint];
}

//the line under the preview says what to do next, unless a profile manages SystemBanner
- (void)showLockHint
{
    if (managed)
    {
        return;
    }
    [status setStringValue:[self isUnlocked] ? @"Choose the classification, then click Apply." : @"Only administrators can change the classification: click the lock."];
    [status setTextColor:[NSColor controlTextColor]];
}

- (void)loadSettings:(id)sender
{
    ReadPrefs();
    int simple = 0;
    NSInteger tag = 0;
    if (PrefInt(@"Simple", &simple) && PresetForCode(simple) != NULL)
    {
        tag = simple;
    }
    else if (PrefValue(@"Text") != nil || PrefValue(@"0") != nil || PrefValue(@"3") != nil)
    {
        tag = CUSTOM_TAG;
    }
    [classification selectItemWithTag:tag];
    [textField setStringValue:bannerText];
    [backgroundWell setColor:ColorFromBytes(bannerColor)];
    [textWell setColor:ColorFromBytes(bannerColor + 3)];
    [topAndBottomBox setState:bannerTopAndBottom ? NSOnState : NSOffState];
    [debugBox setState:debug ? NSOnState : NSOffState];
    managed = PrefsAreManaged();
    [self classificationChanged:nil];
    if (managed)
    {
        //a profile or MCX wins over /Library/Preferences, a change here would never show
        [status setStringValue:@"This Mac is managed by a configuration profile, change the classification there."];
        [status setTextColor:[NSColor redColor]];
    }
    else
    {
        [self showLockHint];
    }
}

- (void)classificationChanged:(id)sender
{
    NSInteger tag = [classification selectedTag];
    if (tag != CUSTOM_TAG)
    {
        //a stock classification sets its own text and colors
        const Preset *preset = PresetForCode((int)tag); //NULL for "Not configured"
        const int *colors = preset != NULL ? preset->colors : unconfiguredColors;
        [textField setStringValue:preset != NULL ? preset->text : unconfiguredText];
        [backgroundWell setColor:ColorFromBytes(colors)];
        [textWell setColor:ColorFromBytes(colors + 3)];
    }
    [self updateEnabled];
    [self updatePreview:nil];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    [self updatePreview:nil];
}

- (void)updatePreview:(id)sender
{
    ColorToBytes([backgroundWell color], preview->colors);
    ColorToBytes([textWell color], preview->colors + 3);
    [preview setText:[textField stringValue]];
}

- (void)apply:(id)sender
{
    [self updatePreview:nil];
    AuthorizationRef authorization = NULL;
    AuthorizationRef ownAuthorization = NULL;
    //today's SDK marks -authorizationRef as 10.10, so it is only called when it answers;
    //otherwise use an authorization of our own
    SFAuthorization *paneAuthorization = [authView authorization];
    if ([paneAuthorization respondsToSelector:@selector(authorizationRef)])
    {
        authorization = (AuthorizationRef)[paneAuthorization performSelector:@selector(authorizationRef)];
    }
    if (authorization == NULL)
    {
        OSStatus created = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &ownAuthorization);
        if (created != errAuthorizationSuccess)
        {
            [self showError:[NSString stringWithFormat:@"Error: no authorization (error %d).", (int)created]];
            return;
        }
        authorization = ownAuthorization;
    }
    //ask for the administrator right itself: the lock can show unlocked without holding it yet (Snow Leopard does that),
    //the system then shows its password prompt
    AuthorizationItem right = { kAuthorizationRightExecute, 0, NULL, 0 };
    AuthorizationRights rights = { 1, &right };
    OSStatus granted = AuthorizationCopyRights(authorization, &rights, kAuthorizationEmptyEnvironment,
        kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize, NULL);
    if (granted != errAuthorizationSuccess)
    {
        if (ownAuthorization != NULL)
        {
            AuthorizationFree(ownAuthorization, kAuthorizationFlagDefaults);
        }
        [self showError:granted == errAuthorizationCanceled ? @"Cancelled, nothing was changed."
            : [NSString stringWithFormat:@"Error: administrator rights refused (error %d).", (int)granted]];
        return;
    }
    NSInteger tag = [classification selectedTag];
    NSMutableArray *writes = [NSMutableArray array]; //each one: key, type, value
    NSMutableArray *deletes = [NSMutableArray arrayWithObjects:@"Text", @"0", @"1", @"2", @"3", @"4", @"5", nil];
    if (tag == CUSTOM_TAG)
    {
        //the text cannot be empty, it would show a blank banner
        NSString *text = [[[textField stringValue] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];
        if ([[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0)
        {
            [status setStringValue:@"Type the text of the banner."];
            [status setTextColor:[NSColor redColor]];
            return;
        }
        deletes = [NSMutableArray arrayWithObject:@"Simple"];
        [writes addObject:[NSArray arrayWithObjects:@"Text", @"-string", text, nil]];
        for (int i = 0; i < 6; i++)
        {
            [writes addObject:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%d", i], @"-int", [NSString stringWithFormat:@"%d", preview->colors[i]], nil]];
        }
    }
    else if (tag > 0)
    {
        [writes addObject:[NSArray arrayWithObjects:@"Simple", @"-int", [NSString stringWithFormat:@"%ld", (long)tag], nil]];
    }
    else
    {
        [deletes addObject:@"Simple"];
    }
    [writes addObject:[NSArray arrayWithObjects:@"TopAndBottom", @"-int", [topAndBottomBox state] == NSOnState ? @"1" : @"0", nil]];
    [writes addObject:[NSArray arrayWithObjects:@"Debug", @"-int", [debugBox state] == NSOnState ? @"1" : @"0", nil]];
    for (NSString *key in deletes)
    {
        RunAsRoot(authorization, "/usr/bin/defaults", [NSArray arrayWithObjects:@"delete", PREF_FILE, key, nil]); //fails harmlessly when the key is not set
    }
    NSString *error = nil;
    for (NSArray *write in writes)
    {
        NSString *writeError = RunAsRoot(authorization, "/usr/bin/defaults", [[NSArray arrayWithObjects:@"write", PREF_FILE, nil] arrayByAddingObjectsFromArray:write]);
        error = error ? error : writeError;
    }
    //the tools keep the user as their real user and the file can end up owned by them: give it back to root,
    //or a standard user who unlocked with an administrator password could change the classification later without one
    NSString *chownError = RunAsRoot(authorization, "/usr/sbin/chown", [NSArray arrayWithObjects:@"root:wheel", [PREF_FILE stringByAppendingString:@".plist"], nil]);
    error = error ? error : chownError;
    //the banners run as the user, they must be able to read the file
    NSString *chmodError = RunAsRoot(authorization, "/bin/chmod", [NSArray arrayWithObjects:@"644", [PREF_FILE stringByAppendingString:@".plist"], nil]);
    error = error ? error : chmodError;
    if (ownAuthorization != NULL)
    {
        AuthorizationFree(ownAuthorization, kAuthorizationFlagDefaults);
    }
    if (error != nil)
    {
        [self showError:[NSString stringWithFormat:@"Error: %@.", error]];
        return;
    }
    //read the settings back, as the banners will
    ReadPrefs();
    int simple = 0;
    BOOL simpleSet = PrefInt(@"Simple", &simple);
    if ((tag > 0 && (!simpleSet || simple != tag)) || (tag == CUSTOM_TAG && simpleSet))
    {
        [self showError:@"Error: the settings were written, but SystemBanner does not read them back."];
        return;
    }
    NSLog(@"SystemBanner pane: saved %@", lastPrefSummary);
    [status setStringValue:@"Saved. The banners change within a second."];
    [status setTextColor:[NSColor controlTextColor]];
}

//shown under the preview and logged to Console.app, to tell what went wrong
- (void)showError:(NSString *)message
{
    NSLog(@"SystemBanner pane: %@", message);
    [status setStringValue:message];
    [status setTextColor:[NSColor redColor]];
}
@end
