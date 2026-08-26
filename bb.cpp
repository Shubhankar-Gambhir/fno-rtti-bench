#include "base_only.hpp"
Base::~Base() {} void Base::f() {}   // key function -> vtable+typeinfo emitted here
