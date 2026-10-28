//
//  RegexGenerator.swift
//  Browserino
//
//  Created by Claude Code on 28.10.2026.
//

import Foundation

enum RegexGenerator {
    private static let secondLevelSuffixes: Set<String> = ["co", "com", "org", "net", "ac", "gov", "edu"]

    /// Builds a regex that matches the given URLs and URLs like them.
    ///
    /// URLs are grouped by domain. Within a group the pattern keeps the hostname
    /// suffix all URLs share (allowing other subdomains if the examples differ)
    /// and, given several different paths, the path segments they all start with.
    /// Queries and fragments are ignored.
    static func regex(from lines: [String]) -> String? {
        let urls = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { line -> URLComponents? in
                let withScheme = line.contains("://") ? line : "https://" + line
                guard let components = URLComponents(string: withScheme),
                      let host = components.host, !host.isEmpty else {
                    return nil
                }
                return components
            }

        guard !urls.isEmpty else {
            return nil
        }

        let schemes = Set(urls.compactMap { $0.scheme?.lowercased() })
        let schemePattern = schemes.isSubset(of: ["http", "https"])
            ? "https?"
            : "(?:" + schemes.sorted().map(escape).joined(separator: "|") + ")"

        let groups = Dictionary(grouping: urls) { baseDomain(of: $0.host!.lowercased()) }
        let groupPatterns = groups.keys.sorted().map { pattern(for: groups[$0]!, baseDomain: $0) }
        let hostAndPath = groupPatterns.count == 1
            ? groupPatterns[0]
            : "(?:" + groupPatterns.joined(separator: "|") + ")"

        return "^\(schemePattern)://\(hostAndPath)"
    }

    private static func pattern(for urls: [URLComponents], baseDomain: String) -> String {
        let hostLabels = urls.map { $0.host!.lowercased().split(separator: ".").map(String.init) }
        var suffix = Array(commonPrefix(hostLabels.map { Array($0.reversed()) }).reversed())
        var subdomains = hostLabels.map { Array($0.dropLast(suffix.count)) }

        if suffix.first == "www" && suffix.count > 2 {
            suffix.removeFirst()
            subdomains = subdomains.map { $0 + ["www"] }
        }

        let isBareDomain = suffix.count >= 2 && Int(suffix.last!) == nil && suffix.joined(separator: ".") == baseDomain

        let subdomainPattern: String
        if subdomains.allSatisfy(\.isEmpty) {
            subdomainPattern = isBareDomain ? "(?:www\\.)?" : ""
        } else if subdomains.allSatisfy({ $0.isEmpty || $0 == ["www"] }) {
            subdomainPattern = "(?:www\\.)?"
        } else {
            subdomainPattern = "(?:[\\w-]+\\.)*"
        }

        let hostPattern = subdomainPattern + suffix.map(escape).joined(separator: "\\.")

        let ports = Set(urls.map(\.port))
        let portPattern = ports.count == 1 && ports.first! != nil ? ":\(ports.first!!)" : ""

        // A single path says nothing about which part of it matters, so it is left out.
        let paths = Set(urls.map(\.percentEncodedPath))
        let pathSegments = paths.count > 1
            ? commonPrefix(paths.sorted().map { $0.split(separator: "/").map(String.init) })
            : []
        let pathPattern = pathSegments.map { "/" + escape($0) }.joined()

        // Without a port in the examples any port is allowed, unless a path follows.
        let terminator = pathPattern.isEmpty && portPattern.isEmpty ? "(?:[:/?#]|$)" : "(?:[/?#]|$)"

        return hostPattern + portPattern + pathPattern + terminator
    }

    private static func baseDomain(of host: String) -> String {
        let labels = host.split(separator: ".").map(String.init)

        if labels.allSatisfy({ Int($0) != nil }) {
            return host
        }

        var count = 2
        if labels.count >= 3,
           labels[labels.count - 1].count == 2,
           secondLevelSuffixes.contains(labels[labels.count - 2]) {
            count = 3
        }

        return labels.suffix(count).joined(separator: ".")
    }

    private static func commonPrefix(_ arrays: [[String]]) -> [String] {
        guard var prefix = arrays.first else {
            return []
        }

        for array in arrays.dropFirst() {
            prefix = Array(zip(prefix, array).prefix { $0 == $1 }.map(\.0))
        }

        return prefix
    }

    private static func escape(_ string: String) -> String {
        NSRegularExpression.escapedPattern(for: string)
    }
}
