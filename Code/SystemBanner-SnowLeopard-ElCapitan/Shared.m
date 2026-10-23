//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
//Mac OS X 10.6 Snow Leopard to 10.11 El Capitan port: Copyright (c) 2026, Cole. MIT License Applies.
//Objective-C with manual retain/release on purpose: ARC cannot target Snow Leopard with today's Xcode.
//This file also runs inside System Preferences, which uses garbage collection on 10.6 and 10.7 (see SettingsPane.m):
//objects kept in globals are held with CFRetain, that works with and without garbage collection.
#import "Shared.h"

//stock classifications, by system; the code is the value of the Simple setting, 1 to 6 for the United States as before,
//then a range of ten per system; national colors are used where an official text sets them, NATO follows a common unofficial convention, the others are neutral
//(white on black, so they cannot be taken for the black on white unconfigured banner)
const int unconfiguredColors[6] = { 255, 255, 255, 0, 0, 0 };
NSString *const unconfiguredText = @"Classification is not configured.";
const Preset presets[] = {
    //United States: gsa form color info collected by Frank Caviggia @ https://github.com/fcaviggia/classification-banner
    { 1, @"United States", @"UNCLASSIFIED", { 0, 122, 51, 255, 255, 255 } },
    { 2, @"United States", @"CUI", { 48, 31, 85, 255, 255, 255 } },
    { 3, @"United States", @"CONFIDENTIAL", { 0, 51, 160, 255, 255, 255 } },
    { 4, @"United States", @"SECRET", { 200, 16, 46, 255, 255, 255 } },
    { 5, @"United States", @"TOP SECRET", { 255, 103, 31, 255, 255, 255 } },
    { 6, @"United States", @"TOP SECRET//SCI", { 247, 234, 72, 0, 0, 0 } },
    //France: decree 2019-1271 and IGI 1300 (2021) stamp SECRET and TRES SECRET in red; DIFFUSION RESTREINTE is a protection mark, not a classification, with no color: neutral
    { 11, @"France", @"DIFFUSION RESTREINTE", { 0, 0, 0, 255, 255, 255 } },
    { 12, @"France", @"SECRET", { 200, 16, 46, 255, 255, 255 } },
    { 13, @"France", @"TRÈS SECRET", { 200, 16, 46, 255, 255, 255 } },
    //Germany: VS-Anweisung annex IV (2023) marks STRENG GEHEIM and GEHEIM in red, with crossed yellow and red stripes for STRENG GEHEIM folders,
    //and a blue stripe for VS-VERTRAULICH; VS-NUR FUER DEN DIENSTGEBRAUCH is marked in black or blue: neutral
    { 21, @"Germany", @"VS-NUR FÜR DEN DIENSTGEBRAUCH", { 0, 0, 0, 255, 255, 255 } },
    { 22, @"Germany", @"VS-VERTRAULICH", { 0, 51, 160, 255, 255, 255 } },
    { 23, @"Germany", @"GEHEIM", { 200, 16, 46, 255, 255, 255 } },
    { 24, @"Germany", @"STRENG GEHEIM", { 200, 16, 46, 247, 234, 72 } },
    //United Kingdom: the Government Security Classifications guidance discourages color coding: neutral
    { 31, @"United Kingdom", @"OFFICIAL", { 0, 0, 0, 255, 255, 255 } },
    { 32, @"United Kingdom", @"OFFICIAL-SENSITIVE", { 0, 0, 0, 255, 255, 255 } },
    { 33, @"United Kingdom", @"SECRET", { 0, 0, 0, 255, 255, 255 } },
    { 34, @"United Kingdom", @"TOP SECRET", { 0, 0, 0, 255, 255, 255 } },
    //NATO: AC/35-D/2002-REV5 sets no colors; common unofficial convention reusing the United States colors (orange for NATO RESTRICTED, yellow for COSMIC TOP SECRET)
    { 41, @"NATO", @"NATO UNCLASSIFIED", { 0, 122, 51, 255, 255, 255 } },
    { 42, @"NATO", @"NATO RESTRICTED", { 255, 103, 31, 255, 255, 255 } },
    { 43, @"NATO", @"NATO CONFIDENTIAL", { 0, 51, 160, 255, 255, 255 } },
    { 44, @"NATO", @"NATO SECRET", { 200, 16, 46, 255, 255, 255 } },
    { 45, @"NATO", @"COSMIC TOP SECRET", { 247, 234, 72, 0, 0, 0 } },
    //United Nations: ST/SGB/2007/6 sets no colors: neutral; "UN" keeps the levels apart from the United States ones
    { 51, @"United Nations", @"UN CONFIDENTIAL", { 0, 0, 0, 255, 255, 255 } },
    { 52, @"United Nations", @"UN STRICTLY CONFIDENTIAL", { 0, 0, 0, 255, 255, 255 } },
};
const int presetCount = sizeof(presets) / sizeof(presets[0]);

const Preset *PresetForCode(int code)
{
    for (int i = 0; i < presetCount; i++)
    {
        if (presets[i].code == code)
        {
            return &presets[i];
        }
    }
    return NULL;
}

NSString *PresetTitle(const Preset *preset)
{
    return [NSString stringWithFormat:@"%@ \u2013 %@", preset->system, preset->text];
}

BOOL debug;
BOOL bannerTopAndBottom;
int bannerColor[6];
NSString *bannerText;
NSString *lastPrefSummary;

void LogString(NSString *msg)
{
    if (debug)
    {
        NSLog(@"%@", msg); //shows in Console.app (system.log on Snow Leopard)
    }
}

//a value set by a configuration profile or MCX wins, otherwise only the computer wide /Library/Preferences file counts:
//CFPreferencesCopyAppValue alone would also read ~/Library/Preferences, and let any user override the classification
id PrefValue(NSString *key)
{
    CFPropertyListRef value;
    if (CFPreferencesAppValueIsForced((CFStringRef)key, PREF_DOMAIN))
    {
        value = CFPreferencesCopyAppValue((CFStringRef)key, PREF_DOMAIN);
    }
    else
    {
        value = CFPreferencesCopyValue((CFStringRef)key, PREF_DOMAIN, kCFPreferencesAnyUser, kCFPreferencesAnyHost);
        if (value == NULL)
        {
            //Mac OS X 10.6.8 does not return the values of /Library/Preferences/com.systembanner.plist to a user process, read the file itself
            return [[NSDictionary dictionaryWithContentsOfFile:[PREF_FILE stringByAppendingString:@".plist"]] objectForKey:key];
        }
    }
    return [(id)CFMakeCollectable(value) autorelease];
}

//profiles store numbers, MCX and hand made plists sometimes store strings, accept both
BOOL PrefInt(NSString *key, int *result)
{
    id value = PrefValue(key);
    if ([value isKindOfClass:[NSNumber class]] || [value isKindOfClass:[NSString class]])
    {
        *result = [value intValue];
        return YES;
    }
    return NO;
}

//true when a configuration profile or MCX sets SystemBanner, /Library/Preferences is then ignored
BOOL PrefsAreManaged(void)
{
    NSArray *keys = [NSArray arrayWithObjects:@"Simple", @"0", @"1", @"2", @"3", @"4", @"5", @"Text", @"TopAndBottom", @"Debug", nil];
    for (NSString *key in keys)
    {
        if (CFPreferencesAppValueIsForced((CFStringRef)key, PREF_DOMAIN))
        {
            return YES;
        }
    }
    return NO;
}

void ReadPrefs(void)
{
    //pick up changes written by another process (defaults, profiles, MCX, SystemBanner Settings) since the last read
    CFPreferencesSynchronize(PREF_DOMAIN, kCFPreferencesAnyUser, kCFPreferencesAnyHost);
    CFPreferencesAppSynchronize(PREF_DOMAIN);
    //values removed since the last read must go back to their defaults
    memcpy(bannerColor, unconfiguredColors, sizeof(bannerColor));
    NSString *text = unconfiguredText;
    bannerTopAndBottom = NO;
    debug = NO;
    int value;
    for (int i = 0; i < 6; i++)
    {
        if (PrefInt([NSString stringWithFormat:@"%d", i], &value) && value >= 0 && value <= 255)
        {
            bannerColor[i] = value;
        }
    }
    id customText = PrefValue(@"Text");
    if ([customText isKindOfClass:[NSString class]])
    {
        text = customText;
    }
    //override custom if simple value is set
    const Preset *preset = PrefInt(@"Simple", &value) ? PresetForCode(value) : NULL;
    if (preset != NULL)
    {
        memcpy(bannerColor, preset->colors, sizeof(bannerColor));
        text = preset->text;
    }
    if (PrefInt(@"Debug", &value) && value == 1)
    {
        debug = YES;
    }
    if (PrefInt(@"TopAndBottom", &value) && value == 1)
    {
        bannerTopAndBottom = YES;
    }
    CFRetain(text);
    if (bannerText != nil)
    {
        CFRelease(bannerText);
    }
    bannerText = text;
    //log the settings only when they change (the banner reads them every second)
    NSString *summary = [NSString stringWithFormat:@"PREFERENCES: TEXT=%@, COLORS=%d,%d,%d,%d,%d,%d, TOPANDBOTTOM=%d", bannerText,
        bannerColor[0], bannerColor[1], bannerColor[2], bannerColor[3], bannerColor[4], bannerColor[5], bannerTopAndBottom];
    if (![summary isEqualToString:lastPrefSummary])
    {
        CFRetain(summary);
        if (lastPrefSummary != nil)
        {
            CFRelease(lastPrefSummary);
        }
        lastPrefSummary = summary;
        LogString(summary);
    }
}

NSColor *ColorFromBytes(const int *rgb)
{
    CGFloat components[4] = { rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, 1.0 };
    return [NSColor colorWithColorSpace:[NSColorSpace sRGBColorSpace] components:components count:4];
}

void DrawBanner(NSRect rect, NSString *text, NSColor *background, NSColor *foreground, NSString *left, NSString *right)
{
    [background set];
    NSRectFill(rect);
    NSFont *font = [NSFont fontWithName:@"Arial-BoldMT" size:NSHeight(rect) - 3];
    if (font == nil)
    {
        font = [NSFont boldSystemFontOfSize:NSHeight(rect) - 3];
    }
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:font, NSFontAttributeName, foreground, NSForegroundColorAttributeName, nil];
    //center the capital letters, markings are in capitals: centering the whole line box (with room for descenders,
    //and computed differently by each macOS version) put the text too low; without NSStringDrawingUsesLineFragmentOrigin
    //the origin given to -drawWithRect: is the baseline, the same on every version since 10.4
    CGFloat baseline = NSMinY(rect) + ceil((NSHeight(rect) - [font capHeight]) / 2); //half points go up: sharp text, and it looks centered
    CGFloat width = [text sizeWithAttributes:attributes].width;
    [text drawWithRect:NSMakeRect(NSMinX(rect) + floor((NSWidth(rect) - width) / 2), baseline, width + 1, 0) options:0 attributes:attributes];
    if (left != nil)
    {
        [left drawWithRect:NSMakeRect(NSMinX(rect) + 4, baseline, NSWidth(rect), 0) options:0 attributes:attributes];
    }
    if (right != nil)
    {
        width = [right sizeWithAttributes:attributes].width;
        [right drawWithRect:NSMakeRect(NSMaxX(rect) - width - 4, baseline, width + 1, 0) options:0 attributes:attributes];
    }
}
