import XCTest
import XCTestCaseProvider

import func POSIX.mkdir
import func POSIX.rename
import func POSIX.popen
import func POSIX.symlink
import func sys.walk

import struct sys.Path


class ValidLayoutsTestCase: XCTestCase, XCTestCaseProvider {

    func testSingleModuleLibrary() {
        runLayoutFixture(name: "SingleModule/Library") { prefix in
            XCTAssertBuilds(prefix)
            XCTAssertFileExists(prefix, ".build", "debug", "Library.a")
        }
    }

    func testSingleModuleExecutable() {
        runLayoutFixture(name: "SingleModule/Executable") { prefix in
            XCTAssertBuilds(prefix)
            XCTAssertFileExists(prefix, ".build", "debug", "Executable")
        }
    }

    func testSingleModuleCustomizedName() {

        // Package.swift for a single module with a customized name
        // names that target after the package name

        runLayoutFixture(name: "SingleModule/CustomizedName") { prefix in
            XCTAssertBuilds(prefix)
            XCTAssertFileExists(prefix, ".build", "debug", "Bar.a")
        }
    }

    func testMultipleModulesLibraries() {
        runLayoutFixture(name: "MultipleModules/Libraries") { prefix in
            XCTAssertBuilds(prefix)
            for x in ["Bar", "Baz", "Foo"] {
                XCTAssertFileExists(prefix, ".build", "debug", "\(x).a")
            }
        }
    }

    func testMultipleModulesExecutables() {
        runLayoutFixture(name: "MultipleModules/Executables") { prefix in
            XCTAssertBuilds(prefix)
            for x in ["Bar", "Baz", "Foo"] {
                let output = try popen(["\(prefix)/.build/debug/\(x)"])
                XCTAssertEqual(output, "\(x)\n")
            }
        }
    }
}


//MARK: Utility

extension ValidLayoutsTestCase {
    func runLayoutFixture(name name: String, line: UInt = __LINE__, @noescape body: (String) throws -> Void) {
        let name = "ValidLayouts/\(name)"

        // 1. Rooted layout
        fixture(name: name, file: __FILE__, line: line, body: body)

        // 2. Move everything to a directory called "Sources"
        fixture(name: name, file: __FILE__, line: line) { prefix in
            let files = walk(prefix, recursively: false).filter{ $0.basename != "Package.swift" }
            let dir = try mkdir(prefix, "Sources")
            for file in files {
                let tip = Path(file).relative(to: prefix)
                try rename(old: file, new: Path.join(dir, tip))
            }
            try body(prefix)
        }

        // 3. Symlink some other directory to a directory called "Sources"
        fixture(name: name, file: __FILE__, line: line) { prefix in
            let files = walk(prefix, recursively: false).filter{ $0.basename != "Package.swift" }
            let dir = try mkdir(prefix, "Floobles")
            for file in files {
                let tip = Path(file).relative(to: prefix)
                try rename(old: file, new: Path.join(dir, tip))
            }
            try symlink(create: "\(prefix)/Sources", pointingAt: dir, relativeTo: prefix)
            try body(prefix)
        }
    }
}


//MARK: Boilerplate

extension ValidLayoutsTestCase {
    var allTests : [(String, () -> Void)] {
        return [
            ("testSingleModuleLibrary", testSingleModuleLibrary),
            ("testSingleModuleExecutable", testSingleModuleExecutable),
            ("testSingleModuleCustomizedName", testSingleModuleCustomizedName),
            ("testMultipleModulesLibraries", testMultipleModulesLibraries),
            ("testMultipleModulesExecutables", testMultipleModulesExecutables),
        ]
    }
}
