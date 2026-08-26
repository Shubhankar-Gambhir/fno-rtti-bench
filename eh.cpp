#include <cstdio>
struct MyErr { int code; };
struct Sub : MyErr {};
void thrower() { throw Sub{42}; }
int main() {
  try { thrower(); }
  catch (const MyErr& e) { printf("caught by BASE, code=%d\n", e.code); }
  return 0;
}
