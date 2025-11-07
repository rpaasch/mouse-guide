import Foundation
import AppKit

class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    private let githubRepo = "rpaasch/mouse-guide"
    private let currentVersion = "1.0"

    @Published var isChecking = false
    @Published var updateAvailable: UpdateInfo?

    struct UpdateInfo: Codable {
        let version: String
        let downloadURL: String
        let releaseNotes: String?
    }

    private struct GitHubRelease: Codable {
        let tag_name: String
        let html_url: String
        let body: String?
        let assets: [Asset]

        struct Asset: Codable {
            let name: String
            let browser_download_url: String
        }
    }

    func checkForUpdates(completion: @escaping (Result<UpdateInfo?, Error>) -> Void) {
        isChecking = true

        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            isChecking = false
            completion(.failure(NSError(domain: "UpdateChecker", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isChecking = false

                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NSError(domain: "UpdateChecker", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                    return
                }

                // Check if we got a 404 (no releases yet)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                    completion(.success(nil)) // No releases yet
                    return
                }

                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

                    // Remove 'v' prefix if present
                    let latestVersion = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name

                    // Compare versions
                    if self?.isNewerVersion(latestVersion, than: self?.currentVersion ?? "1.0") == true {
                        // Find .dmg asset
                        let dmgAsset = release.assets.first { $0.name.hasSuffix(".dmg") || $0.name.hasSuffix(".zip") }
                        let downloadURL = dmgAsset?.browser_download_url ?? release.html_url

                        let updateInfo = UpdateInfo(
                            version: latestVersion,
                            downloadURL: downloadURL,
                            releaseNotes: release.body
                        )

                        self?.updateAvailable = updateInfo
                        completion(.success(updateInfo))
                    } else {
                        // Already on latest version
                        completion(.success(nil))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    private func isNewerVersion(_ version1: String, than version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(v1Components.count, v2Components.count) {
            let v1Part = i < v1Components.count ? v1Components[i] : 0
            let v2Part = i < v2Components.count ? v2Components[i] : 0

            if v1Part > v2Part {
                return true
            } else if v1Part < v2Part {
                return false
            }
        }

        return false // Versions are equal
    }

    func getCurrentVersion() -> String {
        return currentVersion
    }

    func openDownloadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
