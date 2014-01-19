#!/bin/bash
SOURCE_DIR=../farmline
[[ ! -d $SOURCE_DIR ]] && echo "$SOURCE_DIR was not found" && exit 1
cp -vp $SOURCE_DIR/web/{*.dart,*.js} web
cp -vp $SOURCE_DIR/packages/browser/dart.js web
