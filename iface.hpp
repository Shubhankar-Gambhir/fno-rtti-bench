struct Base { virtual ~Base(); virtual void f(); };
struct Derived : Base { void f() override; ~Derived() override; };
Base* make();
