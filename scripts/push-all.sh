#!/bin/zsh
set -euo pipefail

git push origin main
git push origin --tags
git push gitee main
git push gitee --tags
