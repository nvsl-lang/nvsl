package novel.script.tests;

import novel.script.ScriptEngine;
import novel.script.ScriptError;
import novel.script.runtime.ScriptHost;
import novel.script.runtime.ScriptValue;
import novel.script.semantics.ScriptType;

class ScriptHostTest {
	public static function main():Void {
		// 1. Register a custom host function
		var lastBg:String = "";
		ScriptHost.registerSimple(
			"vn.showBg",
			[TString],
			TVoid,
			function(args, span) {
				switch args[0] {
					case VString(id): lastBg = id;
					default: throw new ScriptError("Expected string for bg id", span);
				}
				return VVoid;
			}
		);

		// 2. Register a math function
		ScriptHost.registerSimple(
			"math.add",
			[TInt, TInt],
			TInt,
			function(args, span) {
				var a = switch args[0] { case VInt(v): v; default: 0; };
				var b = switch args[1] { case VInt(v): v; default: 0; };
				return VInt(a + b);
			}
		);

		var source = '
module test.host;

fn run(bg: String) -> Int {
	vn.showBg(bg);
	math.add(10, 5)
}
		';

		var inputs = [{ sourceName: "test.nvsl", source: source }];

		// 3. Test AST Interpreter
		var runtime = ScriptEngine.loadSources(inputs);
		var result = runtime.call("test.host", "run", [VString("forest")]);
		
		assertInt(result, 15, "AST result");
		if (lastBg != "forest") throw new ScriptError("AST side effect failed: expected forest, got " + lastBg);

		// 4. Test Bytecode VM
		var program = ScriptEngine.compileSources(inputs, "test.host", "run");
		var vm = ScriptEngine.loadBytecode(program);
		lastBg = ""; // reset
		var vmResult = vm.call("test.host", "run", [VString("beach")]);

		assertInt(vmResult, 15, "VM result");
		if (lastBg != "beach") throw new ScriptError("VM side effect failed: expected beach, got " + lastBg);

		// 5. Test Type Checking (Expected Failure)
		try {
			var badSource = 'module bad; fn x() -> Int { vn.showBg(123); 1 }';
			ScriptEngine.check(ScriptEngine.parse("bad.nvsl", badSource));
			throw new ScriptError("Expected type error for invalid argument type");
		} catch (e:ScriptError) {
			if (e.message.indexOf("vn.showBg argument 1 expects String but found Int") == -1) {
				throw new ScriptError("Unexpected error message: " + e.message);
			}
		}

		Sys.println("ScriptHostTest passed: dynamic registration, AST, VM, and type checking verified.");
	}

	static function assertInt(value:ScriptValue, expected:Int, label:String):Void {
		switch value {
			case VInt(actual) if (actual == expected):
			case VInt(actual):
				throw new ScriptError(label + " expected " + expected + " but got " + actual + ".");
			default:
				throw new ScriptError(label + " expected Int but got " + value + ".");
		}
	}
}
