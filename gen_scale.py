#!/usr/bin/env python3
"""Clone the BarrierSet hierarchy shape N times so the size/relocation impact of
   RTTI is measurable at a scale comparable to a real libjvm.so."""
import os
N_FAM   = 300      # families; each family = 7 classes -> 2100 polymorphic classes
N_FILES = 20
OUT = os.path.dirname(os.path.abspath(__file__))

# same shape as the real thing: BS -> ModRef -> CardTable -> G1, plus 3 siblings
SHAPE = [("ModRefBarrierSet",       "BarrierSetBase"),
         ("CardTableBarrierSet",    "ModRefBarrierSet"),
         ("G1BarrierSet",           "CardTableBarrierSet"),
         ("ZBarrierSet",            "BarrierSetBase"),
         ("ShenandoahBarrierSet",   "BarrierSetBase"),
         ("EpsilonBarrierSet",      "BarrierSetBase")]

h = ["#pragma once\n", "namespace hotspot { namespace gc { namespace shared {\n"]
h.append("""
class BarrierSetBase {
public:
  explicit BarrierSetBase(unsigned tags) : _tag_set(tags) {}
  virtual ~BarrierSetBase();
  virtual int         write_ref_field_work(void* p);
  virtual int         write_ref_array_work(void* p, int n);
  virtual const char* name() const;
  bool is_a(unsigned t) const { return (_tag_set & (1u << t)) != 0; }
protected:
  unsigned _tag_set;
};
""")
for f in range(N_FAM):
    for (cls, base) in SHAPE:
        b = base if base != "BarrierSetBase" else "BarrierSetBase"
        b = b if base == "BarrierSetBase" else "%s_%03d" % (base, f)
        h.append(f"""
class {cls}_{f:03d} : public {b} {{
public:
  {cls}_{f:03d}();
  ~{cls}_{f:03d}() override;
  int         write_ref_field_work(void* p) override;
  int         write_ref_array_work(void* p, int n) override;
  const char* name() const override;
}};""")
h.append("\n\n}}}\n")
h.append("""
#define HS_EXPORT __attribute__((visibility("default")))
extern "C" {
  HS_EXPORT void* hs_make_barrier_set(int i);
  HS_EXPORT int   hs_have_rtti(void);
}
""")
open(os.path.join(OUT, "scale.hpp"), "w").write("".join(h))

per = (N_FAM + N_FILES - 1) // N_FILES
for fi in range(N_FILES):
    lo, hi = fi*per, min((fi+1)*per, N_FAM)
    s = ['#include "scale.hpp"\n', "namespace hotspot { namespace gc { namespace shared {\n"]
    if fi == 0:
        s.append("""
BarrierSetBase::~BarrierSetBase() {}
int         BarrierSetBase::write_ref_field_work(void*)      { return 0; }
int         BarrierSetBase::write_ref_array_work(void*, int) { return 0; }
const char* BarrierSetBase::name() const { return "BarrierSetBase"; }
""")
    for f in range(lo, hi):
        for ci, (cls, base) in enumerate(SHAPE):
            b = "BarrierSetBase" if base == "BarrierSetBase" else "%s_%03d" % (base, f)
            binit = "BarrierSetBase(%du)" % (ci+1) if base == "BarrierSetBase" \
                    else "%s_%03d()" % (base, f)
            s.append(f"""
{cls}_{f:03d}::{cls}_{f:03d}() : {binit} {{}}
{cls}_{f:03d}::~{cls}_{f:03d}() {{}}
int         {cls}_{f:03d}::write_ref_field_work(void*)      {{ return {ci}; }}
int         {cls}_{f:03d}::write_ref_array_work(void*, int) {{ return {ci}; }}
const char* {cls}_{f:03d}::name() const {{ return "{cls}_{f:03d}"; }}""")
    s.append("\n\n}}}\n")
    open(os.path.join(OUT, "scale_%02d.cpp" % fi), "w").write("".join(s))

fac = ['#include "scale.hpp"\n', "using namespace hotspot::gc::shared;\n",
       'extern "C" HS_EXPORT int hs_have_rtti(void) {\n#ifdef __GXX_RTTI\n  return 1;\n'
       '#else\n  return 0;\n#endif\n}\n',
       'extern "C" HS_EXPORT void* hs_make_barrier_set(int i) {\n  switch (i %% %d) {\n' % (N_FAM*len(SHAPE))]
n = 0
for f in range(N_FAM):
    for (cls, _b) in SHAPE:
        fac.append("    case %d: return new %s_%03d();\n" % (n, cls, f)); n += 1
fac.append("  }\n  return 0;\n}\n")
open(os.path.join(OUT, "scale_factory.cpp"), "w").write("".join(fac))
print("generated %d families x %d = %d polymorphic classes across %d files"
      % (N_FAM, len(SHAPE), N_FAM*len(SHAPE), N_FILES+1))
