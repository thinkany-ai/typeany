#!/bin/bash
# Builds TypeAny's next-word prediction table (联想) from librime-predict's corpus data.
#   source: https://github.com/rime/librime-predict releases/data-1.0 predict.txt (BSD-3), Traditional Chinese
#   → OpenCC t2s → per word, keep the most frequent next words
# Output: .build/predict/predict.tsv   lines: word<TAB>next1 next2 …   (copied into the app bundle)
# Requires: brew install opencc
set -euo pipefail

PREDICT_URL="https://github.com/rime/librime-predict/releases/download/data-1.0/predict.txt"
MAX_PER_WORD=8

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/.build/rime-src/predict"
OUT="$ROOT/.build/predict"
mkdir -p "$SRC" "$OUT"

command -v opencc >/dev/null || { echo "opencc not found: brew install opencc"; exit 1; }

[ -f "$SRC/predict.txt" ] || curl -fsSL -o "$SRC/predict.txt" "$PREDICT_URL"
opencc -c t2s.json -i "$SRC/predict.txt" -o "$SRC/predict.simplified.txt"

python3 - "$SRC/predict.simplified.txt" "$OUT/predict.tsv" "$MAX_PER_WORD" <<'PY'
import sys, re
from collections import defaultdict
src, dst, limit = sys.argv[1], sys.argv[2], int(sys.argv[3])
han = re.compile(r"^[㐀-鿿]+$")
table = defaultdict(lambda: defaultdict(int))
for line in open(src, encoding="utf-8"):
    parts = line.rstrip("\n").split("\t")
    if len(parts) != 3:
        continue
    word, nxt, count = parts
    # skip the sentence-start key ($) and non-Chinese / numeric noise
    if not han.match(word) or not han.match(nxt):
        continue
    table[word][nxt] += int(count)  # t2s merges e.g. 這/这 entries
with open(dst, "w", encoding="utf-8") as f:
    for word in sorted(table):
        nexts = sorted(table[word].items(), key=lambda kv: -kv[1])[:limit]
        f.write(word + "\t" + " ".join(n for n, _ in nexts) + "\n")
print(f"{len(table)} words")
PY
echo "Prediction table ready: $OUT/predict.tsv ($(du -h "$OUT/predict.tsv" | cut -f1))"
