module main;

import std.net.curl : get;
import std.stdio : writeln;
import std.xml;

//import std.algorithm;
import std.range : isInputRange, isOutputRange;
import std.typetuple : allSatisfy, TypeTuple;

void distribute(Range1, Ranges...)(Range1 input, Ranges output) 
	if(isInputRange!Range1)
	//&& allSatisfy!(isOutputRange, Ranges))
{
	foreach(it; input) {
		foreach(jt; output) {
			jt.put(it);
		}
	}
}

struct F {
	bool empty() { return cnt >= 10;}
	int front() { return cnt; }
	void popFront() { ++cnt; }

	private int cnt = 0;
}

struct Dummy {
	void put(int a) {
		writeln(a);
	}
}

struct SpecificOutputRange(T) {
	static bool opCall(U)(U u) pure {
		return isOutputRange!(U, T);
	}
}

bool f(T, S)(S) {
	return isOutputRange!(S, T);
}

unittest {
	static assert(isOutputRange!(Dummy, int));
	static assert(isOutputRange!(TypeTuple!(Dummy, int)));
	//static assert(allSatisfy!(f!int, Dummy));
	distribute(F(), Dummy(), Dummy());
}

void main() {
	/*auto doc = new Document(
		//get("http://forum.dlang.org/group/digitalmars.D").idup
		get("http://www.digitalmars.com/d/archives/digitalmars/D/announce/StackOverflow_Chat_Room_22769.html").idup
	);*/

}
