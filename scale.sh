#!/bin/bash
# Size / relocation / load-time impact at scale, separating -fno-rtti from -fno-exceptions.
set -u
cd "$(dirname "$0")"

# Override to taste:  CXX=g++-13 PIN="taskset -c 7" ./run.sh
CXX=${CXX:-g++}
CC=${CC:-gcc}
PIN=${PIN:-}
J=$(nproc)
hr() { printf '%.0s─' $(seq 1 84); echo; }

python3 gen_scale.py

declare -A FLAGS=( [rtti]="-frtti"
                   [nortti]="-fno-rtti"
                   [nortti_noexc]="-fno-rtti -fno-exceptions" )
ORDER=(rtti nortti nortti_noexc)

build() {                       # $1 = variant ; echoes best-of-2 wall seconds
  local v=$1 f=${FLAGS[$1]} best=999
  for pass in 1 2; do
    rm -rf obj_$v; mkdir -p obj_$v
    local t0=$(date +%s.%N)
    ls scale_*.cpp scale_factory.cpp | \
      xargs -P $J -I{} sh -c "$CXX -O2 -DNDEBUG -fPIC -fvisibility=hidden $f -c {} -o obj_$v/\$(basename {} .cpp).o"
    $CXX -shared obj_$v/*.o -o libscale_$v.so || exit 1
    local t1=$(date +%s.%N)
    best=$(awk "BEGIN{d=$t1-$t0; print (d<$best)?d:$best}")
  done
  echo "$best"
}

declare -A T
for v in "${ORDER[@]}"; do T[$v]=$(build $v); done

sec()  { readelf -SW "$1" | sed 's/\[[ 0-9]*\]//' | awk -v n="$2" '$1==n{print strtonum("0x" $5); f=1} END{if(!f)print 0}'; }
relc() { readelf -rW "$1" | grep -c '^[0-9a-f]\{16\}'; }
sym()  { nm -a "$1" | grep -c " $2"; }

printf "%-30s %13s %13s %15s\n" "metric" "-frtti" "-fno-rtti" "+ -fno-exceptions"
hr
row() { # $1 label ; $2.. values
  local lbl=$1; shift
  local a=$1 b=$2 c=$3
  printf "%-30s %13s %13s %15s\n" "$lbl" "$a" "$b" "$c"
  printf "%-30s %13s %13s %15s\n" "" "" \
     "$(awk "BEGIN{printf \"%+.1f%%\", ($b-$a)*100.0/$a}")" \
     "$(awk "BEGIN{printf \"%+.1f%%\", ($c-$a)*100.0/$a}")"
}
row "file size (bytes)"      $(stat -c %s libscale_rtti.so)      $(stat -c %s libscale_nortti.so)      $(stat -c %s libscale_nortti_noexc.so)
row "dynamic relocations"    $(relc libscale_rtti.so)            $(relc libscale_nortti.so)            $(relc libscale_nortti_noexc.so)
row ".rodata (bytes)"        $(sec libscale_rtti.so .rodata)     $(sec libscale_nortti.so .rodata)     $(sec libscale_nortti_noexc.so .rodata)
row ".data.rel.ro (bytes)"   $(sec libscale_rtti.so .data.rel.ro) $(sec libscale_nortti.so .data.rel.ro) $(sec libscale_nortti_noexc.so .data.rel.ro)
row ".eh_frame (bytes)"      $(sec libscale_rtti.so .eh_frame)   $(sec libscale_nortti.so .eh_frame)   $(sec libscale_nortti_noexc.so .eh_frame)
row ".gcc_except_table"      $(sec libscale_rtti.so .gcc_except_table) $(sec libscale_nortti.so .gcc_except_table) $(sec libscale_nortti_noexc.so .gcc_except_table)
row "_ZTV vtable symbols"    $(sym libscale_rtti.so _ZTV)        $(sym libscale_nortti.so _ZTV)        $(sym libscale_nortti_noexc.so _ZTV)
row "_ZTI typeinfo symbols"  $(sym libscale_rtti.so _ZTI)        $(sym libscale_nortti.so _ZTI)        $(sym libscale_nortti_noexc.so _ZTI)
row "_ZTS typename symbols"  $(sym libscale_rtti.so _ZTS)        $(sym libscale_nortti.so _ZTS)        $(sym libscale_nortti_noexc.so _ZTS)
hr
printf "%-30s %13.2f %13.2f %15.2f   (best of 2, -j%s)\n" "compile wall time (s)" ${T[rtti]} ${T[nortti]} ${T[nortti_noexc]} "$J"
echo
hr; echo "load cost"; hr
$CC -O2 -o loadbench loadbench.c -ldl || exit 1
for v in "${ORDER[@]}"; do $PIN ./loadbench ./libscale_$v.so 400; echo; done
