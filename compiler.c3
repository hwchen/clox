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

fn void Parser.expression(&self) {
	self.parse_precedence(ASSIGNMENT);
}
fn void Parser.number(&self) {
	String s = self.scnr.lexeme(self.previous);
	double val = s.to_float() ?? 0;
	if (catch err = self.emit_constant(val)) {
		self.error(string::tformat("%s", err));
	}
}
fn void Parser.grouping(&self) {
	self.expression();
	self.consume(RIGHT_PAREN, "Expect ')' after expression");
}
fn void Parser.unary(&self) {
	TokenType op_type = self.previous.type;
	// Note order of parsing, negation should be above operand on stack
	self.parse_precedence(UNARY);
	switch (op_type) {
		case MINUS: self.emit_instruction(NEGATE);
		default: $$unreachable();
	}
}
fn void Parser.binary(&self) {
	TokenType op_type = self.previous.type;
	// Note order of parsing, negation should be above operand on stack
	ParseRule* rule = self.get_rule(op_type);
	self.parse_precedence(rule.precedence + 1);
	switch (op_type) {
		case PLUS:  self.emit_instruction(ADD);
		case MINUS: self.emit_instruction(SUBTRACT);
		case STAR:  self.emit_instruction(MULTIPLY);
		case SLASH: self.emit_instruction(DIVIDE);
		default: $$unreachable();
	}
}
fn void Parser.parse_precedence(&self, Precedence precedence) {
	self.advance();
	ParseFn prefix_rule = self.get_rule(self.previous.type).prefix;
	if (prefix_rule == null) {
		self.error("expect expression");
	}
	prefix_rule(self);
	while (precedence <= self.get_rule(self.current.type).precedence) {
		self.advance();
		ParseFn infix_rule = self.get_rule(self.previous.type).infix;
		infix_rule(self);
	}
}
fn ParseRule* Parser.get_rule(&self, TokenType token_type) {
	return &rules[token_type];
}
struct ParseRule {
	ParseFn prefix;
	ParseFn infix;
	Precedence precedence;
}
def ParseFn = fn void(Parser*);
enum Precedence {
	NONE,
	ASSIGNMENT,  // =
	OR,          // or
	AND,         // and
	EQUALITY,    // == !=
	COMPARISON,  // < > <= >=
	TERM,        // + -
	FACTOR,      // * /
	UNARY,       // ! -
	CALL,        // . ()
	PRIMARY,
}
ParseRule[] rules = {
	{&Parser.grouping, null,           NONE},   //[LEFT_PAREN]
	{null,             null,           NONE},   //[RIGHT_PAREN]
	{null,             null,           NONE},   //[LEFT_BRACE]
	{null,             null,           NONE},   //[RIGHT_BRACE]
	{null,             null,           NONE},   //[COMMA]
	{null,             null,           NONE},   //[DOT]
	{&Parser.unary,    &Parser.binary, TERM},   //[MINUS]
	{null,             &Parser.binary, TERM},   //[PLUS]
	{null,             null,           NONE},   //[SEMICOLON]
	{null,             &Parser.binary, FACTOR}, //[SLASH]
	{null,             &Parser.binary, FACTOR}, //[STAR]
	{null,             null,           NONE},   //[BANG]
	{null,             null,           NONE},   //[BANG_EQUAL]
	{null,             null,           NONE},   //[EQUAL]
	{null,             null,           NONE},   //[EQUAL_EQUAL]
	{null,             null,           NONE},   //[GREATER]
	{null,             null,           NONE},   //[GREATER_EQUAL]
	{null,             null,           NONE},   //[LESS]
	{null,             null,           NONE},   //[LESS_EQUAL]
	{null,             null,           NONE},   //[IDENTIFIER]
	{null,             null,           NONE},   //[STRING]
	{&Parser.number,   null,           NONE},   //[NUMBER]
	{null,             null,           NONE},   //[AND]
	{null,             null,           NONE},   //[CLASS]
	{null,             null,           NONE},   //[ELSE]
	{null,             null,           NONE},   //[FALSE]
	{null,             null,           NONE},   //[FOR]
	{null,             null,           NONE},   //[FUN]
	{null,             null,           NONE},   //[IF]
	{null,             null,           NONE},   //[NIL]
	{null,             null,           NONE},   //[OR]
	{null,             null,           NONE},   //[PRINT]
	{null,             null,           NONE},   //[RETURN
	{null,             null,           NONE},   //[SUPER]
	{null,             null,           NONE},   //[THIS]
	{null,             null,           NONE},   //[TRUE]
	{null,             null,           NONE},   //[VAR]
	{null,             null,           NONE},   //[WHILE]
	{null,             null,           NONE},   //[ERROR]
	{null,             null,           NONE},   //[EOF]
};

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
