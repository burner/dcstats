module xmltokenrange;

//import std.array : Appender, appender, front, empty, popFront;
import std.array;
import std.algorithm : equal, count;
import std.conv : to;
import std.encoding : index;
import std.stdio : writeln, writefln;
import std.uni : isWhite;
import std.range : isForwardRange, lockstep;
import std.format : format;
import std.string : stripLeft, indexOf, CaseSensitive, strip;
import std.regex : ctRegex, match, regex, matchAll, popFrontN;
import std.traits : isSomeChar;
import std.functional : binaryFun;

import std.logger;

ptrdiff_t stripLeftIdx(C)(C[] str) @safe pure 
{
	bool foundSome = false;
    foreach (i, dchar c; str)
    {
        if(!std.uni.isWhite(c)) {
            return i;
		} else {
			foundSome = true;
		}
    }

	if(foundSome) {
		return str.length;
	}
    return 0;
}

ptrdiff_t indexOfNone(Char,R2)(const(Char)[] haystack, R2 needles,
		const size_t startIdx, CaseSensitive cs = CaseSensitive.yes) @safe pure
    if (isSomeChar!Char && isForwardRange!R2 && 
		is(typeof(binaryFun!"a == b"(haystack.front, needles.front))))
{	
    if (startIdx < haystack.length)
    {
        ptrdiff_t foundIdx = indexOfNone(haystack[startIdx .. $], needles, cs);
        if (foundIdx != -1)
        {
            return foundIdx + cast(ptrdiff_t)startIdx;
        }
    }
    return -1;
}

ptrdiff_t indexOfNone(Char,R2)(const(Char)[] haystack, R2 needles,
		CaseSensitive cs = CaseSensitive.yes) @safe pure
    if (isSomeChar!Char && isForwardRange!R2 && 
		is(typeof(binaryFun!"a == b"(haystack.front, needles.front))))
{
    if (cs == CaseSensitive.yes)
    {
		foreach (ptrdiff_t i, dchar c; haystack)
		{
			foreach (dchar o; needles)
			{
				if (c != o)
				{
					return i;
				}	
			}
		}
	}
	else
	{
		foreach (ptrdiff_t i, dchar c; haystack)
		{
			dchar cLow = std.uni.toLower(c);
			foreach (dchar o; needles)
			{
				if (cLow != o)
				{
					return i;
				}	
			}
		}
	}

	return -1;
}

ptrdiff_t indexOfAny(Char,R2)(const(Char)[] haystack, R2 needles,
		CaseSensitive cs = CaseSensitive.yes) @safe pure
    if (isSomeChar!Char && isForwardRange!R2 && 
		is(typeof(binaryFun!"a == b"(haystack.front, needles.front))))
{
    if (cs == CaseSensitive.yes)
    {
		foreach (ptrdiff_t i, dchar c; haystack)
		{
			foreach (dchar o; needles)
			{
				if (c == o)
				{
					return i;
				}	
			}
		}
	}
	else
	{
		foreach (ptrdiff_t i, dchar c; haystack)
		{
			dchar cLow = std.uni.toLower(c);
			foreach (dchar o; needles)
			{
				if (cLow == o)
				{
					return i;
				}	
			}
		}
	}

	return -1;
}

unittest {
	ptrdiff_t i = "helloWorld".indexOfAny("Wr");
	assert(i == 5);
	i = "öällo world".indexOfAny("lo ");
	assert(i == 4, to!string(i));
}

ptrdiff_t indexOfAny(Char,R2)(const(Char)[] haystack, R2 needles,
		const size_t startIdx, CaseSensitive cs = CaseSensitive.yes) @safe pure
    if (isSomeChar!Char && isForwardRange!R2 && 
		is(typeof(binaryFun!"a == b"(haystack.front, needles.front))))
{	
    if (startIdx < haystack.length)
    {
        ptrdiff_t foundIdx = indexOfAny(haystack[startIdx .. $], needles, cs);
        if (foundIdx != -1)
        {
            return foundIdx + cast(ptrdiff_t)startIdx;
        }
    }
    return -1;
}

void eatWhitespace(C)(ref C c) @safe pure {
	static if(is(C == string)) {
		c = c.strip();
	} else {
		auto idx = stripLeftIdx(c);
		if(idx == c.length) {
			c = c[idx-1 .. $];
		} else {
			c = c[idx .. $];
		}
	}
}

unittest {
	auto s = "    foo";
	eatWhitespace(s);
	assert(equal(s, "foo"));
}

string eatKey(C)(ref C c) @safe pure {
	eatWhitespace(c);
	auto endOfKey = c.indexOfAny("=\t \n\r");
	assert(endOfKey != -1);
	string name = c[0..endOfKey];
	c = c[endOfKey .. $];
	if(c[0] == '=') {
		c = c[endOfKey+1 .. $];
	} else {
		eatWhitespace(c);
		c = c[1 .. $];
	}
	
	return name;
}

unittest {
	string input = "   \tfoo = ";
	auto n = eatKey(input);
	assert(n == "foo", n);
	assert(input == "", "\"" ~ input ~ "\"");
}

string eatAttri(C)(ref C c) @safe pure {
	eatWhitespace(c);
	auto firstTick = c.indexOf('"');
	assert(firstTick != -1);
	c = c[firstTick+1 .. $];

	size_t i = 0;
	while(true) {
		if(i > 0 && c[i] == '"' && c[i-1] != '\\') {
			break;
		} else if(i == 0 && c[i] == '"') {
			break;
		} else {
			++i;
		}
	}

	auto attri = c[0 .. i];
	c = c[i .. $];
	if(c[0] == '"') {
		c = c[1 .. $];
	}
	eatWhitespace(c);

	return attri;
}

unittest {
	string input = " \"asdf\"  ";
	string attri = eatAttri(input);
	assert(attri == "asdf", "\"" ~ attri ~ "\" " ~ input);
	assert(input.empty, "\"" ~ input ~ "\"");
}

enum XmlTokenKind {
	Invalid,
	OpenClose,
	Open,
	Text,
	Comment,
	Close
}

struct XmlToken {
public:
	this(string d) {
		this.data = d;
		this.kind = this.getKind();
		this.readName();
		this.readAttributes();
	}

	alias name this;

	string name;
	string[string] attributes;
	XmlTokenKind kind = XmlTokenKind.Invalid;

private:
	XmlTokenKind getKind() {
		return XmlTokenKind.Invalid;
	}

	ptrdiff_t readNameBeginIdx() pure {
		return this.data[1 .. $].stripLeftIdx()+1;
	}

	ptrdiff_t readNameEndIdx() pure {
		auto lowIdx = readNameBeginIdx();
		return this.data[lowIdx .. $].indexOfAny(" >/")+lowIdx;
	}

	void readName() pure {
		this.name = this.data[readNameBeginIdx() .. this.readNameEndIdx()];
		this.data = this.data[this.readNameEndIdx() .. $];
	}

	/*void readAttributes() {
		foreach(attr; matchAll(data, re)) {
			attributes[attr[1]] = attr[2];
			//logF("%s %s %s", attr[1], attr[2], attr.post);
			logF("%s %s %s", attr[1], attr[2], attr.post);
		}
	}*/

	void readAttributes() {
		while(!this.data.empty) {
			eatWhitespace(this.data);

			auto end = this.data.indexOf("/>");
			if(end == 0) {
				this.kind = XmlTokenKind.Close;
				break;
			}

			end = this.data.indexOf(">");
			if(end == 0) {
				break;
			}

			eatWhitespace(this.data);
			string key = eatKey(this.data);
			eatWhitespace(this.data);
			string attri = eatAttri(this.data);
			eatWhitespace(this.data);

		}
	}

	string data;
	//static auto re = ctRegex!("\\s*(\\w+)\\s*=\\s*\"(\\w+)\"\\s*");
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
	string testString = "<hello>";
	auto r = xmlTokenRange(testString);
	assert(r.front.name == "hello", r.front.name);
}

unittest {
	string testString = "<hello>";
	string testString2 = "<hello>";
	auto test = testString ~ testString2;
	auto r = xmlTokenRange(test);
	/*foreach(a, b; lockstep(r, [testString, testString2])) {
		assert(a == b, format("%s %s", a, b));
	}*/
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
