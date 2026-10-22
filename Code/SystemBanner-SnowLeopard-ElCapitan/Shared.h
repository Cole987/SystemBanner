//Copyright (c) 2023, Aaron Wawrzyniak. MIT License Applies.
//Mac OS X 10.6 Snow Leopard to 10.11 El Capitan port: Copyright (c) 2026, Cole. MIT License Applies.
//Shared by the banner (SystemBanner.m) and SystemBanner Settings (Settings.m).
#import <Cocoa/Cocoa.h>

//the preferences domain, the macOS counterpart of HKLM\SOFTWARE\Policies\SystemBanner
#define PREF_DOMAIN CFSTR("com.systembanner")
#define PREF_FILE @"/Library/Preferences/com.systembanner"

extern const int stockColors[7][6];
extern NSString *const stockTexts[7];

extern BOOL debug;
extern BOOL bannerTopAndBottom;
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
