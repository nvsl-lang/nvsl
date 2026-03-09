package novel.script;

import novel.script.bytecode.Nvbc.NvbcProgram;
import novel.script.bytecode.NvbcCodec;
import novel.script.compiler.NvslCompiler;
import novel.script.semantics.ScriptChecker;
import novel.script.semantics.ScriptChecker.ScriptProgramInfo;
import novel.script.semantics.ScriptDiagnostics;
import novel.script.project.ScriptLinker;
import novel.script.project.ScriptLinker.ScriptLinkedProject;
import novel.script.project.ScriptProject.ScriptProject;
import novel.script.project.ScriptProject.ScriptProjectInfo;
import novel.script.project.ScriptProject.ScriptProjectLoader;
import novel.script.project.ScriptProject.ScriptSourceInput;
import novel.script.project.ScriptProject.ScriptSourceMap;
import novel.script.runtime.ScriptInterpreter;
import novel.script.runtime.ScriptInterpreter.ScriptModuleInstance;
import novel.script.runtime.ScriptInterpreter.ScriptProjectInstance;
import novel.script.syntax.ScriptAst.ScriptProgram;
import novel.script.syntax.ScriptParser;
import novel.script.vm.NvslVm;
import novel.script.vm.NvslVm.NvslVmProjectInstance;

class ScriptEngine {
	public static function parse(sourceName:String, source:String):ScriptProgram {
		return ScriptParser.parseSource(sourceName, source);
	}

	public static function parseSources(inputs:Array<ScriptSourceInput>):ScriptProject {
		return ScriptProjectLoader.parseSources(inputs);
	}

	public static function parseDirectory(root:String, ?extension:String = ".nvsl"):ScriptProject {
		return ScriptProjectLoader.loadDirectory(root, extension);
	}

	public static function check(program:ScriptProgram):ScriptProgramInfo {
		return ScriptChecker.check(program);
	}

	public static function checkProject(project:ScriptProject):ScriptProjectInfo {
		return ScriptChecker.checkProject(project);
	}

	public static function linkProject(project:ScriptProject, ?entryModule:String, ?entryExport:String = "main"):ScriptLinkedProject {
		return ScriptLinker.link(project, entryModule, entryExport);
	}

	public static function linkSources(inputs:Array<ScriptSourceInput>, ?entryModule:String, ?entryExport:String = "main"):ScriptLinkedProject {
		return ScriptLinker.linkSources(inputs, entryModule, entryExport);
	}

	public static function linkDirectory(root:String, ?extension:String = ".nvsl", ?entryModule:String, ?entryExport:String = "main"):ScriptLinkedProject {
		return ScriptLinker.linkDirectory(root, extension, entryModule, entryExport);
	}

	public static function compileProject(
		project:ScriptProject,
		?entryModule:String,
		?entryExport:String = "main"
	):NvbcProgram {
		return NvslCompiler.compileProject(project, entryModule, entryExport);
	}

	public static function compileSources(
		inputs:Array<ScriptSourceInput>,
		?entryModule:String,
		?entryExport:String = "main"
	):NvbcProgram {
		return NvslCompiler.compileSources(inputs, entryModule, entryExport);
	}

	public static function compileDirectory(
		root:String,
		?extension:String = ".nvsl",
		?entryModule:String,
		?entryExport:String = "main"
	):NvbcProgram {
		return NvslCompiler.compileDirectory(root, extension, entryModule, entryExport);
	}

	public static function encodeBytecode(program:NvbcProgram):String {
		return NvbcCodec.stringifyProgram(program);
	}

	public static function decodeBytecode(json:String):NvbcProgram {
		return NvbcCodec.parseProgram(json);
	}

	public static function loadProgram(program:ScriptProgram):ScriptModuleInstance {
		check(program);
		return ScriptInterpreter.load(program);
	}

	public static function loadProject(project:ScriptProject):ScriptProjectInstance {
		checkProject(project);
		return ScriptInterpreter.loadProject(project);
	}

	public static function loadSource(sourceName:String, source:String):ScriptModuleInstance {
		return loadProgram(parse(sourceName, source));
	}

	public static function loadSources(inputs:Array<ScriptSourceInput>):ScriptProjectInstance {
		return loadProject(parseSources(inputs));
	}

	public static function loadDirectory(root:String, ?extension:String = ".nvsl"):ScriptProjectInstance {
		return loadProject(parseDirectory(root, extension));
	}

	public static function loadBytecode(program:NvbcProgram):NvslVmProjectInstance {
		return NvslVm.loadProgram(program);
	}

	public static function loadBytecodeJson(json:String):NvslVmProjectInstance {
		return NvslVm.loadJson(json);
	}

	public static function formatError(error:ScriptError, ?sourceMap:ScriptSourceMap):String {
		return ScriptDiagnostics.format(error, sourceMap);
	}
}
