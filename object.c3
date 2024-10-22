module object;

enum ObjType : char {
	STRING,
}

struct Obj {
	ObjType type;
}

struct ObjString {
	Obj obj;
	int length;
	char* chars;
}
