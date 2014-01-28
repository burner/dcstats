module main;

import std.net.curl : get;
import std.stdio : writeln;
import std.xml;

import std.range : isInputRange, isOutputRange, ElementType;
import std.typetuple : allSatisfy, TypeTuple;

template allSatisfyBinary(alias F, T...)
{
    static if (T.length == 0)
    {
        enum allSatisfyBinary = true;
    }
    else static if (T.length == 1)
	{
        enum allSatisfyBinary = false;
	}
    else static if (T.length == 2)
    {
        enum allSatisfyBinary = F!(T[0], T[1]);
    }
    else
    {
        enum allSatisfyBinary = allSatisfyBinary!(F, T[ 0  .. 2]) &&
			allSatisfyBinary!(F, T[2 .. $]);
    }
}

template staticSwitchBind(S, T...)
{
    static if (T.length == 0)
    {
        alias staticSwitchBind = TypeTuple!();
    }
    else static if (T.length == 1)
    {
        alias staticSwitchBind = TypeTuple!(T[0], S);
    }
    else
    {
        alias staticSwitchBind =
            TypeTuple!(
                staticSwitchBind!(S, T[ 0  .. $/2]),
                staticSwitchBind!(S, T[$/2 .. $]));
    }
}

pragma(msg, staticSwitchBind!(int, Dummy));
pragma(msg, allSatisfyBinary!(isOutputRange, staticSwitchBind!(int, Dummy)));
pragma(msg, staticSwitchBind!(int, Dummy, Dummy));
pragma(msg, allSatisfyBinary!(isOutputRange, staticSwitchBind!(int, Dummy, Dummy)));
pragma(msg, staticSwitchBind!(int, Dummy, Dummy, Dummy));
pragma(msg, allSatisfyBinary!(isOutputRange, staticSwitchBind!(int, Dummy, Dummy, Dummy)));

void distribute(Range1, Ranges...)(Range1 input, Ranges output) 
	if(isInputRange!Range1
	&& allSatisfyBinary!(isOutputRange, 
		staticSwitchBind!(ElementType!Range1, Ranges))
	)
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
