package novel.script.tests;

import novel.script.ScriptEngine;
import novel.script.ScriptError;
import novel.script.runtime.ScriptValue;
import novel.script.runtime.ScriptValue.ScriptValueTools;

class StdTest {
	public static function main():Void {
		var source = '
module test.std;

fn testRandom() -> Bool {
	let r: Int = std.random(1, 10);
	let f: Float = std.randomFloat();
	r >= 1 && r <= 10 && f >= 0.0 && f < 1.0
}

fn testList() -> Bool {
	let l: List<String> = ["a", "b", "c"];
	let hasB: Bool = std.listContains(l, "b");
	let hasD: Bool = std.listContains(l, "d");
	let removed: List<String> = std.listRemove(l, "b");
	let cleared: List<String> = std.listClear(l);
	
	hasB && !hasD && std.len(removed) == 2 && !std.listContains(removed, "b") && std.len(cleared) == 0
}

fn testString() -> Bool {
	let s: String = "  hello world  ";
	let trimmed: String = std.trim(s);
	let hasHello: Bool = std.contains(trimmed, "hello");
	let parts: List<String> = std.split(trimmed, " ");
	
	trimmed == "hello world" && hasHello && std.len(parts) == 2 && parts[0] == "hello"
}

fn testMath() -> Bool {
	let v: Float = 1.6;
	std.round(v) == 2 && std.floor(v) == 1 && std.ceil(v) == 2
}

fn runAll() -> Bool {
	testRandom() && testList() && testString() && testMath()
}
		';

		var inputs = [{ sourceName: "test.nvsl", source: source }];
		var runtime = ScriptEngine.loadSources(inputs);
		var result = runtime.call("test.std", "runAll", []);

		switch result {
			case VBool(true):
				Sys.println("StdTest passed: all new std functions verified.");
			default:
				throw new ScriptError("StdTest failed: result was " + ScriptValueTools.format(result));
		}
	}
}
