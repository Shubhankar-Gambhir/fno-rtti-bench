#!/bin/bash
# Count vtables vs typeinfos in a shipped libjvm.so to show that HotSpot is built
# -fno-rtti, and list whatever typeinfo survived (which is always exception machinery).
#
#   ./jvm_probe.sh                  # uses $JAVA_HOME, else `which java`
#   ./jvm_probe.sh /path/to/jdk     # or point it at any JDK you have
set -u

JDK=${1:-${JAVA_HOME:-}}
if [ -z "$JDK" ]; then
  J=$(command -v java) || { echo "no java found; pass a JDK path" >&2; exit 2; }
  JDK=$(dirname "$(dirname "$(readlink -f "$J")")")
fi

LIBJVM=$(find "$JDK" -name libjvm.so -path '*server*' 2>/dev/null | head -1)
[ -n "$LIBJVM" ] || LIBJVM=$(find "$JDK" -name libjvm.so 2>/dev/null | head -1)
[ -n "$LIBJVM" ] || { echo "no libjvm.so under $JDK" >&2; exit 1; }

"$JDK/bin/java" -version 2>&1 | head -3
echo
printf '%-22s %s\n' "libjvm.so" "$LIBJVM"
printf '%-22s %s bytes\n' "size" "$(stat -c %s "$LIBJVM")"

ztv=$(nm -a "$LIBJVM" 2>/dev/null | grep -c ' _ZTV')
zti=$(nm -a "$LIBJVM" 2>/dev/null | grep -c ' _ZTI')
printf '%-22s %s\n' "_ZTV (vtables)"   "$ztv"
printf '%-22s %s\n' "_ZTI (typeinfo)"  "$zti"
[ "$zti" -gt 0 ] && printf '%-22s %s:1\n' "ratio" "$((ztv / zti))"
printf '%-22s %s\n' ".rela.dyn entries" "$(readelf -rW "$LIBJVM" | grep -c '^[0-9a-f]\{16\}')"

echo
echo "surviving typeinfo (all of it should be exception machinery):"
nm -a "$LIBJVM" 2>/dev/null | grep ' _ZTI' | c++filt | sed 's/.*typeinfo/  typeinfo/'

echo
echo "the same JDK's other native libraries, for contrast:"
printf '  %-24s %8s %8s\n' "library" "_ZTV" "_ZTI"
for so in $(find "$JDK/lib" -maxdepth 2 -name '*.so' 2>/dev/null | sort); do
  v=$(nm -a "$so" 2>/dev/null | grep -c ' _ZTV')
  i=$(nm -a "$so" 2>/dev/null | grep -c ' _ZTI')
  [ "$v" -gt 0 ] || [ "$i" -gt 0 ] && printf '  %-24s %8s %8s\n' "$(basename "$so")" "$v" "$i"
done
