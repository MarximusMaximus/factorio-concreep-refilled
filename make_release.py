#! env python3

import json
import os
import os.path
import subprocess
import sys
import typing

def make_release() -> typing.Tuple[int, str]:
    my_abs_path = os.path.abspath(__file__)
    my_folder_abs_path = os.path.dirname(my_abs_path)

    os.chdir(my_folder_abs_path)

    folder_name = os.path.basename(my_folder_abs_path)
    mod_name = folder_name.removeprefix("factorio-")

    f = open(f"{mod_name}/info.json")
    text = f.read()
    data = json.loads(text)
    version = data["version"]

    os.makedirs("build", exist_ok=True)

    outfile = f"build/{mod_name}_{version}.zip"

    res = subprocess.run(["zip", "-vr", outfile, f"{mod_name}"])

    return res.returncode, outfile

if __name__ == "__main__":
    sys.exit(make_release())
