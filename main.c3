module clox;

import std::io;
import std::core::mem;

import compiler;
import vm;

fn int main(String[] args) {
	if (args.len == 1) {
		if ( catch error = repl()) {
			io::eprintfn("Error in repl: %s", error);
			// TODO also grab scanner errors here?
			return 77;
		}
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

fn void! repl() {
	Vm vm;

	while (true) {
		io::print("> ");
		@pool() {
			String line = io::readline(io::stdin())!;
			Chunk* chunk = mem::new(Chunk);
			compiler::compile(line, chunk);
			vm.interpret(chunk)!;
		};
	}
}
