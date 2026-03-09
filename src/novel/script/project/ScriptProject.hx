package novel.script.project;

import haxe.ds.StringMap;
import haxe.ds.IntMap;
import sys.FileSystem;
import sys.io.File;
import novel.script.ScriptError;
import novel.script.syntax.ScriptAst.ScriptAssign;
import novel.script.syntax.ScriptAst.ScriptDecl;
import novel.script.syntax.ScriptAst.ScriptEnumDecl;
import novel.script.syntax.ScriptAst.ScriptExpr;
import novel.script.syntax.ScriptAst.ScriptExprDef;
import novel.script.syntax.ScriptAst.ScriptFieldDecl;
import novel.script.syntax.ScriptAst.ScriptFunctionDecl;
import novel.script.syntax.ScriptAst.ScriptProgram;
import novel.script.syntax.ScriptAst.ScriptStmt;
import novel.script.syntax.ScriptAst.ScriptStructDecl;
import novel.script.syntax.ScriptAst.ScriptValueDecl;
import novel.script.syntax.ScriptParser;
import novel.script.semantics.ScriptBindingInfo;
import novel.script.semantics.ScriptType;
import novel.script.semantics.ScriptType.ScriptTypeTools;

typedef ScriptSourceInput = {
	var sourceName:String;
	var source:String;
}

class ScriptSourceMap {
	var sources:StringMap<String>;

	public function new() {
		this.sources = new StringMap();
	}

	public function add(sourceName:String, source:String):Void {
		sources.set(sourceName, source);
	}

	public function get(sourceName:String):Null<String> {
		return sources.get(sourceName);
	}

	public function exists(sourceName:String):Bool {
		return sources.exists(sourceName);
	}
}

class ScriptProject {
	public var modules(default, null):StringMap<ScriptProgram>;
	public var sourceMap(default, null):ScriptSourceMap;

	public function new(modules:StringMap<ScriptProgram>, sourceMap:ScriptSourceMap) {
		this.modules = modules;
		this.sourceMap = sourceMap;
	}
}

class ScriptStructInfo {
	public var qualifiedName(default, null):String;
	public var moduleName(default, null):String;
	public var name(default, null):String;
	public var decl(default, null):ScriptStructDecl;
	public var fields(default, null):StringMap<ScriptType>;
	public var fieldOrder(default, null):Array<String>;

	public function new(
		qualifiedName:String,
		moduleName:String,
		name:String,
		decl:ScriptStructDecl,
		fields:StringMap<ScriptType>,
		fieldOrder:Array<String>
	) {
		this.qualifiedName = qualifiedName;
		this.moduleName = moduleName;
		this.name = name;
		this.decl = decl;
		this.fields = fields;
		this.fieldOrder = fieldOrder;
	}
}

class ScriptEnumInfo {
	public var qualifiedName(default, null):String;
	public var moduleName(default, null):String;
	public var name(default, null):String;
	public var decl(default, null):ScriptEnumDecl;
	public var cases(default, null):StringMap<Bool>;
	public var caseOrder(default, null):Array<String>;

	public function new(
		qualifiedName:String,
		moduleName:String,
		name:String,
		decl:ScriptEnumDecl,
		cases:StringMap<Bool>,
		caseOrder:Array<String>
	) {
		this.qualifiedName = qualifiedName;
		this.moduleName = moduleName;
		this.name = name;
		this.decl = decl;
		this.cases = cases;
		this.caseOrder = caseOrder;
	}
}

class ScriptModuleInfo {
	public var name(default, null):String;
	public var program(default, null):ScriptProgram;
	public var imports(default, null):StringMap<String>;
	public var exports(default, null):StringMap<ScriptBindingInfo>;
	public var functions(default, null):StringMap<ScriptFunctionDecl>;
	public var exprs(default, null):IntMap<ScriptExpr>;
	public var exprTypes(default, null):IntMap<ScriptType>;
	public var values(default, null):IntMap<ScriptValueDecl>;
	public var assigns(default, null):IntMap<ScriptAssign>;

	public function new(
		name:String,
		program:ScriptProgram,
		imports:StringMap<String>,
		exports:StringMap<ScriptBindingInfo>,
		functions:StringMap<ScriptFunctionDecl>,
		exprs:IntMap<ScriptExpr>,
		exprTypes:IntMap<ScriptType>,
		values:IntMap<ScriptValueDecl>,
		assigns:IntMap<ScriptAssign>
	) {
		this.name = name;
		this.program = program;
		this.imports = imports;
		this.exports = exports;
		this.functions = functions;
		this.exprs = exprs;
		this.exprTypes = exprTypes;
		this.values = values;
		this.assigns = assigns;
	}
}

class ScriptProjectInfo {
	public var project(default, null):ScriptProject;
	public var modules(default, null):StringMap<ScriptModuleInfo>;
	public var structs(default, null):StringMap<ScriptStructInfo>;
	public var enums(default, null):StringMap<ScriptEnumInfo>;
	public var moduleOrder(default, null):Array<String>;
	public var sourceMap(default, null):ScriptSourceMap;
	public var snapshotSchema(default, null):String;

	public function new(
		project:ScriptProject,
		modules:StringMap<ScriptModuleInfo>,
		structs:StringMap<ScriptStructInfo>,
		enums:StringMap<ScriptEnumInfo>,
		moduleOrder:Array<String>,
		sourceMap:ScriptSourceMap
	) {
		this.project = project;
		this.modules = modules;
		this.structs = structs;
		this.enums = enums;
		this.moduleOrder = moduleOrder;
		this.sourceMap = sourceMap;
		this.snapshotSchema = ScriptProjectInfoTools.buildSnapshotSchema(this);
	}
}

class ScriptProjectLoader {
	public static function parseSources(inputs:Array<ScriptSourceInput>):ScriptProject {
		var modules = new StringMap<ScriptProgram>();
		var sourceMap = new ScriptSourceMap();

		for (input in inputs) {
			sourceMap.add(input.sourceName, input.source);
			var program = ScriptParser.parseSource(input.sourceName, input.source);

			if (program.moduleName == null) {
				throw new ScriptError("Every project source must declare a module.", program.span);
			}

			var moduleName = program.moduleName.join(".");

			if (modules.exists(moduleName)) {
				throw new ScriptError("Duplicate module '" + moduleName + "'.", program.span);
			}

			modules.set(moduleName, program);
		}

		return new ScriptProject(modules, sourceMap);
	}

	public static function loadDirectory(root:String, ?extension:String = ".nvsl"):ScriptProject {
		var sources:Array<ScriptSourceInput> = [];
		collectSources(root, root, extension, sources);
		return parseSources(sources);
	}

	static function collectSources(root:String, current:String, extension:String, output:Array<ScriptSourceInput>):Void {
		var names = FileSystem.readDirectory(current);
		names.sort(compareStrings);

		for (name in names) {
			var fullPath = current + "/" + name;

			if (FileSystem.isDirectory(fullPath)) {
				collectSources(root, fullPath, extension, output);
				continue;
			}

			if (!StringTools.endsWith(name, extension)) {
				continue;
			}

			var relative = fullPath.substr(root.length + 1);
			output.push({
				sourceName: relative,
				source: File.getContent(fullPath),
			});
		}
	}

	public static function compareStrings(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}

class ScriptProjectInfoTools {
	public static function buildSnapshotSchema(info:ScriptProjectInfo):String {
		var parts:Array<String> = [];

		for (moduleName in info.moduleOrder) {
			var moduleInfo = info.modules.get(moduleName);
			var exportNames = [for (name => binding in moduleInfo.exports) if (binding.mutable && ScriptTypeTools.isSerializable(binding.type)) name];
			exportNames.sort(ScriptProjectLoader.compareStrings);
			var exportParts = [for (name in exportNames) name + ":" + ScriptTypeTools.format(moduleInfo.exports.get(name).type)];
			parts.push("module " + moduleName + " {" + exportParts.join(",") + "}");
		}

		var structNames = [for (name => _ in info.structs) name];
		structNames.sort(ScriptProjectLoader.compareStrings);

		for (qualifiedName in structNames) {
			var structInfo = info.structs.get(qualifiedName);
			var fieldParts = [for (fieldName in structInfo.fieldOrder) fieldName + ":" + ScriptTypeTools.format(structInfo.fields.get(fieldName))];
			parts.push("struct " + qualifiedName + " {" + fieldParts.join(",") + "}");
		}

		var enumNames = [for (name => _ in info.enums) name];
		enumNames.sort(ScriptProjectLoader.compareStrings);

		for (qualifiedName in enumNames) {
			var enumInfo = info.enums.get(qualifiedName);
			parts.push("enum " + qualifiedName + " {" + enumInfo.caseOrder.join(",") + "}");
		}

		return parts.join("\n");
	}
}

class ScriptModuleIndex {
	public var functions(default, null):StringMap<ScriptFunctionDecl>;
	public var exprs(default, null):IntMap<ScriptExpr>;
	public var values(default, null):IntMap<ScriptValueDecl>;
	public var assigns(default, null):IntMap<ScriptAssign>;

	public function new(
		functions:StringMap<ScriptFunctionDecl>,
		exprs:IntMap<ScriptExpr>,
		values:IntMap<ScriptValueDecl>,
		assigns:IntMap<ScriptAssign>
	) {
		this.functions = functions;
		this.exprs = exprs;
		this.values = values;
		this.assigns = assigns;
	}
}

class ScriptModuleIndexer {
	public static function build(program:ScriptProgram):ScriptModuleIndex {
		var functions = new StringMap<ScriptFunctionDecl>();
		var exprs = new IntMap<ScriptExpr>();
		var values = new IntMap<ScriptValueDecl>();
		var assigns = new IntMap<ScriptAssign>();

		for (decl in program.declarations) {
			switch decl {
				case DFunction(fnDecl):
					functions.set(fnDecl.name, fnDecl);
					indexExpr(fnDecl.body, exprs, values, assigns);
				case DValue(valueDecl):
					values.set(valueDecl.id, valueDecl);
					indexExpr(valueDecl.value, exprs, values, assigns);
				case DStruct(_) | DEnum(_):
			}
		}

		return new ScriptModuleIndex(functions, exprs, values, assigns);
	}

	static function indexExpr(
		expr:ScriptExpr,
		exprs:IntMap<ScriptExpr>,
		values:IntMap<ScriptValueDecl>,
		assigns:IntMap<ScriptAssign>
	):Void {
		exprs.set(expr.id, expr);

		switch expr.def {
			case EInt(_) | EFloat(_) | EString(_) | EBool(_) | EPath(_):
			case EList(elements):
				for (element in elements) {
					indexExpr(element, exprs, values, assigns);
				}
			case ERecord(_, fields):
				for (field in fields) {
					indexExpr(field.value, exprs, values, assigns);
				}
			case ELambda(_, _, body):
				indexExpr(body, exprs, values, assigns);
			case ECall(callee, args):
				indexExpr(callee, exprs, values, assigns);
				for (arg in args) {
					indexExpr(arg, exprs, values, assigns);
				}
			case EField(target, _):
				indexExpr(target, exprs, values, assigns);
			case EIndex(target, index):
				indexExpr(target, exprs, values, assigns);
				indexExpr(index, exprs, values, assigns);
			case EUnary(_, inner):
				indexExpr(inner, exprs, values, assigns);
			case EBinary(_, left, right):
				indexExpr(left, exprs, values, assigns);
				indexExpr(right, exprs, values, assigns);
			case EIf(condition, thenBranch, elseBranch):
				indexExpr(condition, exprs, values, assigns);
				indexExpr(thenBranch, exprs, values, assigns);
				indexExpr(elseBranch, exprs, values, assigns);
			case EBlock(statements, tail):
				indexStatements(statements, exprs, values, assigns);
				if (tail != null) {
					indexExpr(tail, exprs, values, assigns);
				}
		}
	}

	static function indexStatements(
		statements:Array<ScriptStmt>,
		exprs:IntMap<ScriptExpr>,
		values:IntMap<ScriptValueDecl>,
		assigns:IntMap<ScriptAssign>
	):Void {
		for (statement in statements) {
			switch statement {
				case SLet(binding):
					values.set(binding.id, binding);
					indexExpr(binding.value, exprs, values, assigns);
				case SSet(assign):
					assigns.set(assign.id, assign);
					indexExpr(assign.value, exprs, values, assigns);
				case SExpr(expr):
					indexExpr(expr, exprs, values, assigns);
			}
		}
	}
}
