package novel.script.tools;

import sys.io.File;
import novel.script.ScriptEngine;
import novel.script.ScriptError;

class NvslcMain {
	public static function main():Void {
		try {
			run(Sys.args());
		} catch (error:ScriptError) {
			Sys.stderr().writeString("nvslc: " + error.message + "\n");
			Sys.exit(1);
		}
	}

	static function run(args:Array<String>):Void {
		if (args.length < 2) {
			throw new ScriptError("usage: nvslc <source-dir> <output.nvbc> [--entry module.export] [--extension .nvsl]");
		}

		var sourceDir = args[0];
		var outputPath = args[1];
		var extension = ".nvsl";
		var entryModule:Null<String> = null;
		var entryExport = "main";
		var index = 2;

		while (index < args.length) {
			switch args[index] {
				case "--entry":
					if (index + 1 >= args.length) {
						throw new ScriptError("nvslc expects a value after --entry.");
					}

					var entry = parseEntrypoint(args[index + 1]);
					entryModule = entry.moduleName;
					entryExport = entry.exportName;
					index += 2;
				case "--extension":
					if (index + 1 >= args.length) {
						throw new ScriptError("nvslc expects a value after --extension.");
					}

					extension = args[index + 1];
					index += 2;
				default:
					throw new ScriptError("Unknown nvslc option '" + args[index] + "'.");
			}
		}

		var program = ScriptEngine.compileDirectory(sourceDir, extension, entryModule, entryExport);
		File.saveContent(outputPath, ScriptEngine.encodeBytecode(program));
		Sys.println("nvslc wrote " + outputPath + " (" + program.moduleOrder.length + " modules).");
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
