/*
 This source file is part of the Swift.org open source project

 Copyright 2015 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if os(OSX) || os(iOS) || os(Linux)
    extension Character {
        static var newline: Character { return "\n" }
    }
#else
    //ERROR: Unsupported platform
#endif

import struct PackageDescription.Version
import POSIX
import sys
import func sys.popen

class Git {
    class Repo {
        let root: String

        init?(root: String) {
            guard let realroot = try? realpath(root) else { self.root = ""; return nil }
            self.root = realroot
            guard Path.join(root, ".git").isDirectory else { return nil }
        }

        lazy var origin: String? = { repo in
            do {
                guard let url = try popen([Git.tool, "-C", repo.root, "config", "--get", "remote.origin.url"]).chuzzle() else {
                    return nil
                }
                if URL.scheme(url) == nil {
                    return try realpath(url)
                } else {
                    return url
                }

            } catch {
                //TODO better
                print("Bad git repository: \(repo.root)", toStream: &stderr)
                return ""
            }
        }(self)

        var versions: [Version] {
            let out = (try? popen([Git.tool, "-C", root, "tag", "-l"])) ?? ""
            let tags = out.characters.split(Character.newline)
            let versions = tags.flatMap(Version.init).sort()
            if !versions.isEmpty {
                return versions
            } else {
                return tags.flatMap(Version.vprefix).sort()
            }
        }

        /**
         - Returns: true if the package versions in this repository
           are all prefixed with "v", otherwise false. If there are
           no versions, returns false.
         */
        var versionsArePrefixed: Bool {
            return (try? popen([Git.tool, "-C", root, "tag", "-l"]))?.hasPrefix("v") ?? false
        }

        var branch: String! {
            return try? popen([Git.tool, "-C", root, "rev-parse", "--abbrev-ref", "HEAD"]).chomp()
        }

        func fetch() throws {
            try system(Git.tool, "-C", root, "fetch", "--tags", "origin", message: nil)
        }
    }

    class func clone(url: String, to dstdir: String) throws -> Repo {
        // canonicalize URL
        var url = url
        if URL.scheme(url) == nil {
            url = try realpath(url)
        }

        do {
            try system(Git.tool, "clone",
                "--recursive",   // get submodules too so that developers can use these if they so choose
                "--depth", "10",
                url, dstdir, message: "Cloning \(url)")
        } catch POSIX.Error.ExitStatus {
            throw Error.GitCloneFailure(url, dstdir)
        }

        return Repo(root: dstdir)!  //TODO no bangs
    }

    class var tool: String {
        return getenv("SWIFT_GIT") ?? "git"
    }
}

extension Version {
    private static func vprefix(string: String.CharacterView) -> Version? {
        if string.first == "v" {
            return Version(string.dropFirst())
        } else {
            return nil
        }
    }
}
