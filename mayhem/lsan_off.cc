// Leak detection is off for every fuzz target (build time, not runtime); ASan and UBSan stay on.
extern "C" int __lsan_is_turned_off() { return 1; }
