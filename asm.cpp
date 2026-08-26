#include "barrierset.hpp"

// What HotSpot actually compiles in a product build:
CardTableBarrierSet* via_fake_rtti(BarrierSet* bs) {
  return barrier_set_cast<CardTableBarrierSet>(bs);
}

// The checked form, used where the type is genuinely unknown:
CardTableBarrierSet* via_is_a(BarrierSet* bs) {
  return bs->is_a(BarrierSet::CardTableBarrierSet)
       ? static_cast<CardTableBarrierSet*>(bs) : nullptr;
}

#ifdef __GXX_RTTI
CardTableBarrierSet* via_dynamic_cast(BarrierSet* bs) {
  return dynamic_cast<CardTableBarrierSet*>(bs);
}
#endif
