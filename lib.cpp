#include "iface.hpp"
Base::~Base() {}      void Base::f() {}       // key function -> vtable emitted HERE
Derived::~Derived() {} void Derived::f() {}   // key function -> vtable emitted HERE
Base* make() { return new Derived(); }
