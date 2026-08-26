#include "barrierset.hpp"
#include <stdio.h>
#include <time.h>
#include <stdlib.h>

static double now_ns() { struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);
                         return t.tv_sec*1e9 + t.tv_nsec; }

static const long ITERS = 30000000L;
static const long WARM  =  2000000L;
static const int  POP   = 4096;
static BarrierSet* pop_[POP];
static volatile uintptr_t sink;

// asm barrier stops the optimiser hoisting a loop-invariant cast out of the loop
#define OPAQUE(p) asm volatile("" : "+r"(p))

#define TIME_ONE(label, EXPR)                                                  \
  do {                                                                         \
    BarrierSet* bs = the_barrier_set();                                        \
    uintptr_t acc = 0;                                                         \
    for (long i=0;i<WARM ;i++){ OPAQUE(bs); acc += (uintptr_t)(EXPR); }        \
    double t0 = now_ns();                                                      \
    for (long i=0;i<ITERS;i++){ OPAQUE(bs); acc += (uintptr_t)(EXPR); }        \
    double t1 = now_ns(); sink += acc;                                         \
    printf("  %-44s %8.2f ns/op\n", label, (t1-t0)/(double)ITERS);             \
  } while (0)

#define TIME_POP(label, EXPR)                                                  \
  do {                                                                         \
    uintptr_t acc = 0;                                                         \
    long reps = ITERS / POP;                                                   \
    for (long r=0;r<WARM/POP;r++) for (int k=0;k<POP;k++){                     \
        BarrierSet* bs = pop_[k]; OPAQUE(bs); acc += (uintptr_t)(EXPR); }      \
    double t0 = now_ns();                                                      \
    for (long r=0;r<reps;r++) for (int k=0;k<POP;k++){                         \
        BarrierSet* bs = pop_[k]; OPAQUE(bs); acc += (uintptr_t)(EXPR); }      \
    double t1 = now_ns(); sink += acc;                                         \
    printf("  %-44s %8.2f ns/op\n", label, (t1-t0)/(double)(reps*POP));        \
  } while (0)

int main() {
  set_barrier_set(make_barrier_set(0));           // G1BarrierSet, as in a default JVM
  for (int k=0;k<POP;k++) pop_[k] = make_barrier_set(k);

  printf("compiled with RTTI : %s\n",
#ifdef __GXX_RTTI
         "yes");
#else
         "no  (-fno-rtti)");
#endif
  printf("asserts            : %s\n",
#ifdef NDEBUG
         "off (product / NDEBUG)");
#else
         "on  (debug)");
#endif
  printf("BarrierSet object size: %zu bytes  (vptr + FakeRtti{tag_set, concrete_tag})\n\n",
         sizeof(G1BarrierSet));

  printf("[A] single global BarrierSet (dynamic type G1BarrierSet)"
         " -- the real HotSpot hot path\n");
  TIME_ONE("baseline (no cast, just the pointer)",  bs);
  TIME_ONE("virtual call  bs->write_ref_field_work()", bs->write_ref_field_work(0));
  TIME_ONE("FakeRtti  barrier_set_cast<CardTableBS>", barrier_set_cast<CardTableBarrierSet>(bs));
  TIME_ONE("FakeRtti  bs->is_a(CardTableBarrierSet)",
           (bs->is_a(BarrierSet::CardTableBarrierSet) ? static_cast<CardTableBarrierSet*>(bs) : (CardTableBarrierSet*)0));
#ifdef __GXX_RTTI
  TIME_ONE("dynamic_cast<CardTableBarrierSet*>  HIT", dynamic_cast<CardTableBarrierSet*>(bs));
  TIME_ONE("dynamic_cast<G1BarrierSet*>         HIT", dynamic_cast<G1BarrierSet*>(bs));
  TIME_ONE("dynamic_cast<ZBarrierSet*>         MISS", dynamic_cast<ZBarrierSet*>(bs));
#else
  printf("  %-44s      n/a (compile error under -fno-rtti)\n", "dynamic_cast<...>");
#endif

  printf("\n[B] mixed population of all 5 barrier set types (worst case)\n");
  TIME_POP("FakeRtti  bs->is_a(CardTableBarrierSet)",
           (bs->is_a(BarrierSet::CardTableBarrierSet) ? static_cast<CardTableBarrierSet*>(bs) : (CardTableBarrierSet*)0));
#ifdef __GXX_RTTI
  TIME_POP("dynamic_cast<CardTableBarrierSet*>", dynamic_cast<CardTableBarrierSet*>(bs));
  TIME_POP("dynamic_cast<ZBarrierSet*>", dynamic_cast<ZBarrierSet*>(bs));
#endif
  return (int)(sink & 0);
}
