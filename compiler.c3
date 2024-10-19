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

	$if $feature(DEBUG_PRINT_CODE):
		p.current_chunk().disassemble("code");
	$endif

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

fn void Parser.expression(&p) {
	p.parse_precedence(ASSIGNMENT);
}
fn void Parser.number(&p) {
	String s = p.scnr.lexeme(p.previous);
	double val = s.to_float() ?? 0;
	if (catch err = p.emit_constant(val)) {
		p.error(string::tformat("%s", err));
	}
}
fn void Parser.grouping(&p) {
	p.expression();
	p.consume(RIGHT_PAREN, "Expect ')' after expression");
}
fn void Parser.unary(&p) {
	TokenType op_type = p.previous.type;
	// Note order of parsing, negation should be above operand on stack
	p.parse_precedence(UNARY);
	switch (op_type) {
		case MINUS: p.emit_instruction(NEGATE);
		default: $$unreachable();
	}
}
fn void Parser.binary(&p) {
	TokenType op_type = p.previous.type;
	// Note order of parsing, negation should be above operand on stack
	ParseRule* rule = p.get_rule(op_type);
	p.parse_precedence(rule.precedence + 1);
	switch (op_type) {
		case PLUS:  p.emit_instruction(ADD);
		case MINUS: p.emit_instruction(SUBTRACT);
		case STAR:  p.emit_instruction(MULTIPLY);
		case SLASH: p.emit_instruction(DIVIDE);
		default: $$unreachable();
	}
}
fn void Parser.parse_precedence(&p, Precedence precedence) {
	p.advance();
	ParseFn prefix_rule = p.get_rule(p.previous.type).prefix;
	if (prefix_rule == null) {
		p.error("expect expression");
		return;
	}
	prefix_rule(p);
	while (precedence <= p.get_rule(p.current.type).precedence) {
		p.advance();
		ParseFn infix_rule = p.get_rule(p.previous.type).infix;
		infix_rule(p);
	}
}
fn ParseRule* Parser.get_rule(&p, TokenType token_type) {
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

fn void Parser.advance(&p) {
	p.previous = p.current;
	while (true) {
		p.current = p.scnr.token();
		if (p.current.type != ERROR) break;
		p.error_at_current(p.scnr.lexeme(p.current));
	}
}
fn void Parser.consume(&p, TokenType token_type, String err_msg) {
	if (p.current.type == token_type) {
		p.advance();
		return;
	}
	p.error_at_current(err_msg);
}

// === error handling ===

fn void Parser.error_at_current(&p, String msg) {
	p.error_at(&p.current, msg);
}
fn void Parser.error(&p, String msg) {
	p.error_at(&p.previous, msg);
}
fn void Parser.error_at(&p, Token* token, String msg) {
	if (p.panic_mode) return;
	p.panic_mode = true;

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
	p.had_error = true;
}

// === emit to chunk ===

fn Chunk* Parser.current_chunk(&p) {
	return p.compiling_chunk;
}
fn void Parser.emit_byte(&p, char byte) {
	p.current_chunk().write(byte, p.previous.line);
}
fn void Parser.emit_instruction(&p, OpCode opcode, char... bytes) {
	p.current_chunk().write_instruction(opcode, p.previous.line, ...bytes);
}
fn void! Parser.emit_constant(&p, Value value) {
	return p.current_chunk().write_constant(value, p.previous.line);
}
