#include "base_only.hpp"
#include <typeinfo>
#include <cstdio>
struct D2 : Base { void f() override {} };  // derives from an -fno-rtti base, compiled WITH rtti
int main() { D2 d; printf("%s\n", typeid(d).name()); }
