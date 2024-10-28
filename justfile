check *args="":
    c3c compile . -C {{args}}

build *args="":
    c3c compile . {{args}}

# `-D DEBUG_TRACE_EXECUTION` prints execution in vm
# `-D DEBUG_PRINT_CODE` prints compiled code
run *args="":
    c3c compile-run . {{args}}

valgrind:
    c3c compile . && valgrind ./clox
