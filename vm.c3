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
				io::printf("[ ");
				v.print();
				io::printf(" ]");
			}
			io::printn();
			chunk::instruction_disassemble(vm.chunk, vm.ip);
		$endif

		OpCode opcode = (OpCode)vm.chunk.code[vm.ip];
		vm.ip += 1;
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
			case NOT:
				Value constant = vm.stack.pop()!;
				vm.stack.push(value::from_bool(constant.is_falsey()));
			case NEGATE:
				// check before pop, in case garbage collector triggered during op
				if (!vm.stack[^1].is_number()) {
					vm.runtime_error("Operand must be a number.");
					return VmError.RUNTIME_ERROR?;
				}
				Value constant = vm.stack.pop()!;
				double x = constant.number;
				vm.stack.push(value::from_number(-1 * x));
			case EQUAL:
				// unlike other binary ops, doesn't check before popping?
				Value b = vm.stack.pop()!;
				Value a = vm.stack.pop()!;
				vm.stack.push(value::from_bool(a.equals(b)));
			case GREATER:  vm.@binary_op(value::from_bool, gt)!;
			case LESS:     vm.@binary_op(value::from_bool, lt)!;
			case ADD:      vm.@binary_op(value::from_number, add)!;
			case SUBTRACT: vm.@binary_op(value::from_number, sub)!;
			case MULTIPLY: vm.@binary_op(value::from_number, mul)!;
			case DIVIDE:   vm.@binary_op(value::from_number, div)!;
			case RETURN:
				Value constant = vm.stack.pop()!;
				constant.print();
				io::printn();
				return;
		}
	}
}
macro void! Vm.@binary_op(&vm, #from_value, #binary_fn) {
	// check before pop, in case garbage collector triggered during op
	if (!vm.stack[^1].is_number() || !vm.stack[^2].is_number()) {
		vm.runtime_error("Operand must be a number.");
		return VmError.RUNTIME_ERROR?;
	}
	Value vb = vm.stack.pop()!;
	Value va = vm.stack.pop()!;
	double b = vb.number;
	double a = va.number;
	vm.stack.push(#from_value(#binary_fn(a, b)));
}
// These functions are for passing into macro, as we can't pass operators directly
fn double add(double a, double b) { return a + b; }
fn double sub(double a, double b) { return a - b; }
fn double mul(double a, double b) { return a * b; }
fn double div(double a, double b) { return a / b; }
fn bool gt(double a, double b) { return a < b; }
fn bool lt(double a, double b) { return a < b; }

fn void Vm.runtime_error(&vm, String format, any... args) {
	io::eprintfn(format, ...args);
	// TODO double check this is right
	io::eprintfn("[line %d] in script", vm.chunk.lines[vm.ip]);
	vm.stack.clear();
}

fault VmError {
	RUNTIME_ERROR,
}
