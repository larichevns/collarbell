#!/bin/sh
# Regenerates the API client in lib/data/api/generated from
# contracts/openapi.json. Run from anywhere: sh mobile/tool/generate_api.sh
# CI runs it too and fails if the result differs from the committed files.
set -e
cd "$(dirname "$0")/.."

# Start from an empty folder (except the README), so that models removed
# from the contract disappear too.
find lib/data/api/generated -type f ! -name README.md -delete

# 1. Retrofit clients and json_serializable models (settings: swagger_parser.yaml).
dart run swagger_parser

# 2. Their *.g.dart parts (settings: build.yaml). JIT mode, because AOT
#    compilation of the build script fails on Dart 3.10 when plugins with
#    build hooks are in the dependencies.
dart run build_runner build --force-jit
