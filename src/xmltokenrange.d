module xmltokenrange;

//import std.array : Appender, appender, front, empty, popFront;
import std.array;
import std.algorithm : equal;
import std.stdio : writeln, writefln;
import std.uni : isWhite;
import std.range : isForwardRange, lockstep;
import std.format : format;

struct XmlTokenRange(InputRange) {
public:
	@property InputRange input() pure {
		return input_;
	}

	@property void input(InputRange i) {
		input_ = i;
		readFromRange();
	}

	@property auto front() pure {
		return store_.data;
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
	assert(equal(r.front, testString));
}

unittest {
	string testString = "<hello world>";
	string testString2 = "<hello robert>";
	auto test = testString ~ testString2;
	auto r = xmlTokenRange(test);
	foreach(a, b; lockstep(r, [testString, testString2])) {
		//writefln("%s %s", a, b);
		assert(a == b, format("%s %s", a, b));
	}
}
