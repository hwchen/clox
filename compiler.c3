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
			io::printf("%04d ", token.line);
			line = token.line;
		} else {
			io::print("   |");
		}
		io::printf("%s '%s'", token.type, (String)scanner::token_lexeme(token, src));
		if (token.type == ERROR) {
			io::printfn(" Error: %s", scnr.err_msg);
		} else {
			io::printn();
		}

		if (token.type == EOF) break;
	}

	return {};
}
