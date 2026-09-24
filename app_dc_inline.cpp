#include "inline.hpp"
#include <cstdio>
int main() {
  Base* p = make();
  printf("about to dynamic_cast...\n"); fflush(stdout);
  printf("dynamic_cast = %p\n", (void*)dynamic_cast<Derived*>(p));
  return 0;
}
