module vm;

import std::io;
import std::collections::list;

import chunk;
import value;

struct Vm {
	Chunk*        chunk;
	// not a pointer; book says pointers are faster, but it's not clear that's the case now.
	// https://stackoverflow.com/questions/2305770/efficiency-arrays-vs-pointers
	int           ip;
	List(<Value>) stack;
}

fn void! Vm.interpret(&vm, Chunk* chnk) {
	if (chnk.code.len() == 0) return;
	vm.chunk = chnk;
	vm.ip = 0;

	while(true) {
		$if $feature(DEBUG_TRACE_EXECUTION):
			io::printf("     ");
			foreach (v : vm.stack) {
				io::printf("[ %f ]", v);
			}
			io::printn();
			instruction_disassemble(vm.chunk, vm.ip);
		$endif

		OpCode opcode = (OpCode)vm.chunk.code[vm.ip];
		vm.ip += 1; // TODO: should this defer?
		switch (opcode) {
			case CONSTANT:
				int const_idx = vm.chunk.code[vm.ip];
				Value constant = vm.chunk.constants[const_idx];
				vm.ip += 1;
				vm.stack.push(constant);
			case NIL:
				vm.stack.push(value::nil());
			case TRUE:
				vm.stack.push(value::from_bool(true));
			case FALSE:
				vm.stack.push(value::from_bool(false));
			case NEGATE:
				// check before pop, in case garbage collector triggered during op
				if (!vm.stack[^1].is_number()) {
					vm.runtime_error("Operand must be a number.");
					return VmError.RUNTIME_ERROR?;
				}
				Value constant = vm.stack.pop()!;
				double x = constant.as_number()!;
				vm.stack.push(value::from_number(-1 * x));
			case ADD:
			case SUBTRACT:
			case MULTIPLY:
			case DIVIDE:
				// check before pop, in case garbage collector triggered during op
				if (!vm.stack[^1].is_number() || !vm.stack[^2].is_number()) {
					vm.runtime_error("Operand must be a number.");
					return VmError.RUNTIME_ERROR?;
				}
				Value vb = vm.stack.pop()!;
				Value va = vm.stack.pop()!;
				double b = vb.as_number()!;
				double a = va.as_number()!;
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

fn void Vm.runtime_error(&vm, String format, any... args) {
	io::eprintfn(format, ...args);
	// TODO double check this is right
	io::eprintfn("[line %d] in script", vm.chunk.lines[vm.ip]);
	vm.stack.clear();
}

fault VmError {
	RUNTIME_ERROR,
}
