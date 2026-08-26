#include <typeinfo>
struct Plain { int x; };
struct Base { virtual ~Base(); };
const char* a() { return typeid(Plain).name(); }  // non-polymorphic type
const char* b() { return typeid(Base).name(); }   // polymorphic TYPE (not object)
