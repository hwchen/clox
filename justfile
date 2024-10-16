run:
    c3c compile-run .

run-trace:
    c3c compile-run . -D DEBUG_TRACE_EXECUTION

valgrind:
    c3c compile . && valgrind ./clox
