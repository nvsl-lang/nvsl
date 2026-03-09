package novel.script.tools;

import novel.script.ScriptError;
import novel.script.bench.ScriptBench;
import novel.script.bench.ScriptBench.ScriptBenchConfig;

class NvslBenchMain {
	public static function main():Void {
		try {
			var config = parseArgs(Sys.args());
			Sys.println(ScriptBench.formatReport(ScriptBench.run(config)));
		} catch (error:Dynamic) {
			if (Std.isOfType(error, ScriptError)) {
				Sys.println("NVSL benchmark error: " + cast(error, ScriptError).message);
			} else if (Std.isOfType(error, String)) {
				Sys.println("NVSL benchmark error: " + cast error);
			} else {
				Sys.println("NVSL benchmark error: " + Std.string(error));
			}
			Sys.println("");
			Sys.println(usage());
			Sys.exit(1);
		}
	}

	static function parseArgs(args:Array<String>):ScriptBenchConfig {
		var modules = 8;
		var helpers = 16;
		var iterations = 20;
		var runIterations = 200;
		var warmup = 3;
		var seed = 7;
		var index = 0;

		while (index < args.length) {
			switch args[index] {
				case "--modules":
					modules = parseIntFlag(args, index, "--modules");
					index += 2;
				case "--helpers":
					helpers = parseIntFlag(args, index, "--helpers");
					index += 2;
				case "--iterations":
					iterations = parseIntFlag(args, index, "--iterations");
					index += 2;
				case "--run-iterations":
					runIterations = parseIntFlag(args, index, "--run-iterations");
					index += 2;
				case "--warmup":
					warmup = parseIntFlag(args, index, "--warmup");
					index += 2;
				case "--seed":
					seed = parseIntFlag(args, index, "--seed");
					index += 2;
				case "--help" | "-h":
					throw usage();
				default:
					throw "Unknown benchmark option '" + args[index] + "'.";
			}
		}

		return new ScriptBenchConfig(modules, helpers, iterations, runIterations, warmup, seed);
	}

	static function parseIntFlag(args:Array<String>, index:Int, flag:String):Int {
		if (index + 1 >= args.length) {
			throw "Missing value after " + flag + ".";
		}

		var parsed = Std.parseInt(args[index + 1]);

		if (parsed == null) {
			throw "Expected an integer after " + flag + ".";
		}

		return parsed;
	}

	static function usage():String {
		return
"usage:
  nvsl bench [--modules N] [--helpers N] [--iterations N] [--run-iterations N] [--warmup N] [--seed N]

defaults:
  --modules 8
  --helpers 16
  --iterations 20
  --run-iterations 200
  --warmup 3
  --seed 7

notes:
  - benchmarking is only available in a source checkout
  - the harness generates a synthetic multi-module NVSL project in memory
  - parse/check/load phases use --iterations
  - runtime call/execution phases use --run-iterations";
	}
}
