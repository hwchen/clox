module compiler;

import std::io;

import scanner;
import vm;

fn Chunk compile(char[] src) {
	scanner::Scanner scnr;
	scnr.init(src);

	// temporary to drive the scanner
	int line = -1;
	while (true) {
		Token token = scnr.token();
		if (token.line != line) {
			io::printf("%4d ", token.line);
			line = token.line;
		} else {
			io::print("   |");
		}
		io::printfn("%v '%s'", token.type, scanner::token_lexeme(token, src));

		if (token.type == EOF) break;
	}

	return {};
}
