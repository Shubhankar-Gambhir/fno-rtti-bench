#!/bin/bash
# Which RTTI-adjacent constructs each compiler accepts under a given flag.
#
#   COMPILERS="g++-9 g++-15 clang++" FLAGS=-fno-rtti ./constructs.sh
#
# Prints "ok" if the construct compiles, "error" if it does not, "warn" if it
# compiles with a diagnostic.
set -u
cd "$(dirname "$0")"
FLAGS=${FLAGS:--fno-rtti}
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT

H='#include <typeinfo>
struct Plain { int x; };
struct Base { virtual ~Base(); };
struct Derived : Base {};
struct Other { virtual ~Other(); };
struct Both : Base, Other {};
void g();'

declare -A SRC=(
  [typeid_obj]='const std::type_info& f(Base* b) { return typeid(*b); }'
  [typeid_type]='const std::type_info& f() { return typeid(Base); }'
  [typeid_plain]='const std::type_info& f() { return typeid(Plain); }'
  [dc_down]='Derived* f(Base* b) { return dynamic_cast<Derived*>(b); }'
  [dc_cross]='Other* f(Base* b) { return dynamic_cast<Other*>(b); }'
  [dc_void]='void* f(Base* b) { return dynamic_cast<void*>(b); }'
  [dc_up]='Base* f(Derived* d) { return dynamic_cast<Base*>(d); }'
  [catch]='int f() { try { g(); } catch (Base&) { return 1; } return 0; }'
  [any_type]='#include <any>
const std::type_info& f(std::any& a) { return a.type(); }'
  [any_cast]='#include <any>
int f(std::any& a) { return std::any_cast<int>(a); }'
  [fn_target]='#include <functional>
void (*const* f(std::function<void()>& fn))() { return fn.target<void(*)()>(); }'
)
ORDER="typeid_obj typeid_type typeid_plain dc_down dc_cross dc_void dc_up catch any_type any_cast fn_target"

printf "%-22s" "compiler ($FLAGS)"; for k in $ORDER; do printf "%13s" "$k"; done; echo
for C in ${COMPILERS:-g++}; do
  if $C --version | grep -q clang; then ver="Clang $($C -dumpversion)"; else ver="GCC $($C -dumpfullversion)"; fi
  printf "%-22s" "$ver"
  for k in $ORDER; do
    printf '%s\n%s\n' "$H" "${SRC[$k]}" > "$D/$k.cpp"
    if $C -std=c++17 $FLAGS -c "$D/$k.cpp" -o "$D/$k.o" 2> "$D/$k.err"; then
      [ -s "$D/$k.err" ] && r=warn || r=ok
    else r=error; fi
    printf "%13s" "$r"
  done
  echo
done
