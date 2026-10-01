#!/bin/bash
# Assembles Rime shared data for TypeAny and prebuilds the dictionaries.
#   - rime-ice (雾凇拼音, GPL-3.0), pinned revision: schemas, dicts, lua, emoji
#   - Rime/typeany_pinyin.schema.yaml: rime-ice's schema + TypeAny patches
#   - Rime/typeany_phrase.txt: high-frequency abbreviations (s → 是 …)
# Output: .build/rime-data (copied into TypeAny.app/Contents/SharedSupport/rime-data)
set -euo pipefail

RIME_ICE_REPO="https://github.com/iDvel/rime-ice.git"
RIME_ICE_REV="3aea6d3694fb3d94ec663641f021f788822897ad"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.build/rime-src/rime-ice"
OUT="$ROOT/.build/rime-data"

command -v rime_deployer >/dev/null || { echo "rime_deployer not found: brew install librime"; exit 1; }

if [ ! -d "$SRC/.git" ]; then
  mkdir -p "$(dirname "$SRC")"
  git init -q "$SRC"
  git -C "$SRC" remote add origin "$RIME_ICE_REPO"
fi
if [ "$(git -C "$SRC" rev-parse -q --verify HEAD 2>/dev/null)" != "$RIME_ICE_REV" ]; then
  echo "Fetching rime-ice @ ${RIME_ICE_REV:0:7}..."
  git -C "$SRC" fetch -q --depth 1 origin "$RIME_ICE_REV"
  git -C "$SRC" checkout -q FETCH_HEAD
fi

rm -rf "$OUT"
mkdir -p "$OUT/opencc"
# The full rime-ice distribution: schemas, dictionaries, lua scripts, emoji/OpenCC data
cp "$SRC"/*.yaml "$SRC"/*.txt "$SRC/LICENSE" "$OUT/"
cp -R "$SRC/cn_dicts" "$SRC/en_dicts" "$SRC/lua" "$OUT/"
cp "$SRC"/opencc/* "$OUT/opencc/"
rm -f "$OUT/squirrel.yaml" "$OUT/weasel.yaml" "$OUT/recipe.yaml"

# Simplified → Traditional conversion (rime-ice's 简繁切换) uses OpenCC's s2t data
OPENCC_DIR="$(brew --prefix opencc 2>/dev/null)/share/opencc"
for f in s2t.json STPhrases.ocd2 STPhrases_GeneratedFromRegionalPhrases.ocd2 STCharacters.ocd2 \
         CJK_Compatibility_Ideographs.ocd2; do
  [ -f "$OPENCC_DIR/$f" ] && cp "$OPENCC_DIR/$f" "$OUT/opencc/"
done

# rime-ice's default.yaml, with schema_list reduced to TypeAny's schema
python3 - "$SRC/default.yaml" "$OUT/default.yaml" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
src = re.sub(r"^schema_list:\n(?:[ \t]+.*\n|\n)*?(?=^\S)",
             "schema_list:\n  - schema: typeany_pinyin\n\n", src, count=1, flags=re.M)
open(sys.argv[2], "w", encoding="utf-8").write(src)
PY

# TypeAny's schema (includes rime_ice.schema) and phrase table
cp "$ROOT"/Rime/*.yaml "$ROOT"/Rime/*.txt "$OUT/"

# Pin every typeany_phrase.txt entry to the top for its code via rime-ice's pin_cand_filter;
# otherwise completion (sh → shi → 是) can outrank the phrase. Appended to the schema's __patch.
python3 - "$OUT/typeany_phrase.txt" "$OUT/typeany_pinyin.schema.yaml" <<'PY'
import sys
from collections import defaultdict
pins = defaultdict(list)
started = False
for line in open(sys.argv[1], encoding="utf-8"):
    if line.startswith("# 此行之后不能写注释"):
        started = True
        continue
    parts = line.rstrip("\n").split("\t")
    if not started or len(parts) < 2 or line.startswith("#"):
        continue
    weight = float(parts[2]) if len(parts) > 2 else 0
    pins[parts[1]].append((weight, parts[0]))
lines = ["", "  # generated from typeany_phrase.txt by build-rime-data.sh", "  pin_cand_filter/+:"]
for code, words in pins.items():
    ordered = " ".join(w for _, w in sorted(words, key=lambda x: -x[0]))
    lines.append(f'    - "{code}\t{ordered}"')
with open(sys.argv[2], "a", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
PY

echo "Prebuilding Rime dictionaries (first time takes a while)..."
(cd "$OUT" && rime_deployer --build "$OUT" "$OUT" "$OUT/build" >/dev/null)

# Drop user-side artefacts produced by the deployer; only shared data ships
rm -rf "$OUT"/*.userdb "$OUT/installation.yaml" "$OUT/user.yaml"
echo "Rime data ready: $OUT ($(du -sh "$OUT" | cut -f1))"
