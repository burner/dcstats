module main;

import std.net.curl : get;
import std.stdio : writeln;

import std.range;
import std.string;
import std.typetuple : allSatisfy, TypeTuple;

import std.logger;

import xmltokenrange;
import dropuntil;

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

template staticBind2(S, T...)
{
    static if (T.length == 0)
    {
        alias staticBind = TypeTuple!();
    }
    else static if (T.length == 1)
    {
        alias staticBind = TypeTuple!(T[0], S);
    }
    else
    {
        alias staticBind = TypeTuple!(
                staticBind!(S, T[ 0  .. $/2]),
                staticBind!(S, T[$/2 .. $]));
    }
}

void distribute(InputRange, OutputRanges...)(InputRange input, 
		OutputRanges output) if(isInputRange!Range1 && 
		allSatisfyBinary!(isOutputRange, 
		staticBind2!(ElementType!InputRange, OutputRanges))
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

void main() {
	log("main");
	auto s = get("http://www.digitalmars.com/d/archives/digitalmars/D/index.html").idup;
	auto sp = s.splitLines();
	auto x = xmlTokenRange(s).dropUntil!(a => a.kind == XmlTokenKind.Open &&
			"id" in a.attributes && a.attributes["id"] == "content");
	foreach(a; x) {
		if(a.kind == XmlTokenKind.Open && a.attributes.length != 0) {
			writeln(a.attributes);
		}
	}
}
