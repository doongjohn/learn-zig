#if defined(HELLO_STATIC)
  #define HELLO_API
  #define HELLO_INTERNAL
#elif defined(_WIN32) || defined(__CYGWIN__)
  #ifdef HELLO_SHARED
    #ifdef __GNUC__
      #define HELLO_API __attribute__((dllexport))
    #else
      #define HELLO_API __declspec(dllexport)
    #endif
  #else
    #ifdef __GNUC__
      #define HELLO_API __attribute__((dllimport))
    #else
      #define HELLO_API __declspec(dllimport)
    #endif
  #endif
  // Symbols are hidden by default on Windows.
  #define HELLO_INTERNAL
#else
  #define HELLO_API __attribute__((visibility("default")))
  #define HELLO_INTERNAL __attribute__((visibility("hidden")))
#endif
