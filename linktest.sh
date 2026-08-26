#!/bin/bash
cd "$(dirname "$0")"

# Override to taste:  CXX=g++-13 PIN="taskset -c 7" ./run.sh
CXX=${CXX:-g++}
CC=${CC:-gcc}
PIN=${PIN:-}
$CXX -O1 -fno-rtti -c bb.cpp -o bb.o
$CXX -O1 -frtti    -c dd.cpp -o dd.o
echo "### Linking an -frtti-compiled derived class against an -fno-rtti base:"
$CXX bb.o dd.o -o mm 2>&1 | c++filt | head -8
echo "linker exit = ${PIPESTATUS[0]}"
