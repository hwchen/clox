module compiler;

import std::io;

import chunk;
import object;
import scanner;
import value;

// Both parses and generates bytecode (single-pass)
fn bool compile(char[] src, Chunk* chunk) {
	scanner::Scanner scanner;
	scanner.init(src);
	Parser p = {.scanner = scanner, .compiling_chunk = chunk};

	p.advance();
	while (!p.match(EOF)) {
		p.declaration();
	}

	$if $feature(DEBUG_PRINT_CODE):
		p.current_chunk().disassemble("code");
	$endif

	return p.had_error;
}

struct Parser {
	scanner::Scanner scanner;
	Token            current;
	Token            previous;
	bool             had_error;
	bool             panic_mode; // suppresses additional errs til cleared at end of stmt
	Chunk*           compiling_chunk;
}

fn void Parser.declaration(&p) {
	p.statement();
	if (p.panic_mode) p.synchronize();
}
fn void Parser.statement(&p) {
	if (p.match(PRINT)) {
		p.print_statement();
	} else {
		p.expression_statement();
	}
}
fn void Parser.print_statement(&p) {
	p.expression();
	p.consume(SEMICOLON, "expected ';' after expression");
	p.emit_ops(PRINT);
}
fn void Parser.expression_statement(&p) {
	p.expression();
	p.consume(SEMICOLON, "expected ';' after expression");
	p.emit_ops(POP);
}
fn void Parser.expression(&p) {
	p.parse_precedence(ASSIGNMENT);
}
fn void Parser.number(&p) {
	String s = p.scanner.lexeme(p.previous);
	double val = s.to_float() ?? 0;
	if (catch err = p.emit_constant(value::from_number(val))) {
		p.error(string::tformat("%s", err));
	}
}
// Allocates, think about strategy in the future.
fn void Parser.string(&p) {
	String s= p.scanner.lexeme(p.previous);
	ZString chars = s[1:^2].zstr_copy(); // trims quotes
	ObjString* obj_s = mem::new(ObjString);
	obj_s.obj.type = STRING;
	obj_s.length = p.previous.length - 2;
	obj_s.chars = chars;
	Value v = value::from_obj((Obj*)obj_s);
	if (catch err = p.emit_constant(v)) {
		p.error(string::tformat("%s", err));
	}
}
fn void Parser.literal(&p) {
	switch (p.previous.type) {
		case FALSE: p.emit_ops(FALSE);
		case NIL:   p.emit_ops(NIL);
		case TRUE:  p.emit_ops(TRUE);
		default: $$unreachable();
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
		case BANG:  p.emit_ops(NOT);
		case MINUS: p.emit_ops(NEGATE);
		default: $$unreachable();
	}
}
fn void Parser.binary(&p) {
	TokenType op_type = p.previous.type;
	// Note order of parsing, negation should be above operand on stack
	ParseRule* rule = p.get_rule(op_type);
	p.parse_precedence(rule.precedence + 1);
	switch (op_type) {
		case BANG_EQUAL:    p.emit_ops(EQUAL, NOT);
		case EQUAL_EQUAL:   p.emit_ops(EQUAL);
		case GREATER:       p.emit_ops(GREATER);
		case GREATER_EQUAL: p.emit_ops(LESS, NOT);
		case LESS:          p.emit_ops(LESS);
		case LESS_EQUAL:    p.emit_ops(GREATER, NOT);
		case PLUS:          p.emit_ops(ADD);
		case MINUS:         p.emit_ops(SUBTRACT);
		case STAR:          p.emit_ops(MULTIPLY);
		case SLASH:         p.emit_ops(DIVIDE);
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
	[TokenType.LEFT_PAREN]    = {&Parser.grouping, null,           NONE},
	[TokenType.RIGHT_PAREN]   = {null,             null,           NONE},
	[TokenType.LEFT_BRACE]    = {null,             null,           NONE},
	[TokenType.RIGHT_BRACE]   = {null,             null,           NONE},
	[TokenType.COMMA]         = {null,             null,           NONE},
	[TokenType.DOT]           = {null,             null,           NONE},
	[TokenType.MINUS]         = {&Parser.unary,    &Parser.binary, TERM},
	[TokenType.PLUS]          = {null,             &Parser.binary, TERM},
	[TokenType.SEMICOLON]     = {null,             null,           NONE},
	[TokenType.SLASH]         = {null,             &Parser.binary, FACTOR},
	[TokenType.STAR]          = {null,             &Parser.binary, FACTOR},
	[TokenType.BANG]          = {&Parser.unary,    null,           NONE},
	[TokenType.BANG_EQUAL]    = {null,             &Parser.binary, EQUALITY},
	[TokenType.EQUAL]         = {null,             null,           NONE},
	[TokenType.EQUAL_EQUAL]   = {null,             &Parser.binary, EQUALITY},
	[TokenType.GREATER]       = {null,             &Parser.binary, COMPARISON},
	[TokenType.GREATER_EQUAL] = {null,             &Parser.binary, COMPARISON},
	[TokenType.LESS]          = {null,             &Parser.binary, COMPARISON},
	[TokenType.LESS_EQUAL]    = {null,             &Parser.binary, COMPARISON},
	[TokenType.IDENTIFIER]    = {null,             null,           NONE},
	[TokenType.STRING]        = {&Parser.string,   null,           NONE},
	[TokenType.NUMBER]        = {&Parser.number,   null,           NONE},
	[TokenType.AND]           = {null,             null,           NONE},
	[TokenType.CLASS]         = {null,             null,           NONE},
	[TokenType.ELSE]          = {null,             null,           NONE},
	[TokenType.FALSE]         = {&Parser.literal,  null,           NONE},
	[TokenType.FOR]           = {null,             null,           NONE},
	[TokenType.FUN]           = {null,             null,           NONE},
	[TokenType.IF]            = {null,             null,           NONE},
	[TokenType.NIL]           = {&Parser.literal,  null,           NONE},
	[TokenType.OR]            = {null,             null,           NONE},
	[TokenType.PRINT]         = {null,             null,           NONE},
	[TokenType.RETURN]        = {null,             null,           NONE},
	[TokenType.SUPER]         = {null,             null,           NONE},
	[TokenType.THIS]          = {null,             null,           NONE},
	[TokenType.TRUE]          = {&Parser.literal,  null,           NONE},
	[TokenType.VAR]           = {null,             null,           NONE},
	[TokenType.WHILE]         = {null,             null,           NONE},
	[TokenType.ERROR]         = {null,             null,           NONE},
	[TokenType.EOF]           = {null,             null,           NONE},
};

// === advancing ===

fn void Parser.advance(&p) {
	p.previous = p.current;
	while (true) {
		p.current = p.scanner.token();
		if (p.current.type != ERROR) break;
		p.error_at_current(p.scanner.lexeme(p.current));
	}
}
fn void Parser.consume(&p, TokenType token_type, String err_msg) {
	if (p.current.type == token_type) {
		p.advance();
		return;
	}
	p.error_at_current(err_msg);
}
fn bool Parser.match(&p, TokenType token_type) {
	if (!p.check(token_type)) return false;
	p.advance();
	return true;
}
fn bool Parser.check(&p, TokenType token_type) {
	// TODO refactor? is this really needed as separate method?
	return p.current.type == token_type;
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
fn void Parser.synchronize(&p) {
	// synchronize at semicolon (end of statement)
	p.panic_mode = false;
	while (p.current.type != EOF) {
		if (p.previous.type == SEMICOLON) return;
		switch (p.current.type) {
			case CLASS:
			case FUN:
			case VAR:
			case FOR:
			case IF:
			case WHILE:
			case PRINT:
			case RETURN: return;
			default: // nothing
		}
		p.advance();
	}
}

// === emit to chunk ===

fn Chunk* Parser.current_chunk(&p) {
	return p.compiling_chunk;
}
fn void Parser.emit_ops(&p, OpCode... ops) {
	foreach (op: ops) {
		p.current_chunk().write_instruction(op, p.previous.line);
	}
}
fn void! Parser.emit_constant(&p, Value value) {
	return p.current_chunk().write_constant(value, p.previous.line);
}
