# Reproduction harness for "The Null Slot: What -fno-rtti Actually Removes".
#
#   make abi      what the flag does to the ABI, and what it rejects
#   make mixing   the two failure modes for mixing -frtti and -fno-rtti objects
#   make casts    cast-cost microbenchmark on a BarrierSet-shaped hierarchy
#   make asm      the three downcast forms, disassembled
#   make scale    1800-class corpus: size, relocations, load time, dirty pages
#   make jvm      probe a real libjvm.so (JDK=/path/to/jdk, else $JAVA_HOME)
#   make all      everything
#
# Override the toolchain or pinning:
#   make casts CXX=g++-13 PIN="taskset -c 7"

CXX ?= g++
CC  ?= gcc
PIN ?=
JDK ?= $(JAVA_HOME)

export CXX CC PIN

.PHONY: all abi mixing casts asm scale jvm clean

all: abi mixing casts asm scale jvm

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
	-@./app_n; echo "(exit $$? -- 139 is SIGSEGV inside __dynamic_cast on a null typeinfo)"

casts:
	bash run.sh

asm:
	bash asm.sh

scale:
	bash scale.sh

jvm:
	bash jvm_probe.sh $(JDK)

clean:
	rm -f *.o *.so eh app_n mm bench_rtti bench_nortti loadbench
	rm -rf obj_rtti obj_nortti obj_nortti_noexc obj_t
	rm -f scale.hpp scale_*.cpp
