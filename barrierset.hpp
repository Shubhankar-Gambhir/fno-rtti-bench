// Standalone reproduction of HotSpot's BarrierSet fake-RTTI scheme.
// Faithful to src/hotspot/share/utilities/fakeRttiSupport.hpp and
//              src/hotspot/share/gc/shared/barrierSet.hpp
#pragma once
#include <stdint.h>
#include <assert.h>

typedef uintptr_t uintx;

template<typename T, typename TagType>
class FakeRttiSupport {
public:
  explicit FakeRttiSupport(TagType concrete_tag)
    : _tag_set(tag_bit(concrete_tag)), _concrete_tag(concrete_tag) {}
  FakeRttiSupport(TagType concrete_tag, uintx tag_set)
    : _tag_set(tag_set), _concrete_tag(concrete_tag) {}

  TagType concrete_tag() const { return _concrete_tag; }
  bool    has_tag(TagType tag) const { return (_tag_set & tag_bit(tag)) != 0; }

  FakeRttiSupport add_tag(TagType tag) const {
    uintx tbit = tag_bit(tag);
    assert((_tag_set & tbit) == 0 && "tag already present");
    return FakeRttiSupport(_concrete_tag, _tag_set | tbit);
  }
private:
  uintx   _tag_set;
  TagType _concrete_tag;
  static uintx tag_bit(TagType tag) { return ((uintx)1) << tag; }
};

class BarrierSet {
public:
  enum Name { ModRef, CardTableBarrierSet, G1BarrierSet, ZBarrierSet,
              ShenandoahBarrierSet, EpsilonBarrierSet, UnknownBS };
protected:
  typedef FakeRttiSupport<BarrierSet, Name> FakeRtti;
private:
  FakeRtti _fake_rtti;
public:
  template<typename T> struct GetName;

  Name kind() const { return _fake_rtti.concrete_tag(); }
  bool is_a(Name bsn) const { return _fake_rtti.has_tag(bsn); }

  virtual ~BarrierSet();                        // key function -> vtable lands in .cpp
  virtual int  write_ref_field_work(void* p);
  virtual const char* name() const;
protected:
  explicit BarrierSet(const FakeRtti& r) : _fake_rtti(r) {}
};

// HotSpot's checked downcast: an assert (compiled out with NDEBUG) + static_cast.
template<typename T>
inline T* barrier_set_cast(BarrierSet* bs) {
  assert(bs->is_a(BarrierSet::GetName<T>::value) && "wrong type of barrier set");
  return static_cast<T*>(bs);
}

class ModRefBarrierSet : public BarrierSet {
protected:
  explicit ModRefBarrierSet(const FakeRtti& r) : BarrierSet(r.add_tag(BarrierSet::ModRef)) {}
public:
  ~ModRefBarrierSet() override;
  int  write_ref_field_work(void* p) override;
  const char* name() const override;
};

class CardTableBarrierSet : public ModRefBarrierSet {
  int _card_shift;
protected:
  explicit CardTableBarrierSet(const FakeRtti& r)
    : ModRefBarrierSet(r.add_tag(BarrierSet::CardTableBarrierSet)), _card_shift(9) {}
public:
  CardTableBarrierSet();
  ~CardTableBarrierSet() override;
  int  write_ref_field_work(void* p) override;
  const char* name() const override;
  int  card_shift() const { return _card_shift; }
};

class G1BarrierSet : public CardTableBarrierSet {
public:
  G1BarrierSet();
  ~G1BarrierSet() override;
  int  write_ref_field_work(void* p) override;
  const char* name() const override;
};

class ZBarrierSet : public BarrierSet {
public:
  ZBarrierSet();
  ~ZBarrierSet() override;
  int  write_ref_field_work(void* p) override;
  const char* name() const override;
};

class ShenandoahBarrierSet : public BarrierSet {
public:
  ShenandoahBarrierSet();
  ~ShenandoahBarrierSet() override;
  int  write_ref_field_work(void* p) override;
  const char* name() const override;
};

class EpsilonBarrierSet : public BarrierSet {
public:
  EpsilonBarrierSet();
  ~EpsilonBarrierSet() override;
  int  write_ref_field_work(void* p) override;
  const char* name() const override;
};

// GetName specialisations (HotSpot generates these via FOR_EACH_BARRIER_SET_DO)
template<> struct BarrierSet::GetName<ModRefBarrierSet>
  { static const BarrierSet::Name value = BarrierSet::ModRef; };
template<> struct BarrierSet::GetName<CardTableBarrierSet>
  { static const BarrierSet::Name value = BarrierSet::CardTableBarrierSet; };
template<> struct BarrierSet::GetName<G1BarrierSet>
  { static const BarrierSet::Name value = BarrierSet::G1BarrierSet; };
template<> struct BarrierSet::GetName<ZBarrierSet>
  { static const BarrierSet::Name value = BarrierSet::ZBarrierSet; };
template<> struct BarrierSet::GetName<ShenandoahBarrierSet>
  { static const BarrierSet::Name value = BarrierSet::ShenandoahBarrierSet; };
template<> struct BarrierSet::GetName<EpsilonBarrierSet>
  { static const BarrierSet::Name value = BarrierSet::EpsilonBarrierSet; };

// opaque accessors (defined in barrierset.cpp, never inlined) so the optimiser
// cannot statically know the dynamic type
BarrierSet*  the_barrier_set();
void         set_barrier_set(BarrierSet*);
BarrierSet*  make_barrier_set(int which);
