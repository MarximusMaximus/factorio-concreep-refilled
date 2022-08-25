#! env python3

import make_release
import shutil
import sys

def make_debug() -> None:
    ret, outfile = make_release.make_release()

    if ret != 0:
        sys.exit(ret)

    shutil.rmtree("run/mods", ignore_errors=True)
    shutil.copytree("mods_debug", "run/mods")
    shutil.copy2(outfile, "run/mods")

if __name__ == "__main__":
    make_debug()
