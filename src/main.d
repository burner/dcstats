module main;

import std.net.curl : get;
import std.stdio : writeln;
import std.xml;

void main() {
	auto doc = new Document(
		//get("http://forum.dlang.org/group/digitalmars.D").idup
		get("http://www.digitalmars.com/d/archives/digitalmars/D/announce/StackOverflow_Chat_Room_22769.html").idup
	);

}
