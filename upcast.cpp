struct Base { virtual ~Base(); };
struct Derived : Base {};
Base* up(Derived* d) { return dynamic_cast<Base*>(d); }
