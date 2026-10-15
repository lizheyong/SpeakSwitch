import AppKit
import SwiftUI
import UniformTypeIdentifiers
import VoiceSwitchCore

@MainActor
struct ProviderIcon: View {
    let provider: Provider
    let size: CGFloat

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .renderingMode(.original)
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private var icon: NSImage {
        if let url = installedApplicationURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if !provider.isCustom, let image = ProviderIconResources.image(named: provider.id) {
            return image
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }

    private var installedApplicationURL: URL? {
        var candidates: [URL] = []
        if let path = provider.appPath {
            candidates.append(URL(fileURLWithPath: path))
        }
        candidates += provider.bundleIDs.compactMap {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        }
        let roots = [
            "/Applications", NSHomeDirectory() + "/Applications",
            "/Library/Input Methods", NSHomeDirectory() + "/Library/Input Methods"
        ]
        for root in roots {
            for name in provider.appNames {
                candidates.append(URL(fileURLWithPath: root).appendingPathComponent(name + ".app"))
            }
        }
        return candidates.first { FileManager.default.fileExists(atPath: $0.path) }
    }
}

@MainActor
private enum ProviderIconResources {
    // Packaged apps keep the SwiftPM bundle in Contents/Resources. SwiftPM
    // command-line runs use the generated Bundle.module accessor directly.
    private static let bundle: Bundle = {
        if let url = Bundle.main.url(forResource: "VoiceSwitch_VoiceSwitch", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return Bundle.module
    }()

    static func image(named name: String) -> NSImage? {
        bundle.url(forResource: name, withExtension: "png", subdirectory: "ProviderIcons")
            .flatMap { NSImage(contentsOf: $0) }
    }
}
