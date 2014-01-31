module xmltokenrange;

//import std.array : Appender, appender, front, empty, popFront;
import std.array;
import std.algorithm : equal;
import std.stdio : writeln, writefln;
import std.uni : isWhite;
import std.range : isForwardRange, lockstep;
import std.format : format;
import std.string : stripLeft, indexOf;
import std.regex : ctRegex, match, regex, matchAll;

import std.logger;

ptrdiff_t stripLeftIdx(C)(C[] str) @safe pure 
{
    foreach (i, dchar c; str)
    {
        if (!std.uni.isWhite(c))
            return i;
    }

    return 0;
}

enum XmlTokenKind {
	OpenClose,
	Open,
	Close
}

struct XmlToken {
public:
	this(string d) {
		this.data = d;
		this.readName();
		this.readAttributes();
	}

	alias data this;

	string name;
	string[string] attributes;
	XmlTokenKind kind;

private:
	ptrdiff_t readNameBeginIdx() pure {
		return this.data[1 .. $].stripLeftIdx()+1;
	}

	ptrdiff_t readNameEndIdx() pure {
		auto lowIdx = readNameBeginIdx();
		return this.data[lowIdx .. $].indexOf(' ')+lowIdx;
	}

	void readName() pure {
		this.name = this.data[readNameBeginIdx() .. this.readNameEndIdx()];
	}

	void readAttributes() {
		foreach(attr; matchAll(data, re)) {
			attributes[attr[1]] = attr[2];
			//logF("%s %s %s", attr[1], attr[2], attr.post);
			logF("%s %s %s", attr[1], attr[2], attr.post);
		}
	}

	string data;
	static auto re = ctRegex!("\\s*(\\w+)\\s*=\\s*\"(\\w+)\"\\s*");
}

struct XmlTokenRange(InputRange) {
public:
	@property InputRange input() pure {
		return input_;
	}

	@property void input(InputRange i) {
		input_ = i;
		readFromRange();
	}

	@property auto front() {
		return XmlToken(store_.data);
	}

	@property void popFront() {
		readFromRange();
	}

	@property bool empty() const pure {
		return this.store_.data.empty() && std.array.empty(input_);
	}

	@property XmlTokenRange!InputRange save() pure {
		return this;
	}

private: 
	void readFromRange() {
		store_.clear();

		size_t numCrocos = 0;
		eatWhiteSpace();
		
		dchar prev = '\0';

		dchar it;
		for(; !input_.empty(); input_.popFront()) {
			it = input_.front();

			store_.put(it);

			if(it == '<' && prev != '\\') {
				++numCrocos;
			} else if(it == '>' && prev != '\\') {
				--numCrocos;
			}

			prev = it;

			if(!numCrocos) {
				input_.popFront();
				break;
			}
		}
	}

	void eatWhiteSpace() pure {
		while(!input_.empty && isWhite(std.array.front(input_))) {
			input_.popFront();
		}
	}

	InputRange input_;
	Appender!string store_;
}

auto xmlTokenRange(InputRange)(InputRange input) {
	XmlTokenRange!InputRange ret;
	ret.input = input;
   	return ret;	
}

unittest {
	static assert(isForwardRange!(XmlTokenRange!string));
}

unittest {
	string testString = "<hello world>";
	auto r = xmlTokenRange(testString);
	assert(r.front == testString);
	assert(r.front.name == "hello", r.front.name);
}

unittest {
	string testString = "<hello world>";
	string testString2 = "<hello robert>";
	auto test = testString ~ testString2;
	auto r = xmlTokenRange(test);
	foreach(a, b; lockstep(r, [testString, testString2])) {
		assert(a == b, format("%s %s", a, b));
	}
}

unittest {
	string testString = "<hello zzz=\"ttt\" world=\"foo\" args=\"bar\">";
	auto r = xmlTokenRange(testString);
	foreach(it; r) {
		foreach(key, value; it.attributes) {
			writefln("%s %s", key, value);
		}
	}
}
