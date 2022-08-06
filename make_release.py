#! env python3

import json
import os
import os.path
import subprocess

os.chdir(os.path.dirname(__file__))

name = "concreep-refilled"

f = open(f"{name}/info.json")
text = f.read()
data = json.loads(text)
version = data["version"]

os.makedirs("build", exist_ok=True)

subprocess.run(["zip", "-vr", f"build/{name}_{version}.zip", f"{name}"])
