#include "barrierset.hpp"

BarrierSet::~BarrierSet() {}
int         BarrierSet::write_ref_field_work(void*) { return 0; }
const char* BarrierSet::name() const { return "BarrierSet"; }

ModRefBarrierSet::~ModRefBarrierSet() {}
int         ModRefBarrierSet::write_ref_field_work(void*) { return 1; }
const char* ModRefBarrierSet::name() const { return "ModRefBarrierSet"; }

CardTableBarrierSet::CardTableBarrierSet()
  : ModRefBarrierSet(FakeRtti(BarrierSet::CardTableBarrierSet)), _card_shift(9) {}
CardTableBarrierSet::~CardTableBarrierSet() {}
int         CardTableBarrierSet::write_ref_field_work(void*) { return 2; }
const char* CardTableBarrierSet::name() const { return "CardTableBarrierSet"; }

G1BarrierSet::G1BarrierSet() : CardTableBarrierSet(FakeRtti(BarrierSet::G1BarrierSet)) {}
G1BarrierSet::~G1BarrierSet() {}
int         G1BarrierSet::write_ref_field_work(void*) { return 3; }
const char* G1BarrierSet::name() const { return "G1BarrierSet"; }

ZBarrierSet::ZBarrierSet() : BarrierSet(FakeRtti(BarrierSet::ZBarrierSet)) {}
ZBarrierSet::~ZBarrierSet() {}
int         ZBarrierSet::write_ref_field_work(void*) { return 4; }
const char* ZBarrierSet::name() const { return "ZBarrierSet"; }

ShenandoahBarrierSet::ShenandoahBarrierSet() : BarrierSet(FakeRtti(BarrierSet::ShenandoahBarrierSet)) {}
ShenandoahBarrierSet::~ShenandoahBarrierSet() {}
int         ShenandoahBarrierSet::write_ref_field_work(void*) { return 5; }
const char* ShenandoahBarrierSet::name() const { return "ShenandoahBarrierSet"; }

EpsilonBarrierSet::EpsilonBarrierSet() : BarrierSet(FakeRtti(BarrierSet::EpsilonBarrierSet)) {}
EpsilonBarrierSet::~EpsilonBarrierSet() {}
int         EpsilonBarrierSet::write_ref_field_work(void*) { return 6; }
const char* EpsilonBarrierSet::name() const { return "EpsilonBarrierSet"; }

static BarrierSet* _the_bs = 0;

__attribute__((noinline)) BarrierSet* the_barrier_set()      { return _the_bs; }
__attribute__((noinline)) void        set_barrier_set(BarrierSet* b) { _the_bs = b; }

__attribute__((noinline)) BarrierSet* make_barrier_set(int which) {
  switch (which % 5) {
    case 0: return new G1BarrierSet();
    case 1: return new CardTableBarrierSet();
    case 2: return new ZBarrierSet();
    case 3: return new ShenandoahBarrierSet();
    default: return new EpsilonBarrierSet();
  }
}
