#include "iface.hpp"
#include <typeinfo>
#include <cstdio>
int main() {
  Base* p = make();
  printf("vptr[1] (typeinfo slot) = %p\n", ((void***)p)[0][-1]);
  printf("about to call typeid...\n"); fflush(stdout);
  printf("typeid = %s\n", typeid(*p).name());
  return 0;
}
