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
fn bool Value.is_bool(&v) {
	return v.type == BOOL;
}
fn bool Value.is_nil(&v) {
	return v.type == NIL;
}
fn bool Value.is_number(&v) {
	return v.type == NUMBER;
}
fn bool! Value.as_bool(&v) {
	return (v.type == BOOL) ? v.boolean : ValueError.ERR_AS_BOOL?;
}
fn double! Value.as_number(&v) {
	return (v.type == NUMBER) ? v.number : ValueError.ERR_AS_NUMBER?;
}
fn bool Value.is_falsey(&v) {
	return v.is_nil() || !(v.as_bool() ?? true);
}
fn bool Value.equals(a, Value b) {
	if (a.type != b.type) return false;
	switch (a.type) {
		case BOOL:
			bool aa = a.as_bool() ?? false;
			bool bb = b.as_bool() ?? false;
			return (aa == bb);
		case NIL:
			return true;
		case NUMBER:
			double aa = a.as_number() ?? 0;
			double bb = b.as_number() ?? 0;
			return (aa == bb);
		default: $$unreachable();
	}
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
