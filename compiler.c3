module compiler;

import std::io;

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
	p.end_compiler();

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

// === emit bytes ===

fn Chunk* Parser.current_chunk(&self) {
	return self.compiling_chunk;
}
fn void Parser.emit_byte(&self, char byte) {
	self.current_chunk().write(byte, self.previous.line);
}
fn void Parser.emit_bytes(&self, char byte1, char byte2) {
	self.emit_byte(byte1);
	self.emit_byte(byte2);
}
fn void Parser.emit_return(&self) {
	self.emit_byte((char)OpCode.RETURN);
}
fn void Parser.end_compiler(&self) {
	self.emit_return();
}
