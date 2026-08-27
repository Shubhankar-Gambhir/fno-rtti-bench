# fno-rtti-bench

Reproduction harness for **[The Null Slot: What `-fno-rtti` Actually Removes](https://shubhankar-gambhir.github.io/posts/the-null-slot-what-fno-rtti-actually-removes/)**.

`-fno-rtti` is usually described as "it disables `dynamic_cast` and `typeid`". That is
true and it hides most of what the flag does. This repo measures the rest: what happens
to the vtable, what the flag still lets you write, what it costs to add RTTI back, and
what OpenJDK uses instead of `dynamic_cast`.

## Running it

Everything is plain GCC, GNU make, binutils, and Python 3. No dependencies.

```bash
make abi      # what the flag does to the ABI, and what it rejects
make mixing   # the two failure modes for mixing -frtti and -fno-rtti objects
make casts    # cast-cost microbenchmark on a BarrierSet-shaped hierarchy
make asm      # the three downcast forms, disassembled
make scale    # 1800-class corpus: size, relocations, load time, dirty pages
make jvm      # probe a real libjvm.so
make all
```

Override the toolchain or CPU pinning:

```bash
make casts CXX=g++-13 PIN="taskset -c 7"
make jvm   JDK=/path/to/any/jdk
```

`make casts` defaults to `-march=native`. The published numbers used
`-march=skylake-avx512` on a Xeon Gold 6130; retarget as needed. The alignment flags in
`BENCHFLAGS` were measured to make no difference to this benchmark and are kept only for
consistency with the rest of the blog series.

## What each target shows

**`make abi`** compiles the same two-class hierarchy both ways. Without RTTI the
`typeinfo` and `typeinfo name` symbols vanish, along with the undefined references to
libsupc++'s `__class_type_info` vtables. The vtable itself stays exactly `0x28` bytes and
loses exactly one relocation, the one pointing at `_ZTI4Base`. The slot is not reclaimed,
it goes null. The target then shows the three constructs GCC rejects, the upcast it still
accepts, and the fact that `throw`/`catch` keeps working *and* keeps emitting typeinfo.

**`make mixing`** demonstrates both directions. An `-frtti` class deriving from an
`-fno-rtti` base is a link error, which is the case the GCC manual documents. An `-frtti`
caller doing `typeid` on an object whose vtable came from an `-fno-rtti` TU links with no
diagnostic at all and then segfaults on the null slot. That one is not documented.

**`make casts`** builds a faithful reduction of HotSpot's `BarrierSet` hierarchy and its
`FakeRttiSupport` bitmask, then times `barrier_set_cast`, an explicit `is_a()` check, and
`dynamic_cast` against each other. Note that the sub-3ns rows quantize to whole CPU cycles
and are not separable from loop overhead; the `dynamic_cast` rows are the meaningful ones.

**`make scale`** clones the `BarrierSet` shape 300 times into 1800 polymorphic classes and
builds it three ways: `-frtti`, `-fno-rtti`, and `-fno-rtti -fno-exceptions`. Separating
the two flags is the point. `-fno-rtti` does nothing for `.gcc_except_table` or compile
time; `-fno-exceptions` does nothing for `_ZTS`, `_ZTI`, or relocations.

**`make jvm`** counts `_ZTV` against `_ZTI` in a shipped `libjvm.so`, lists whatever
typeinfo survived, and does the same for the JDK's other native libraries. On a stock
OpenJDK 17 build, `libjvm.so` has thousands of vtables and about ten typeinfos, all of
them libsupc++ internals, while `libjimage.so` carries typeinfo for its own classes. The
flag is scoped to the JVM, and you can see that in the shipped bits without any source.

## Files

| file | what it is |
|---|---|
| `poly.cpp` | two-class hierarchy, compiled both ways for the symbol and vtable diff |
| `uses.cpp`, `upcast.cpp`, `statictypeid.cpp` | the constructs `-fno-rtti` does and does not reject |
| `eh.cpp` | exceptions still work, and still emit typeinfo |
| `bb.cpp`, `dd.cpp`, `linktest.sh` | mixing direction A: the link error |
| `iface.hpp`, `lib.cpp`, `app.cpp` | mixing direction B: the silent runtime crash |
| `barrierset.{hpp,cpp}` | HotSpot's `BarrierSet` + `FakeRttiSupport`, reduced but faithful |
| `bench.cpp` | the cast microbenchmark |
| `asm.cpp`, `asm.sh` | the three downcast forms, for disassembly |
| `gen_scale.py` | generates the 1800-class corpus |
| `scale.sh` | the three-way build and the size/relocation table |
| `loadbench.c` | `dlopen` timing and private-dirty page accounting |
| `jvm_probe.sh` | vtable/typeinfo census of any JDK you point it at |

## References

- [GCC C++ Dialect Options](https://gcc.gnu.org/onlinedocs/gcc/C_002b_002b-Dialect-Options.html)
- [LLVM Coding Standards: Do not use RTTI or Exceptions](https://llvm.org/docs/CodingStandards.html#do-not-use-rtti-or-exceptions)
- [How to set up LLVM-style RTTI for your class hierarchy](https://llvm.org/docs/HowToSetUpLLVMStyleRTTI.html)
- OpenJDK [`make/autoconf/flags-cflags.m4`](https://github.com/openjdk/jdk17u/blob/master/make/autoconf/flags-cflags.m4) -- where `-fno-rtti` is scoped to `libjvm.so`
- OpenJDK [`barrierSet.hpp`](https://github.com/openjdk/jdk17u/blob/master/src/hotspot/share/gc/shared/barrierSet.hpp), [`fakeRttiSupport.hpp`](https://github.com/openjdk/jdk17u/blob/master/src/hotspot/share/utilities/fakeRttiSupport.hpp)
