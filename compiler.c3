module compiler;

import std::io;

import scanner;
import vm;

// Both parses and generates bytecode (single-pass)
fn void! compile(char[] src, Chunk* chunk) {
	scanner::Scanner scnr;
	scnr.init(src);
	Parser p = {.scnr = scnr};

	p.advance();
	p.expression();
	p.consume(TokenType.EOF, "expect end of expression.");

	return;
}

struct Parser {
	scanner::Scanner scnr;
	Token            current;
	Token            previous;
}

fn void Parser.advance(&self) {}
fn void Parser.expression(&self) {}
fn void Parser.consume(&self, TokenType token_type, String err_msg) {}
