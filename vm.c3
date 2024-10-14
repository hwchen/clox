module vm;

import std::io;
import std::collections::list;

struct Vm {
	// not a pointer; book says pointers are faster, but it's not clear that's the case now.
	// https://stackoverflow.com/questions/2305770/efficiency-arrays-vs-pointers
	int           ip;
	List(<Value>) stack;
}

fault InterpretError {
	COMPILER_ERROR,
	RUNTIME_ERROR,
}

fn void! Vm.interpret(&vm, Chunk chunk) {
	if (chunk.code.len() == 0) return;

	while(true) {
		$if $feature(DEBUG_TRACE_EXECUTION):
			io::printf("     ");
			foreach (v : vm.stack) {
				io::printf("[ %v ]", v);
			}
			io::printn();
			instruction_disassemble(chunk, vm.ip);
		$endif

		OpCode opcode = (OpCode)chunk.code[vm.ip];
		vm.ip += 1;
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
					case ADD:
						vm.stack.push(a + b);
					case SUBTRACT:
						vm.stack.push(a - b);
					case MULTIPLY:
						vm.stack.push(a * b);
					case DIVIDE:
						vm.stack.push(a / b);
					default:
						$$unreachable();
				}
			case RETURN:
				Value constant = vm.stack.pop()!;
				io::printfn("%v", constant);
				return;
		}
	}
}

enum OpCode : char {
	CONSTANT,
	NEGATE,
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	RETURN,
}

distinct Value = double;

struct Chunk {
	List(<char>)  code;
	// All constant values stored in the list, to simplify things
	List(<Value>) constants;
	List(<int>)   lines;
}

fn void Chunk.write(&self, char byte, int line) {
	self.code.push(byte);
	self.lines.push(line);
}

fn void Chunk.write_constant(&self, Value v, int line) {
	int const_idx = self.add_constant((Value)v);
	self.write((char)OpCode.CONSTANT, line);
	self.write((char)const_idx, line);
}

fn int Chunk.add_constant(&self, Value value) {
	self.constants.push(value);
	return (char)self.constants.len() - 1;
}

fn void Chunk.disassemble(&self, String label) {
	io::printfn("== %s ==", label);
	int offset = 0;
	while (offset < self.code.len()) {
		offset = instruction_disassemble(self, offset);
	}
}

fn int instruction_disassemble(Chunk* chunk, int offset) {
	io::printf("%04d ", offset);

	// don't show line if previous instruction has the same line num
	if (offset > 0 && chunk.lines[offset] == chunk.lines[(usz)offset - 1]) {
		io::printf("   | ");
	} else {
		io::printf("%4d ", chunk.lines[offset]);
	}

	OpCode opcode = (OpCode)chunk.code[offset];
	switch (opcode) {
		case CONSTANT:
			int const_idx = chunk.code[(usz)offset + 1];
			Value const_val = chunk.constants[const_idx];
			io::printfn("%-16s %4d '%v'", opcode, const_idx, const_val);
			return offset + 2;
		case NEGATE:
		case ADD:
		case SUBTRACT:
		case MULTIPLY:
		case DIVIDE:
		case RETURN:
			io::printfn("%s", opcode);
			return offset + 1;
		default:
			io::printfn("Unknown opcode %d", opcode);
			return offset + 1;
	}
}
