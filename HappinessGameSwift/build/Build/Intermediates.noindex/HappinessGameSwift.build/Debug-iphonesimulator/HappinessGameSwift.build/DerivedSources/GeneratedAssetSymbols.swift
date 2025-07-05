import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = DeveloperToolsSupport.ColorResource(name: "AccentColor", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "かぐや" asset catalog image resource.
    static let かぐや = DeveloperToolsSupport.ImageResource(name: "かぐや", bundle: resourceBundle)

    /// The "かのかり" asset catalog image resource.
    static let かのかり = DeveloperToolsSupport.ImageResource(name: "かのかり", bundle: resourceBundle)

    /// The "青豚" asset catalog image resource.
    static let 青豚 = DeveloperToolsSupport.ImageResource(name: "青豚", bundle: resourceBundle)

}

