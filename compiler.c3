module compiler;

import std::io;
import std::core::string;

import scanner;
import vm;

// Both parses and generates bytecode (single-pass)
fn bool compile(char[] src, Chunk* chunk) {
	scanner::Scanner scnr;
	scnr.init(src);
	Parser p = {.scnr = scnr, .compiling_chunk = chunk};

	p.advance();
	p.expression();
	p.consume(TokenType.EOF, "expect end of expression.");
	p.emit_instruction(RETURN);

	return p.had_error;
}

struct Parser {
	scanner::Scanner scnr;
	Token            current;
	Token            previous;
	bool             had_error;
	bool             panic_mode; // suppresses additional errs til cleared at end of stmt
	Chunk*           compiling_chunk;
}

fn void Parser.expression(&self) {}

fn void Parser.number(&self) {
	String s = self.scnr.lexeme(self.previous);
	double! val = s.to_float();
	if (catch val) {
		val = 0;
	}
	if (catch err = self.emit_constant(val)) {
		self.error(string::tformat("%s", err));
	}

}

// === advancing ===

fn void Parser.advance(&self) {
	self.previous = self.current;
	while (true) {
		self.current = self.scnr.token();
		if (self.current.type != ERROR) break;
		self.error_at_current(self.scnr.lexeme(self.current));
	}
}
fn void Parser.consume(&self, TokenType token_type, String err_msg) {
	if (self.current.type == token_type) {
		self.advance();
		return;
	}
	self.error_at_current(err_msg);
}

// === error handling ===

fn void Parser.error_at_current(&self, String msg) {
	self.error_at(&self.current, msg);
}
fn void Parser.error(&self, String msg) {
	self.error_at(&self.previous, msg);
}
fn void Parser.error_at(&self, Token* token, String msg) {
	if (self.panic_mode) return;
	self.panic_mode = true;

	// TODO better way to handle this? Don't want to print this deep.
	// Instead could return an error message through `compile` instead of just a bool
	io::eprintf("[line %d] Error", token.line);

	if (token.type == EOF) {
		io::eprint(" at end");
	} else if (token.type == ERROR) {
		// nothing
	} else {
		io::eprintf(" at %.*s", token.length, token.start);
	}
	io::eprintfn(": %s", msg);
	self.had_error = true;
}

// === emit to chunk ===

fn Chunk* Parser.current_chunk(&self) {
	return self.compiling_chunk;
}
fn void Parser.emit_byte(&self, char byte) {
	self.current_chunk().write(byte, self.previous.line);
}
fn void Parser.emit_instruction(&self, OpCode opcode, char... bytes) {
	self.current_chunk().write_instruction(opcode, self.previous.line, ...bytes);
}
fn void! Parser.emit_constant(&self, Value value) {
	return self.current_chunk().write_constant(value, self.previous.line);
}
