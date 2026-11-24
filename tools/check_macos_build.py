"""T-264: checks a macOS export (the zip tools/build_macos.sh makes) without a Mac.

    python -I tools/check_macos_build.py build/ClaudeZombies_<version>_macos.zip [-v]

Reads the zip's entries, the bundle's Info.plist and the Mach-O headers of the executable: both architectures
(x86_64 + arm64), each slice's minimum macOS, whether it carries a code signature and whether that is ad-hoc, the
executable bit in the zip, the .pck and the sealed-resources file. Exit code 0 = everything this script can see is
in order. It cannot run the app: only a Mac can.
"""
import plistlib
import struct
import sys
import zipfile

CPU = {0x01000007: "x86_64", 0x0100000C: "arm64"}


def thin(b, off, size):
    magic = struct.unpack_from("<I", b, off)[0]
    if magic != 0xFEEDFACF:
        return {"error": "not a 64-bit Mach-O (%08x)" % magic}
    cputype, _sub, _ftype, ncmds, _sz, _flags = struct.unpack_from("<iiIIII", b, off + 4)
    out = {"arch": CPU.get(cputype & 0xFFFFFFFF, hex(cputype)), "size": size, "minos": None, "signed": False, "adhoc": None, "ident": None}
    p = off + 32
    for _ in range(ncmds):
        cmd, csz = struct.unpack_from("<II", b, p)
        if cmd == 0x32:  # LC_BUILD_VERSION
            _plat, minos, _sdk = struct.unpack_from("<III", b, p + 8)
            out["minos"] = "%d.%d" % (minos >> 16, (minos >> 8) & 255)
        elif cmd == 0x24:  # LC_VERSION_MIN_MACOSX
            minos = struct.unpack_from("<I", b, p + 8)[0]
            out["minos"] = "%d.%d" % (minos >> 16, (minos >> 8) & 255)
        elif cmd == 0x1D:  # LC_CODE_SIGNATURE
            dataoff, datasize = struct.unpack_from("<II", b, p + 8)
            out["signed"] = True
            sig = b[off + dataoff: off + dataoff + datasize]
            i = sig.find(b"\xfa\xde\x0c\x02")  # the CodeDirectory blob
            if i >= 0:
                flags = struct.unpack_from(">I", sig, i + 12)[0]
                out["adhoc"] = bool(flags & 0x2)
                identoff = struct.unpack_from(">I", sig, i + 20)[0]
                out["ident"] = sig[i + identoff: sig.index(b"\0", i + identoff)].decode("utf-8", "replace")
        p += csz
    return out


def slices(b):
    magic = struct.unpack_from(">I", b, 0)[0]
    if magic == 0xCAFEBABE:
        n = struct.unpack_from(">I", b, 4)[0]
        res = []
        for i in range(n):
            _c, _s, off, size, _a = struct.unpack_from(">iiIII", b, 8 + i * 20)
            res.append(thin(b, off, size))
        return res
    return [thin(b, 0, len(b))]


def main():
    path = sys.argv[1]
    verbose = "-v" in sys.argv
    z = zipfile.ZipFile(path)
    names = z.namelist()
    bad = []
    apps = sorted({n.split(".app/")[0] + ".app" for n in names if ".app/" in n})
    print("[check_macos] %s: %d entries, bundle(s): %s" % (path, len(names), ", ".join(apps) or "NONE"))
    if len(apps) != 1:
        bad.append("expected exactly one .app bundle")
    if verbose:
        for n in names:
            i = z.getinfo(n)
            print("    %s %10d %s" % (oct(i.external_attr >> 16), i.file_size, n))
    plists = [n for n in names if n.endswith(".app/Contents/Info.plist")]
    exe_name = None
    if not plists:
        bad.append("no Contents/Info.plist")
    else:
        pl = plistlib.loads(z.read(plists[0]))
        exe_name = pl.get("CFBundleExecutable")
        for k in ("CFBundleName", "CFBundleDisplayName", "CFBundleIdentifier", "CFBundleExecutable", "CFBundleShortVersionString", "CFBundleVersion",
                  "LSMinimumSystemVersionByArchitecture", "LSArchitecturePriority", "NSHighResolutionCapable", "LSApplicationCategoryType", "CFBundleIconFile"):
            print("[check_macos]   %s = %r" % (k, pl.get(k)))
        if not pl.get("CFBundleIdentifier"):
            bad.append("no bundle identifier")
        if pl.get("NSHighResolutionCapable") is not True:
            print("[check_macos]   note: not high-resolution capable (the OS upscales a low-DPI picture)")
    exes = [n for n in names if ".app/Contents/MacOS/" in n and not n.endswith("/")]
    if not exes:
        bad.append("no executable in Contents/MacOS")
    for n in exes:
        i = z.getinfo(n)
        mode = i.external_attr >> 16
        print("[check_macos]   executable %s, %d bytes, mode %s" % (n, i.file_size, oct(mode)))
        if not mode & 0o111:
            bad.append("%s has no executable bit in the zip (unzip on a Mac would give a file that cannot start)" % n)
        if exe_name and not n.endswith("/MacOS/" + exe_name):
            bad.append("%s is not the plist's CFBundleExecutable %s" % (n, exe_name))
        sl = slices(z.read(n))
        archs = set()
        for t in sl:
            print("[check_macos]     slice %s" % t)
            archs.add(t.get("arch"))
            if not t.get("signed"):
                bad.append("the %s slice has no code signature (Apple silicon refuses unsigned arm64 code)" % t.get("arch"))
        if archs != {"x86_64", "arm64"}:
            bad.append("expected x86_64 + arm64, found %s" % sorted(archs))
    pcks = [n for n in names if n.endswith(".pck")]
    for n in pcks:
        print("[check_macos]   pck %s, %d bytes" % (n, z.getinfo(n).file_size))
    if not pcks:
        bad.append("no .pck in Contents/Resources")
    seal = [n for n in names if n.endswith("_CodeSignature/CodeResources")]
    print("[check_macos]   sealed resources (_CodeSignature/CodeResources): %s" % ("present" if seal else "absent"))
    if not seal:
        bad.append("no _CodeSignature/CodeResources (the bundle is not sealed)")
    icons = [n for n in names if n.endswith(".icns")]
    print("[check_macos]   icon: %s" % (", ".join(icons) or "none"))
    for b_ in bad:
        print("[check_macos] PROBLEM: " + b_)
    print("[check_macos] RESULT: %s" % ("ok" if not bad else "%d problem(s)" % len(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
