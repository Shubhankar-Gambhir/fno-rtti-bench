struct Base { virtual ~Base(); virtual void f(); };
struct Derived : Base { void f() override; };
Base::~Base() {} void Base::f() {}
void Derived::f() {}
Base* make() { return new Derived(); }
