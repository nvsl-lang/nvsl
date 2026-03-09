package novel.script.project;

import novel.script.ScriptError;
import novel.script.semantics.ScriptChecker;
import novel.script.runtime.ScriptInterpreter;
import novel.script.runtime.ScriptInterpreter.ScriptProjectInstance;
import novel.script.project.ScriptProject.ScriptProject;
import novel.script.project.ScriptProject.ScriptProjectInfo;
import novel.script.project.ScriptProject.ScriptProjectLoader;
import novel.script.project.ScriptProject.ScriptSourceInput;
import novel.script.semantics.ScriptType;
import novel.script.semantics.ScriptType.ScriptTypeTools;

class ScriptEntrypoint {
	public var moduleName(default, null):String;
	public var exportName(default, null):String;
	public var type(default, null):ScriptType;

	public function new(moduleName:String, exportName:String, type:ScriptType) {
		this.moduleName = moduleName;
		this.exportName = exportName;
		this.type = type;
	}
}

class ScriptLinkedProject {
	public var info(default, null):ScriptProjectInfo;
	public var entry(default, null):Null<ScriptEntrypoint>;

	public function new(info:ScriptProjectInfo, entry:Null<ScriptEntrypoint>) {
		this.info = info;
		this.entry = entry;
	}

	public function load():ScriptProjectInstance {
		return ScriptInterpreter.loadInfo(info);
	}
}

class ScriptLinker {
	public static function link(project:ScriptProject, ?entryModule:String, ?entryExport:String = "main"):ScriptLinkedProject {
		var info = ScriptChecker.checkProject(project);
		var entry = entryModule == null ? null : resolveEntrypoint(info, entryModule, entryExport);
		return new ScriptLinkedProject(info, entry);
	}

	public static function linkSources(inputs:Array<ScriptSourceInput>, ?entryModule:String, ?entryExport:String = "main"):ScriptLinkedProject {
		return link(ScriptProjectLoader.parseSources(inputs), entryModule, entryExport);
	}

	public static function linkDirectory(root:String, ?extension:String = ".nvsl", ?entryModule:String, ?entryExport:String = "main"):ScriptLinkedProject {
		return link(ScriptProjectLoader.loadDirectory(root, extension), entryModule, entryExport);
	}

	public static function resolveEntrypoint(info:ScriptProjectInfo, moduleName:String, exportName:String):ScriptEntrypoint {
		var module = info.modules.get(moduleName);

		if (module == null) {
			throw new ScriptError("Unknown entry module '" + moduleName + "'.");
		}

		var binding = module.exports.get(exportName);

		if (binding == null) {
			throw new ScriptError("Module '" + moduleName + "' does not export '" + exportName + "'.");
		}

		return new ScriptEntrypoint(moduleName, exportName, binding.type);
	}

	public static function resolveFunctionEntrypoint(
		info:ScriptProjectInfo,
		moduleName:String,
		exportName:String,
		?paramCount:Int
	):ScriptEntrypoint {
		var entry = resolveEntrypoint(info, moduleName, exportName);

		switch entry.type {
			case TFunction(paramTypes, _):
				if (paramCount != null && paramTypes.length != paramCount) {
					throw new ScriptError(
						"Entrypoint '" + moduleName + "." + exportName + "' expects " + paramTypes.length
							+ " arguments, not " + paramCount + "."
					);
				}
			default:
				throw new ScriptError(
					"Entrypoint '" + moduleName + "." + exportName + "' is not callable; found "
						+ ScriptTypeTools.format(entry.type) + "."
				);
		}

		return entry;
	}
}
