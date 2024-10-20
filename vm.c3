module vm;

import std::io;
import std::collections::list;

import chunk;
import value;

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
				double x = value::as_number(constant)!;
				vm.stack.push(value::from_number(-1 * x));
			case ADD:
			case SUBTRACT:
			case MULTIPLY:
			case DIVIDE:
				Value vb = vm.stack.pop()!;
				Value va = vm.stack.pop()!;
				double b = value::as_number(vb)!;
				double a = value::as_number(va)!;
				switch (opcode) {
					case ADD:      vm.stack.push(value::from_number(a + b));
					case SUBTRACT: vm.stack.push(value::from_number(a - b));
					case MULTIPLY: vm.stack.push(value::from_number(a * b));
					case DIVIDE:   vm.stack.push(value::from_number(a / b));
					default: $$unreachable();
				}
			case RETURN:
				Value constant = vm.stack.pop()!;
				constant.print();
				io::printn();
				return;
		}
	}
}
