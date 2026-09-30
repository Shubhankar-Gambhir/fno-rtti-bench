#!/bin/bash
# The cast microbenchmark across compilers and C++ runtimes, median of RUNS runs.
#
#   COMPILERS="g++-9 g++-13 clang++ clang++@libc++" ./compilers.sh
#
# Each entry is a C++ compiler command with optional suffixes:
#   @libc++   build with -stdlib=libc++ (dynamic_cast then runs libc++abi's __dynamic_cast)
#   @static   link statically (a newer toolchain on an older glibc)
# LDFLAGS is passed to every link. The default, -static-libstdc++, matters: dynamic_cast
# is a call into the runtime library, and a dynamically linked binary runs whichever
# libstdc++.so.6 the loader finds, which is often newer than the compiler that built it.
set -u
cd "$(dirname "$0")"
PIN=${PIN:-}
RUNS=${RUNS:-5}
LDFLAGS=${LDFLAGS--static-libstdc++}
BENCHFLAGS=${BENCHFLAGS:--std=c++17 -O2 -march=native -fcf-protection -falign-functions=64 -falign-loops=64 -DNDEBUG}

ROWS=("virtual call" "bs->is_a(CardTableBarrierSet)" "dynamic_cast<G1BarrierSet*>" \
      "dynamic_cast<CardTableBarrierSet*>  HIT" "dynamic_cast<ZBarrierSet*>         MISS")
HDRS=("virtual" "is_a" "dc exact" "dc base" "dc miss")

printf "%-34s" "compiler"; for h in "${HDRS[@]}"; do printf "%10s" "$h"; done; echo
for C in ${COMPILERS:-g++}; do
  cxx=${C%%@*}; lib=""; ld=""
  case "$C" in *@libc++*) lib="-stdlib=libc++"
    # a static libc++ does not pull in libc++abi, which is where __dynamic_cast lives
    case "$LDFLAGS" in *-static-libstdc++*) ld="-Wl,-Bstatic -lc++abi -Wl,-Bdynamic";; esac;; esac
  case "$C" in *@static*) ld="-static";; esac
  tag=$(echo "$C" | tr -c 'a-zA-Z0-9\n' '_')
  $cxx $BENCHFLAGS $lib -frtti -c barrierset.cpp -o cc_bs_$tag.o   || exit 1
  $cxx $BENCHFLAGS $lib -frtti -c bench.cpp      -o cc_bench_$tag.o || exit 1
  $cxx $lib $LDFLAGS cc_bs_$tag.o cc_bench_$tag.o $ld -o cc_bench_$tag || exit 1
  for r in $(seq 1 $RUNS); do $PIN ./cc_bench_$tag; done > cc_out_$tag.txt
  if $cxx --version | grep -q clang; then ver="Clang $($cxx -dumpversion)"; else ver="GCC $($cxx -dumpfullversion)"; fi
  [ -n "$lib" ] && ver="$ver, libc++" || ver="$ver, libstdc++"
  printf "%-34s" "$ver"
  for row in "${ROWS[@]}"; do
    # section [A] only (single dynamic type); median across runs
    awk '/^\[A\]/{a=1;next} /^\[B\]/{a=0} a' cc_out_$tag.txt | grep -F -- "$row" \
      | awk '{print $(NF-1)}' | sort -g | awk '{a[NR]=$1} END{printf "%10.2f", a[int((NR+1)/2)]}'
  done
  echo
done
