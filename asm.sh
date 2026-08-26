#!/bin/bash
cd "$(dirname "$0")"

# Override to taste:  CXX=g++-13 PIN="taskset -c 7" ./run.sh
CXX=${CXX:-g++}
CC=${CC:-gcc}
PIN=${PIN:-}
$CXX -O2 -DNDEBUG -frtti -c asm.cpp -o asm.o
for f in via_fake_rtti via_is_a via_dynamic_cast; do
  echo "=== $f ==="
  objdump -d --no-show-raw-insn asm.o | \
    awk -v fn="$f" '/^[0-9a-f]+ </{p = index($0, fn)>0} p && NF' | \
    sed 's/^[0-9a-f]*:\t/    /' | head -30
  echo
done
