package novel.script.tools;

import sys.io.File;
import novel.script.ScriptEngine;
import novel.script.ScriptError;
import novel.script.runtime.ScriptValue.ScriptValueTools;

class NvslVmMain {
	public static function main():Void {
		try {
			run(Sys.args());
		} catch (error:ScriptError) {
			Sys.stderr().writeString("nvslvm: " + error.message + "\n");
			Sys.exit(1);
		}
	}

	static function run(args:Array<String>):Void {
		if (args.length < 1) {
			throw new ScriptError("usage: nvslvm <program.nvbc> [module.export]");
		}

		var program = ScriptEngine.loadBytecodeJson(File.getContent(args[0]));
		var result = if (args.length >= 2) {
			var entry = parseEntrypoint(args[1]);
			program.call(entry.moduleName, entry.exportName, []);
		} else {
			program.callDefault([]);
		}

		Sys.println(ScriptValueTools.format(result));
	}

	static function parseEntrypoint(value:String):{ moduleName:String, exportName:String } {
		var index = value.lastIndexOf(".");

		if (index <= 0 || index >= value.length - 1) {
			throw new ScriptError("Entrypoint must be formatted as module.export.");
		}

		return {
			moduleName: value.substr(0, index),
			exportName: value.substr(index + 1),
		};
	}
}
