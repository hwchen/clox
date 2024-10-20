module chunk;

import std::io;
import std::collections::list;

import value;

enum OpCode : char {
	CONSTANT,
	NIL,
	TRUE,
	FALSE,
	NEGATE,
	ADD,
	SUBTRACT,
	MULTIPLY,
	DIVIDE,
	RETURN,
}

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

fn void Chunk.write_instruction(&self, OpCode opcode, int line, char... bytes) {
	self.write((char)opcode, line);
	foreach (byte : bytes) {
		self.write(byte, line);
	}
}

// Writes constant instruction (with idx to constant), as well as the constant itself.
// Just like write_instruction, but needs to also check that possible number of constants
// addressable by one byte is not exceeded.
fn void! Chunk.write_constant(&self, Value v, int line) {
	self.constants.push(v);
	usz const_idx = self.constants.len() - 1;
	if (const_idx > char.max) {
		return ChunkError.TOO_MANY_CONSTANTS?;
	}
	self.write_instruction(CONSTANT, line, (char)const_idx);
}

fault ChunkError {
	TOO_MANY_CONSTANTS,
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
			io::printf("%-16s %4d '", opcode, const_idx);
			const_val.print();
			io::printn("'");
			return offset + 2;
		case NIL:
		case TRUE:
		case FALSE:
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
