module vm;

import std::io;
import std::collections::list;

import chunk;

struct Vm {
	// not a pointer; book says pointers are faster, but it's not clear that's the case now.
	// https://stackoverflow.com/questions/2305770/efficiency-arrays-vs-pointers
	int           ip;
	List(<Value>) stack;
}

fn void! Vm.interpret(&vm, Chunk* chunk) {
	if (chunk.code.len() == 0) return;
	vm.ip = 0;

	while(true) {
		$if $feature(DEBUG_TRACE_EXECUTION):
			io::printf("     ");
			foreach (v : vm.stack) {
				io::printf("[ %f ]", v);
			}
			io::printn();
			instruction_disassemble(chunk, vm.ip);
		$endif

		OpCode opcode = (OpCode)chunk.code[vm.ip];
		vm.ip += 1; // TODO: should this defer?
		switch (opcode) {
			case CONSTANT:
				int const_idx = chunk.code[vm.ip];
				Value constant = chunk.constants[const_idx];
				vm.ip += 1;
				vm.stack.push(constant);
			case NEGATE:
				Value constant = vm.stack.pop()!;
				vm.stack.push(-1 * constant);
			case ADD:
			case SUBTRACT:
			case MULTIPLY:
			case DIVIDE:
				Value b = vm.stack.pop()!;
				Value a = vm.stack.pop()!;
				switch (opcode) {
					case ADD:      vm.stack.push(a + b);
					case SUBTRACT: vm.stack.push(a - b);
					case MULTIPLY: vm.stack.push(a * b);
					case DIVIDE:   vm.stack.push(a / b);
					default: $$unreachable();
				}
			case RETURN:
				Value constant = vm.stack.pop()!;
				io::printfn("%f", constant);
				return;
		}
	}
}
