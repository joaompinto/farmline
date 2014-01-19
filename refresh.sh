#!/bin/bash
SOURCE_DIR=../farmline
[[ ! -d $SOURCE_DIR ]] && echo "$SOURCE_DIR was not found" && exit 1
rm -rf common
cp -va $SOURCE_DIR/common .
cp -vp $SOURCE_DIR/web/{*.html,*.css,*.dart,*.js} web
cp -vp $SOURCE_DIR/packages/browser/dart.js web/packages/browser
