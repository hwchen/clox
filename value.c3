module value;

import std::io;

enum ValueType {
	BOOL,
	NIL,
	NUMBER,
}

struct Value {
	ValueType type;
	union {
		bool   boolean;
		double number;
	}
}
fn Value from_bool(bool boolean) {
	return {.type = BOOL, .boolean = boolean};
}
fn Value nil() {
	return {.type = NIL, .number = 0};
}
fn Value from_number(double number) {
	return {.type = NUMBER, .number = number};
}
fn bool! as_bool(Value v) {
	return (v.type == BOOL) ? v.boolean : ValueError.ERR_AS_BOOL?;
}
fn bool is_nil(Value v) {
	return v.type == NIL;
}
fn double! as_number(Value v) {
	return (v.type == NUMBER) ? v.number : ValueError.ERR_AS_NUMBER?;
}
fn void Value.print(&v) {
	switch (v.type) {
		case BOOL: io::printf("%s", v.boolean);
		case NIL: io::printf("nil");
		case NUMBER: io::printf("%g", v.number);
	}
}

fault ValueError{
	ERR_AS_BOOL,
	ERR_AS_NUMBER,
}
