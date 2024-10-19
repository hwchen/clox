run:
    c3c compile-run .

run-trace:
    c3c compile-run . -D DEBUG_TRACE_EXECUTION

run-chunk:
    c3c compile-run . -D DEBUG_PRINT_CODE

valgrind:
    c3c compile . && valgrind ./clox
