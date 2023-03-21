# Package

version       = "0.1.0"
author        = "silent-observer"
description   = "Chess web app (with AI)"
license       = "MIT"
srcDir        = "src"
bin           = @["chess_app"]


# Dependencies

requires "nim >= 1.6.2"
requires "jester >= 0.5.0"
requires "fusion >= 1.1"

import os

before build:
  echo "Building js!"
  for f in listFiles("src/js"):
    echo f
    let file_parts = splitFile(f)
    let out_file = ("public" / "js" / file_parts.name).addFileExt ".js"
    exec("nim js -o=" & out_file & " " & f)