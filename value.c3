module value;

import std::io;

import object;

enum ValueType {
	BOOL,
	NIL,
	NUMBER,
	OBJ,
}

struct Value {
	ValueType type;
	union {
		bool   boolean;
		double number;
		Obj*   obj;
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
fn Value from_obj(Obj* obj) {
	return {.type = OBJ, .obj = obj};
}
fn ObjString* Value.as_string(&v) {
	return (ObjString*)v.obj;
}
fn char* Value.as_cstring(&v) {
	return ((ObjString*)v.obj).chars;
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
fn bool Value.is_obj(&v) {
	return v.type == OBJ;
}
fn bool Value.is_obj_type(&v, ObjType type) {
	return v.type == OBJ && v.obj.type == type;
}
fn bool Value.is_string(&v) {
	return v.is_obj_type(STRING);
}
fn bool Value.is_falsey(&v) {
	return v.is_nil() || (v.is_bool() && !v.boolean);
}
fn bool Value.equals(a, Value b) {
	if (a.type != b.type) return false;
	switch (a.type) {
		case BOOL:
			return (a.boolean == b.boolean);
		case NIL:
			return true;
		case NUMBER:
			return (a.number == b.number);
		default: $$unreachable();
	}
}
fn void Value.print(&v) {
	switch (v.type) {
		case BOOL:   io::printf("%s", v.boolean);
		case NIL:    io::printf("nil");
		case NUMBER: io::printf("%g", v.number);
		case OBJ:
			switch (v.obj.type) {
				case STRING:
					ObjString* s = (ObjString*)v.obj;
					io::printf("%s", s.chars[:s.length]);
			}
	}
}

fault ValueError{
	ERR_AS_BOOL,
	ERR_AS_NUMBER,
}
