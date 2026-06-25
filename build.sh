#!/usr/bin/env bash
set -euo pipefail

bundle install
pnpm install
pnpm build
