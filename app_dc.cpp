#include "iface.hpp"
#include <cstdio>
// Base and Derived have out-of-line virtuals defined in lib.cpp, so their typeinfo
// would live there. Built -fno-rtti, it does not exist, and this fails to link.
int main() {
  Base* p = make();
  printf("dynamic_cast = %p\n", (void*)dynamic_cast<Derived*>(p));
  return 0;
}
