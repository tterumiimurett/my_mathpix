import Foundation

struct AppVersionInfo: Equatable {
    let marketingVersion: String
    let build: String

    var displayName: String {
        "MyMathpix \(marketingVersion) (\(build))"
    }

    static var current: AppVersionInfo {
        let info = Bundle.main.infoDictionary ?? [:]
        return AppVersionInfo(
            marketingVersion: info["CFBundleShortVersionString"] as? String ?? "Development",
            build: info["CFBundleVersion"] as? String ?? "Development"
        )
    }
}

struct ThirdPartyLicense: Identifiable, Equatable {
    let name: String
    let text: String

    var id: String { name }
}

enum ThirdPartyLicenses {
    static var bundled: [ThirdPartyLicense] {
        guard let directory = AppResources.directoryURL,
              let text = try? String(
                contentsOf: directory.appendingPathComponent("KATEX-LICENSE.txt"),
                encoding: .utf8
              ),
              !text.isEmpty else {
            return []
        }
        return [ThirdPartyLicense(name: "KaTeX", text: text)]
    }
}
