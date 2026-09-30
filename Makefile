# Reproduction harness for "The Null Slot: What -fno-rtti Removes, Costs, and Buys".
#
#   make abi      what the flag does to the ABI, and what it rejects
#   make mixing   the two failure modes for mixing -frtti and -fno-rtti objects
#   make casts    cast-cost microbenchmark on a BarrierSet-shaped hierarchy
#   make asm      the three downcast forms, disassembled
#   make scale    1800-class corpus: size, relocations, load time, dirty pages
#   make jvm      probe a real libjvm.so (JDK=/path/to/jdk, else $JAVA_HOME)
#   make compilers    the cast benchmark across compilers and C++ runtimes
#   make constructs   which RTTI-adjacent constructs each compiler accepts
#   make future       Clang's omit-vtable-rtti and relative vtables on the corpus
#   make all      everything
#
# Override the toolchain or pinning:
#   make casts CXX=g++-13 PIN="taskset -c 7"
#   make compilers COMPILERS="g++-11 g++-13 clang++ clang++@libc++"
#   make future CLANG=clang++-22

CXX ?= g++
CC  ?= gcc
PIN ?=
JDK ?= $(JAVA_HOME)

COMPILERS ?= $(CXX)
CLANG ?= clang++

export CXX CC PIN COMPILERS

.PHONY: all abi mixing casts asm scale jvm compilers constructs future clean

all: abi mixing casts asm scale jvm compilers constructs future

abi:
	@echo "=== typeinfo symbols emitted, with and without RTTI ==="
	$(CXX) -O2           -c poly.cpp -o poly_rtti.o
	$(CXX) -O2 -fno-rtti -c poly.cpp -o poly_nortti.o
	@echo "--- WITH RTTI ---";    nm -C poly_rtti.o   | grep -iE 'typeinfo|vtable' | sort
	@echo "--- WITHOUT RTTI ---"; nm -C poly_nortti.o | grep -iE 'typeinfo|vtable' | sort
	@echo
	@echo "=== the vtable is the same size either way; one relocation goes missing ==="
	@readelf -SW poly_rtti.o   | grep _ZTV4Base
	@readelf -SW poly_nortti.o | grep _ZTV4Base
	@readelf -rW poly_rtti.o   | grep -A5 'rela.data.rel.ro.local._ZTV4Base'
	@readelf -rW poly_nortti.o | grep -A4 'rela.data.rel.ro.local._ZTV4Base'
	@echo
	@echo "=== what -fno-rtti rejects (expect three errors) ==="
	-$(CXX) -fno-rtti -O2 -c uses.cpp -o /dev/null
	@echo "=== ... and what it still allows: an upcast ==="
	$(CXX) -fno-rtti -O2 -c upcast.cpp -o /dev/null && echo "upcast compiled clean"
	@echo
	@echo "=== exceptions keep working AND keep emitting typeinfo ==="
	$(CXX) -fno-rtti -O2 -c eh.cpp -o eh.o
	@nm -C eh.o | grep -i typeinfo | sort
	$(CXX) -fno-rtti -O2 eh.cpp -o eh && ./eh

mixing:
	@echo "=== Direction A: -frtti derived class, -fno-rtti base -> loud link error ==="
	-bash linktest.sh
	@echo
	@echo "=== Direction B: -frtti caller, -fno-rtti vtable -> links clean, then dies ==="
	$(CXX) -O1 -fno-rtti -c lib.cpp -o lib_nortti.o
	$(CXX) -O1 -frtti    -c app.cpp -o app_rtti.o
	$(CXX) lib_nortti.o app_rtti.o -o app_n && echo "link: clean, no diagnostic"
	-@./app_n; echo "(exit $$? -- 139 is SIGSEGV in type_info::name() on a null typeinfo)"
	@echo
	@echo "=== Direction B via dynamic_cast, class with an out-of-line virtual -> link error ==="
	$(CXX) -O1 -frtti -c app_dc.cpp -o app_dc.o
	-$(CXX) lib_nortti.o app_dc.o -o app_dc
	@echo
	@echo "=== Direction B via dynamic_cast, all-inline virtuals -> links clean, then dies ==="
	$(CXX) -O1 -fno-rtti -c lib_inline.cpp -o lib_inline.o
	$(CXX) -O1 -frtti    -c app_dc_inline.cpp -o app_dc_inline.o
	$(CXX) lib_inline.o app_dc_inline.o -o app_dc_inline && echo "link: clean, no diagnostic"
	-@./app_dc_inline; echo "(exit $$? -- 139 is SIGSEGV inside __dynamic_cast on a null typeinfo)"

casts:
	bash run.sh

asm:
	bash asm.sh

scale:
	bash scale.sh

jvm:
	bash jvm_probe.sh $(JDK)

compilers:
	bash compilers.sh

constructs:
	FLAGS=-fno-rtti bash constructs.sh
	@echo
	FLAGS=-frtti bash constructs.sh

future:
	CXX=$(CLANG) bash future.sh

clean:
	rm -f *.o *.so eh app_n app_dc app_dc_inline mm bench_rtti bench_nortti loadbench
	rm -rf obj_rtti obj_nortti obj_nortti_noexc obj_t obj_f_*
	rm -f cc_bs_* cc_bench_* cc_out_*
	rm -f scale.hpp scale_*.cpp
