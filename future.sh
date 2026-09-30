#!/bin/bash
# Clang's experimental vtable ABIs on the 1800-class corpus: static ELF accounting.
#
#   CXX=clang++ ./future.sh
#
# omit-vtable-rtti drops the (already null) typeinfo slot; relative vtables store
# 32-bit offsets instead of pointers. Both are ABI breaks: everything linked together,
# the C++ runtime included, must agree. Needs Clang 18 or later.
set -u
cd "$(dirname "$0")"
CXX=${CXX:-clang++}
J=$(nproc)
python3 gen_scale.py

OMIT="-Xclang -fexperimental-omit-vtable-rtti"
REL="-fexperimental-relative-c++-abi-vtables"
declare -A FLAGS=( [rtti]="-frtti" [nortti]="-fno-rtti" [omit]="-fno-rtti $OMIT"
                   [rel]="-fno-rtti $REL" [rel_omit]="-fno-rtti $REL $OMIT" )
ORDER=(rtti nortti omit rel rel_omit)

for v in "${ORDER[@]}"; do
  rm -rf obj_f_$v; mkdir -p obj_f_$v
  ls scale_*.cpp scale_factory.cpp | xargs -P $J -I{} sh -c \
    "$CXX -O2 -DNDEBUG -fPIC -fvisibility=hidden ${FLAGS[$v]} -c {} -o obj_f_$v/\$(basename {} .cpp).o" || exit 1
  $CXX -shared obj_f_$v/*.o -o libfuture_$v.so || exit 1
done

sec()  { readelf -SW "$1" | sed 's/\[[ 0-9]*\]//' | awk -v n="$2" '$1==n{print strtonum("0x" $5); f=1} END{if(!f)print 0}'; }
relc() { readelf -rW "$1" | grep -c '^[0-9a-f]\{16\}'; }
vtb()  { nm -S "$1" | awk '$4 ~ /^_ZTV/ && $4 !~ /\.local$/ {s+=strtonum("0x" $2)} END{print s+0}'; }

printf "%-22s" "metric"; for v in "${ORDER[@]}"; do printf "%12s" "$v"; done; echo
row() { printf "%-22s" "$1"; for v in "${ORDER[@]}"; do printf "%12s" "$($2 libfuture_$v.so ${3:-})"; done; echo; }
row "file size (bytes)"    "stat -c %s"
row "dynamic relocations"  relc
row "vtable bytes"         vtb
row ".data.rel.ro (bytes)" sec .data.rel.ro
row ".rodata (bytes)"      sec .rodata
