#include <typeinfo>
struct Base { virtual ~Base(); virtual void f(); };
struct Derived : Base { void f() override; };
const char* name(Base* b)    { return typeid(*b).name(); }   // polymorphic typeid
const char* sname()          { return typeid(Base).name(); } // static typeid
Derived*    down(Base* b)    { return dynamic_cast<Derived*>(b); }
