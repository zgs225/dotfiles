#!/bin/sh

set -e

if command -v mise &>/dev/null; then
  mise install -q
fi
