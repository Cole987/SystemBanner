//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
//Mac OS X 10.6 Snow Leopard to 10.11 El Capitan port: Copyright (c) 2026, Cole. MIT License Applies.
//Shared by the banner (SystemBanner.m) and the System Preferences pane (SettingsPane.m).
#import <Cocoa/Cocoa.h>

//the preferences domain, the macOS counterpart of HKLM\SOFTWARE\Policies\SystemBanner
#define PREF_DOMAIN CFSTR("com.systembanner")
#define PREF_FILE @"/Library/Preferences/com.systembanner"

//a stock classification, chosen with the Simple setting
typedef struct
{
    int code;         //value of the Simple setting
    NSString *system; //classification system, groups the classifications in the settings
    NSString *text;
    int colors[6];    //background red, green, blue, then text red, green, blue, same order as the "0" to "5" preference keys
} Preset;

extern const int unconfiguredColors[6];
extern NSString *const unconfiguredText;
extern const Preset presets[];
extern const int presetCount;
const Preset *PresetForCode(int code); //NULL when no stock classification has this code
NSString *PresetTitle(const Preset *preset); //"France – SECRET", for the settings

extern BOOL debug;
extern BOOL bannerTopAndBottom;
extern BOOL arrangeWindows; //move the windows of other apps out from under the banners (needs Accessibility access)
extern int bannerColor[6];
extern NSString *bannerText;
extern NSString *lastPrefSummary;

id PrefValue(NSString *key);
BOOL PrefInt(NSString *key, int *result);
BOOL PrefsAreManaged(void);
void ReadPrefs(void);
void LogString(NSString *msg);
NSColor *ColorFromBytes(const int *rgb);
//draws a banner (color, centered text) in rect, also used by the Settings preview
void DrawBanner(NSRect rect, NSString *text, NSColor *background, NSColor *foreground, NSString *left, NSString *right);
