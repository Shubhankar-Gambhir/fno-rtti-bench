// Every virtual is inline, so there is no key function: whichever TU needs the
// typeinfo emits it. The -frtti side supplies it and the link succeeds.
struct Base { virtual ~Base() {} virtual int f() { return 1; } };
struct Derived : Base { int f() override { return 2; } };
Base* make();
