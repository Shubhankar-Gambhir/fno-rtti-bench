#!/bin/bash
# Measure the cost/benefit of -fno-rtti on a HotSpot BarrierSet-shaped hierarchy.
set -u
cd "$(dirname "$0")"

# Override to taste:  CXX=g++-13 PIN="taskset -c 7" ./run.sh
CXX=${CXX:-g++}
CC=${CC:-gcc}
PIN=${PIN:-}
# Flags used for the published numbers. -march is Skylake-AVX512; drop or retarget
# it on other hardware. The alignment flags were measured to make no difference to
# this benchmark, and are kept only for consistency with the rest of the series.
BENCHFLAGS=${BENCHFLAGS:--std=c++17 -O2 -march=native -fcf-protection -falign-functions=64 -falign-loops=64 -DNDEBUG}
J=$(nproc)
hr() { printf '%.0s─' $(seq 1 78); echo; }

echo "### generating scale corpus"
python3 gen_scale.py
echo

########################  PART 1: microbenchmark  ##############################
hr; echo "PART 1  —  cast cost on the real BarrierSet hierarchy"; hr
for V in rtti nortti; do
  [ $V = rtti ] && F="-frtti" || F="-fno-rtti"
  $CXX $BENCHFLAGS $F -c barrierset.cpp -o bs_$V.o     || exit 1
  $CXX $BENCHFLAGS $F -c bench.cpp      -o bench_$V.o  || exit 1
  $CXX bs_$V.o bench_$V.o -o bench_$V                   || exit 1
done
echo "--- product build, -frtti ---";    $PIN ./bench_rtti
echo
echo "--- product build, -fno-rtti ---"; $PIN ./bench_nortti
echo

########################  PART 2: size / relocations  ##########################
hr; echo "PART 2  —  size & relocations at scale (1800 polymorphic classes)"; hr
for V in rtti nortti; do
  [ $V = rtti ] && F="-frtti" || F="-fno-rtti -fno-exceptions"
  rm -f obj_$V/*.o; mkdir -p obj_$V
  T0=$(date +%s.%N)
  echo scale_*.cpp scale_factory.cpp | tr ' ' '\n' | \
    xargs -P $J -I{} sh -c "$CXX -O2 -DNDEBUG -fPIC -fvisibility=hidden $F -c {} -o obj_$V/\$(basename {} .cpp).o"
  $CXX -shared obj_$V/*.o -o libscale_$V.so || exit 1
  T1=$(date +%s.%N)
  echo "$V build wall time: $(echo "$T1 - $T0" | bc) s"
done
echo
printf "%-26s %14s %14s %10s\n" "metric" "-frtti" "-fno-rtti" "delta"
hr
metric() {  # $1=label  $2=cmd
  a=$(eval "${2//LIB/libscale_rtti.so}"); b=$(eval "${2//LIB/libscale_nortti.so}")
  d=$(( a - b )); p=$(awk "BEGIN{printf \"%.1f\", ($d*100.0)/$a}")
  printf "%-26s %14s %14s %10s\n" "$1" "$a" "$b" "-$d (-$p%)"
}
metric "file size (bytes)"        'stat -c %s LIB'
metric ".rela.dyn entries"        'readelf -rW LIB | grep -c "^[0-9a-f]\{16\}"'
metric ".rodata (bytes)"          'readelf -SW LIB | awk "/ \.rodata /{print strtonum(\"0x\" \$7)}"'
metric ".data.rel.ro (bytes)"     'readelf -SW LIB | awk "/ \.data\.rel\.ro /{print strtonum(\"0x\" \$7)}"'
metric "_ZTV vtable symbols"      'nm -a LIB | grep -c " _ZTV"'
metric "_ZTI typeinfo symbols"    'nm -a LIB | grep -c " _ZTI"'
metric "_ZTS typename symbols"    'nm -a LIB | grep -c " _ZTS"'
echo

########################  PART 3: load time / dirty pages  #####################
hr; echo "PART 3  —  dynamic load cost (relocation processing) & dirty pages"; hr
$CC -O2 -o loadbench loadbench.c -ldl || exit 1
$PIN ./loadbench ./libscale_rtti.so   400
echo
$PIN ./loadbench ./libscale_nortti.so 400
