module clox;

import std::io;
import std::core::mem;

import compiler;
import vm;

fn int main(String[] args) {
	if (args.len == 1) {
		repl();
	} else if (args.len == 2) {
		//run_file(os.args[1])
		io::eprintn("Files not yet supported");
		return 128;
	} else {
		io::eprintn("Usage: clox [path]");
		return 64;
	}
	return 0;
}

fn void repl() {
	Vm vm;

	while (true) {
		io::print("> ");
		@pool() {
			String! line = io::treadline(io::stdin());
			if (catch error = line) {
				if (error == IoError.EOF) return;
				io::eprintfn("Readline error: %s", error);
			}
			Chunk* chunk = mem::temp_new(Chunk);
			if (catch error = compiler::compile(line, chunk)) {
				io::eprintfn("Compiler error: %s", error);
			}
			if (catch error = vm.interpret(chunk)) {
				io::eprintfn("Interpreter error: %s", error);
			}
		};
	}
}
