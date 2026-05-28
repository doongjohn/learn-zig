#include <hello.h>
#include <stdio.h>

HELLO_API void say_hello(void)
{
  puts("hello");
}

HELLO_INTERNAL void say_hello_hidden(void)
{
  puts("hello hidden");
}
