#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.example.HappinessGameSwift";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

#warning The "かぐや" image asset name resolves to an empty symbol. Try renaming the asset.

#warning The "かのかり" image asset name resolves to an empty symbol. Try renaming the asset.

#warning The "青豚" image asset name resolves to an empty symbol. Try renaming the asset.

#undef AC_SWIFT_PRIVATE
