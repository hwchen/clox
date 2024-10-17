module compiler;

import std::io;

import scanner;
import vm;

// Both parses and generates bytecode (single-pass)
fn bool compile(char[] src, Chunk* chunk) {
	scanner::Scanner scnr;
	scnr.init(src);
	Parser p = {.scnr = scnr};

	p.advance();
	p.expression();
	p.consume(TokenType.EOF, "expect end of expression.");

	return p.had_error;
}

struct Parser {
	scanner::Scanner scnr;
	Token            current;
	Token            previous;
	bool             had_error;
	bool             panic_mode; // suppresses additional errs til cleared at end of stmt
}

fn void Parser.advance(&self) {}
fn void Parser.expression(&self) {}
fn void Parser.consume(&self, TokenType token_type, String err_msg) {
	if (self.current.type == token_type) {
		self.advance();
		return;
	}
	self.error_at_current(err_msg);
}
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
