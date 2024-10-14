module scanner;

import std::io;

struct Scanner {
	char[] src;
	int    start;
	int    current;
	int    line;
	String err_msg;
}

fn void Scanner.init(&self, char[] src) {
	self.src = src;
	self.start = 0;
	self.current = 0;
	self.line = 1;
}

fn Token Scanner.token(&self) {
	self.skip_whitespace();
	self.start = self.current;

	if (self.is_end()) {
		return self.make_token(EOF);
	}

	char c = self.advance();
	
	switch (c) {
		case '(': return self.make_token(LEFT_PAREN);
		case ')': return self.make_token(RIGHT_PAREN);
		case '{': return self.make_token(LEFT_BRACE);
		case '}': return self.make_token(RIGHT_BRACE);
		case ';': return self.make_token(SEMICOLON);
		case ',': return self.make_token(COMMA);
		case '.': return self.make_token(DOT);
		case '-': return self.make_token(MINUS);
		case '+': return self.make_token(PLUS);
		case '/': return self.make_token(SLASH);
		case '*': return self.make_token(STAR);
		case '!': return self.make_token(self.match('=') ? BANG_EQUAL : BANG);
		case '=': return self.make_token(self.match('=') ? EQUAL_EQUAL : EQUAL);
		case '<': return self.make_token(self.match('=') ? LESS_EQUAL : LESS);
		case '>': return self.make_token(self.match('=') ? GREATER_EQUAL : GREATER);
		case '"': return self.make_string_token();
		case '0'..'9': return self.make_number_token();
		case 'a'..'z':
		case 'A'..'Z': return self.make_ident_token();
	}

	return self.error_token("Unexpected character.");
}

fn Token Scanner.make_string_token(&self) {
	while (self.peek() != '"' && !self.is_end()) {
		if (self.peek() == '\n') {
			self.line += 1;
		}
		self.advance();
	}
	if (self.is_end()) {
		return self.error_token("Unterminated string");
	}
	self.advance(); // the closing quote
	return self.make_token(STRING);
}

fn Token Scanner.make_number_token(&self) {
	while (is_digit(self.peek())) {
		self.advance();
	}
	// fractional part
	if (self.peek() == '.' && is_digit(self.peek_next())) {
		self.advance();
		while (is_digit(self.peek())) {
			self.advance();
		}
	}
	return self.make_token(NUMBER);
}

fn void Scanner.skip_whitespace(&self) {
	while (true) {
		if (self.is_end()) {
			return;
		}
		char c = self.peek();
		switch (c) {
			case ' ':
			case '\r':
			case '\t':
				self.advance();
			case '\n':
				self.line += 1;
				self.advance();
			case '/':
				// comments
				if (self.peek_next() == '/') {
					while (self.peek() != '\n' && !self.is_end()) {
						self.advance();
					}
				} else {
					return;
				}
			default:
				return;
		}
	}
}

fn char Scanner.advance(&self) {
	self.current += 1;
	return self.src[self.current - 1];
}

fn char Scanner.peek(&self) {
	if (self.is_end()) return 0; // not needed in odin or clox, why?
	return self.src[self.current];
}

// returns \0 if not 
fn char Scanner.peek_next(&self) {
	if (self.is_end()) return 0;
	return self.src[self.current + 1];
}

// advances if matches
fn bool Scanner.match(&self, char expected) {
	if (self.is_end()) return false;
	if (self.src[self.current] != expected) return false;
	self.current += 1;
	return true;
}

fn bool Scanner.is_end(&self) {
	return self.current >= self.src.len;
}

fn bool is_digit(char c) {
	return c >= '0' && c <= '9';
}

fn Token Scanner.make_token(&self, TokenType type) {
	return {
		.type = type,
		.start = self.start,
		.length = self.current - self.start,
		.line = self.line,
	};
}

// Hack for storing error messages. In clox, these are defined inline as string literals,
// and then start is set to that pointer. Here, we'll store the err msg in the scanner and
// retrieve it in a separate step.
//
// TODO: not sure if clox scanner does early return on errors, will have to restructure if not.
fn Token Scanner.error_token(&self, String msg) {
	self.err_msg = msg;
	return self.make_token(ERROR);
}

// === Identifiers and Keywords ===

fn bool is_alpha(char c) {
	switch (c) {
		case 'a'..'z':
		case 'A'..'Z':
			return true;
		default:
			return false;
	}
}

// the first char is only alpha, but that's checked in scan_token switch
fn Token Scanner.make_ident_token(&self) {
	while (is_alpha(self.peek()) || is_digit(self.peek())) {
		self.advance();
	}
	char[] lexeme = self.src[self.start..self.current - 1];
	if (try kw = try_keyword(lexeme)) {
		return self.make_token(kw);
	} else {
		return self.make_token(IDENTIFIER);
	}
}

fn TokenType! try_keyword(char[] s) {
	if (s == "and")   return AND;
	if (s == "class") return CLASS;
	if (s == "else")  return ELSE;
	if (s == "false") return FALSE;
	if (s == "for")   return FOR;
	if (s == "fun")   return FUN;
	if (s == "if")    return IF;
	if (s == "nil")   return NIL;
	if (s == "or")    return OR;
	if (s == "print") return PRINT;
	if (s == "return")return RETURN;
	if (s == "super") return SUPER;
	if (s == "this")  return THIS;
	if (s == "true")  return TRUE;
	if (s == "var")   return VAR;
	if (s == "while") return WHILE;
	return SearchResult.MISSING?;
}

// === Tokens ===

struct Token {
	TokenType type;
	int       start;
	int       length;
	int       line;
}

enum TokenType : char {
	EOF, // 0

	// single-character tokens
	LEFT_PAREN, RIGHT_PAREN, LEFT_BRACE, RIGHT_BRACE,
	COMMA, DOT, MINUS, PLUS, SEMICOLON, SLASH, STAR,

	// one or two character tokens
	BANG, BANG_EQUAL, EQUAL, EQUAL_EQUAL,
	GREATER, GREATER_EQUAL, LESS, LESS_EQUAL,

	// literals
	IDENTIFIER, STRING, NUMBER,

	// keywords
	AND, CLASS, ELSE, FALSE, FOR, FUN, IF, NIL, OR,
	PRINT, RETURN, SUPER, THIS, TRUE, VAR, WHILE,

	ERROR,
}

fn char[] token_lexeme(Token token, char[] src) {
	return src[token.start:token.length];
}
