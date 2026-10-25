#!/bin/sh
# Side by side, for checking a screen: the app's screenshot (left) and the
# Figma screen (right). Usage: compare.sh REFS SHOTS OUT name.png
magick "$1/$4" -resize 50% "$2/$4" -background white -gravity north +append "$3/$4"
