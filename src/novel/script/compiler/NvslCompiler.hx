package novel.script.compiler;

import haxe.ds.StringMap;
import novel.script.ScriptError;
import novel.script.bytecode.Nvbc.NvbcEnumType;
import novel.script.bytecode.Nvbc.NvbcFunction;
import novel.script.bytecode.Nvbc.NvbcGlobal;
import novel.script.bytecode.Nvbc.NvbcModule;
import novel.script.bytecode.Nvbc.NvbcOp;
import novel.script.bytecode.Nvbc.NvbcProgram;
import novel.script.bytecode.Nvbc.NvbcStructType;
import novel.script.project.ScriptLinker;
import novel.script.project.ScriptProject.ScriptEnumInfo;
import novel.script.project.ScriptProject.ScriptModuleInfo;
import novel.script.project.ScriptProject.ScriptProject;
import novel.script.project.ScriptProject.ScriptProjectInfo;
import novel.script.project.ScriptProject.ScriptProjectLoader;
import novel.script.project.ScriptProject.ScriptSourceInput;
import novel.script.semantics.ScriptChecker;
import novel.script.semantics.ScriptType;
import novel.script.runtime.ScriptHost;
import novel.script.semantics.ScriptType.ScriptTypeTools;
import novel.script.syntax.ScriptAst.ScriptBinaryOp;
import novel.script.syntax.ScriptAst.ScriptDecl;
import novel.script.syntax.ScriptAst.ScriptExpr;
import novel.script.syntax.ScriptAst.ScriptExprDef;
import novel.script.syntax.ScriptAst.ScriptFunctionDecl;
import novel.script.syntax.ScriptAst.ScriptPath;
import novel.script.syntax.ScriptAst.ScriptStmt;
import novel.script.syntax.ScriptAst.ScriptTypeRef;
import novel.script.syntax.ScriptAst.ScriptUnaryOp;
import novel.script.syntax.ScriptAst.ScriptValueDecl;
import novel.script.syntax.ScriptSpan;

class NvslCompiler {
	public static function compileProject(
		project:ScriptProject,
		?defaultEntryModule:String,
		?defaultEntryExport:String = "main"
	):NvbcProgram {
		return compileInfo(ScriptChecker.checkProject(project), defaultEntryModule, defaultEntryExport);
	}

	public static function compileSources(
		inputs:Array<ScriptSourceInput>,
		?defaultEntryModule:String,
		?defaultEntryExport:String = "main"
	):NvbcProgram {
		return compileProject(ScriptProjectLoader.parseSources(inputs), defaultEntryModule, defaultEntryExport);
	}

	public static function compileDirectory(
		root:String,
		?extension:String = ".nvsl",
		?defaultEntryModule:String,
		?defaultEntryExport:String = "main"
	):NvbcProgram {
		return compileProject(ScriptProjectLoader.loadDirectory(root, extension), defaultEntryModule, defaultEntryExport);
	}

	public static function compileInfo(
		info:ScriptProjectInfo,
		?defaultEntryModule:String,
		?defaultEntryExport:String = "main"
	):NvbcProgram {
		if (defaultEntryModule != null) {
			ScriptLinker.resolveFunctionEntrypoint(info, defaultEntryModule, defaultEntryExport);
		}

		return new NvslProjectCompiler(info, defaultEntryModule, defaultEntryExport).compile();
	}
}

private class NvslProjectCompiler {
	var info:ScriptProjectInfo;
	var defaultEntryModule:Null<String>;
	var defaultEntryExport:Null<String>;
	var currentFunctions:Null<StringMap<NvbcFunction>>;
	var currentLambdaCounter:Int;

	public function new(info:ScriptProjectInfo, defaultEntryModule:Null<String>, defaultEntryExport:Null<String>) {
		this.info = info;
		this.defaultEntryModule = defaultEntryModule;
		this.defaultEntryExport = defaultEntryModule == null ? null : defaultEntryExport;
		this.currentFunctions = null;
		this.currentLambdaCounter = 0;
	}

	public function compile():NvbcProgram {
		var modules = new StringMap<NvbcModule>();
		var structs = new StringMap<NvbcStructType>();
		var enums = new StringMap<NvbcEnumType>();

		for (qualifiedName => structInfo in info.structs) {
			structs.set(qualifiedName, new NvbcStructType(qualifiedName, structInfo.fieldOrder.copy()));
		}

		for (qualifiedName => enumInfo in info.enums) {
			enums.set(qualifiedName, new NvbcEnumType(qualifiedName, enumInfo.caseOrder.copy()));
		}

		for (moduleName in info.moduleOrder) {
			var moduleInfo = info.modules.get(moduleName);
			modules.set(moduleName, compileModule(moduleInfo));
		}

		return new NvbcProgram(
			modules,
			structs,
			enums,
			info.moduleOrder.copy(),
			info.snapshotSchema,
			defaultEntryModule,
			defaultEntryExport
		);
	}

	function compileModule(moduleInfo:ScriptModuleInfo):NvbcModule {
		var globals:Array<NvbcGlobal> = [];
		var functions = new StringMap<NvbcFunction>();
		currentFunctions = functions;
		currentLambdaCounter = 0;

		for (decl in moduleInfo.program.declarations) {
			switch decl {
				case DFunction(fnDecl):
					functions.set(fnDecl.name, compileFunction(moduleInfo, fnDecl));
				case DValue(valueDecl):
					globals.push(compileGlobal(moduleInfo, valueDecl));
				case DStruct(_) | DEnum(_):
			}
		}

		currentFunctions = null;
		return new NvbcModule(moduleInfo.name, globals, functions);
	}

	function compileGlobal(moduleInfo:ScriptModuleInfo, valueDecl:ScriptValueDecl):NvbcGlobal {
		var binding = moduleInfo.exports.get(valueDecl.name);
		var emitter = new NvslEmitter();
		compileExpr(valueDecl.value, moduleInfo, new NvslLocalScope(), emitter);
		emitter.emit(Return);
		return new NvbcGlobal(valueDecl.name, binding.type, binding.mutable, emitter.code);
	}

	function compileFunction(moduleInfo:ScriptModuleInfo, fnDecl:ScriptFunctionDecl):NvbcFunction {
		var binding = moduleInfo.exports.get(fnDecl.name);
		var fnType = binding.type;
		return compileFunctionBody(
			moduleInfo,
			fnDecl.name,
			true,
			[for (param in fnDecl.params) param.name],
			extractFunctionParams(fnType),
			extractFunctionReturn(fnType),
			fnDecl.body,
			new NvslLocalScope()
		);
	}

	function compileExpr(expr:ScriptExpr, moduleInfo:ScriptModuleInfo, scope:NvslLocalScope, emitter:NvslEmitter):Void {
		switch expr.def {
			case EInt(value):
				emitter.emit(PushInt(value));
			case EFloat(value):
				emitter.emit(PushFloat(value));
			case EString(value):
				emitter.emit(PushString(value));
			case EBool(value):
				emitter.emit(PushBool(value));
			case EPath(path):
				compilePathExpr(path, moduleInfo, scope, emitter, expr.span);
			case EList(elements):
				for (element in elements) {
					compileExpr(element, moduleInfo, scope, emitter);
				}
				emitter.emit(MakeList(elements.length));
			case ERecord(typePath, fields):
				for (field in fields) {
					compileExpr(field.value, moduleInfo, scope, emitter);
				}
				emitter.emit(MakeRecord(resolveRecordTypeName(moduleInfo, typePath, expr.span), [for (field in fields) field.name]));
			case ELambda(params, _, body):
				var lambdaType = getExprType(moduleInfo, expr.id);
				var lambdaName = nextLambdaName();
				var lambdaScope = new NvslLocalScope(scope);

				currentFunctions.set(
					lambdaName,
					compileFunctionBody(
						moduleInfo,
						lambdaName,
						false,
						[for (param in params) param.name],
						extractFunctionParams(lambdaType),
						extractFunctionReturn(lambdaType),
						body,
						lambdaScope
					)
				);
				emitter.emit(MakeClosure(moduleInfo.name, lambdaName));
			case ECall(callee, args):
				compileCallExpr(callee, args, moduleInfo, scope, emitter, expr.span);
			case EField(target, name):
				compileExpr(target, moduleInfo, scope, emitter);
				emitter.emit(GetField(name));
			case EIndex(target, index):
				compileExpr(target, moduleInfo, scope, emitter);
				compileExpr(index, moduleInfo, scope, emitter);
				emitter.emit(GetIndex);
			case EUnary(op, inner):
				compileExpr(inner, moduleInfo, scope, emitter);
				emitter.emit(Unary(op));
			case EBinary(op, left, right):
				compileExpr(left, moduleInfo, scope, emitter);
				compileExpr(right, moduleInfo, scope, emitter);
				emitter.emit(Binary(op));
			case EIf(condition, thenBranch, elseBranch):
				compileExpr(condition, moduleInfo, scope, emitter);
				var falseJump = emitter.emit(JumpIfFalse(-1));
				compileExpr(thenBranch, moduleInfo, scope, emitter);
				var endJump = emitter.emit(Jump(-1));
				var elseStart = emitter.position();
				emitter.patch(falseJump, JumpIfFalse(elseStart));
				compileExpr(elseBranch, moduleInfo, scope, emitter);
				emitter.patch(endJump, Jump(emitter.position()));
			case EBlock(statements, tail):
				compileBlock(statements, tail, moduleInfo, scope, emitter);
		}
	}

	function compileBlock(
		statements:Array<ScriptStmt>,
		tail:Null<ScriptExpr>,
		moduleInfo:ScriptModuleInfo,
		scope:NvslLocalScope,
		emitter:NvslEmitter
	):Void {
		var blockScope = new NvslLocalScope(scope);
		emitter.emit(EnterScope);

		for (statement in statements) {
			switch statement {
				case SLet(binding):
					compileExpr(binding.value, moduleInfo, blockScope, emitter);
					emitter.emit(DefineLocal(binding.name, resolveBindingType(moduleInfo, binding)));
					blockScope.define(binding.name);
				case SSet(assign):
					if (assign.target.length != 1) {
						throw new ScriptError("NVBC assignments only support simple identifiers.", assign.span);
					}

					compileExpr(assign.value, moduleInfo, blockScope, emitter);
					if (blockScope.exists(assign.target[0])) {
						emitter.emit(StoreLocal(assign.target[0]));
					} else {
						if (!moduleInfo.exports.exists(assign.target[0])) {
							throw new ScriptError("Unknown assignment target '" + assign.target[0] + "'.", assign.span);
						}

						emitter.emit(StoreGlobal(moduleInfo.name, assign.target[0]));
					}
				case SExpr(statementExpr):
					compileExpr(statementExpr, moduleInfo, blockScope, emitter);
					emitter.emit(Pop);
			}
		}

		if (tail == null) {
			emitter.emit(PushVoid);
		} else {
			compileExpr(tail, moduleInfo, blockScope, emitter);
		}

		emitter.emit(ExitScope);
	}

	function compilePathExpr(
		path:ScriptPath,
		moduleInfo:ScriptModuleInfo,
		scope:NvslLocalScope,
		emitter:NvslEmitter,
		span:ScriptSpan
	):Void {
		switch resolveValueTarget(path, moduleInfo, scope, span) {
			case Local(name, fields):
				emitter.emit(LoadLocal(name));
				emitFieldChain(fields, emitter);
			case Global(moduleName, name, fields):
				emitter.emit(LoadGlobal(moduleName, name));
				emitFieldChain(fields, emitter);
			case EnumValue(typeName, caseName):
				emitter.emit(PushEnum(typeName, caseName));
			case FunctionValue(moduleName, name):
				emitter.emit(LoadGlobal(moduleName, name));
			case BuiltinValue(name):
				emitter.emit(LoadGlobal(moduleInfo.name, name));
		}
	}

	function compileCallExpr(
		callee:ScriptExpr,
		args:Array<ScriptExpr>,
		moduleInfo:ScriptModuleInfo,
		scope:NvslLocalScope,
		emitter:NvslEmitter,
		span:ScriptSpan
	):Void {
		var direct = switch callee.def {
			case EPath(path):
				resolveDirectCallTarget(path, moduleInfo, scope);
			default:
				null;
		};

		if (direct != null) {
			for (arg in args) {
				compileExpr(arg, moduleInfo, scope, emitter);
			}

			switch direct {
				case Builtin(name):
					emitter.emit(CallBuiltin(name, args.length));
				case Function(moduleName, name):
					emitter.emit(CallFunction(moduleName, name, args.length));
			}
			return;
		}

		compileExpr(callee, moduleInfo, scope, emitter);
		for (arg in args) {
			compileExpr(arg, moduleInfo, scope, emitter);
		}
		emitter.emit(CallValue(args.length));
	}

	function emitFieldChain(fields:Array<String>, emitter:NvslEmitter):Void {
		for (fieldName in fields) {
			emitter.emit(GetField(fieldName));
		}
	}

	function resolveValueTarget(
		path:ScriptPath,
		moduleInfo:ScriptModuleInfo,
		scope:NvslLocalScope,
		span:ScriptSpan
	):NvslValueTarget {
		if (path.length == 0) {
			throw new ScriptError("Expected a value path.", span);
		}

		if (scope.exists(path[0])) {
			return Local(path[0], path.slice(1));
		}

		if (path.length == 2) {
			var localEnumName = moduleInfo.name + "." + path[0];
			var localEnum = info.enums.get(localEnumName);

			if (localEnum != null && localEnum.cases.exists(path[1])) {
				return EnumValue(localEnumName, path[1]);
			}
		}

		if (path.length >= 2) {
			var builtinName = path.join(".");

			if (ScriptHost.has(builtinName)) {
				return BuiltinValue(builtinName);
			}
		}

		var localExport = moduleInfo.exports.get(path[0]);

		if (localExport != null) {
			return switch localExport.type {
				case TFunction(_, _):
					FunctionValue(moduleInfo.name, path[0]);
				default:
					Global(moduleInfo.name, path[0], path.slice(1));
			};
		}

		var moduleTarget = resolveModuleReference(moduleInfo, path);

		if (moduleTarget != null) {
			return resolveModuleValueTarget(moduleTarget.moduleName, moduleTarget.remainder, span);
		}

		throw new ScriptError("Unknown value '" + path.join(".") + "'.", span);
	}

	function resolveModuleValueTarget(moduleName:String, remainder:ScriptPath, span:ScriptSpan):NvslValueTarget {
		if (remainder.length == 0) {
			throw new ScriptError("Module '" + moduleName + "' is not a value.", span);
		}

		var moduleInfo = info.modules.get(moduleName);
		var exportBinding = moduleInfo.exports.get(remainder[0]);

		if (exportBinding != null) {
			return switch exportBinding.type {
				case TFunction(_, _):
					FunctionValue(moduleName, remainder[0]);
				default:
					Global(moduleName, remainder[0], remainder.slice(1));
			};
		}

		if (remainder.length == 2) {
			var enumName = moduleName + "." + remainder[0];
			var enumInfo = info.enums.get(enumName);

			if (enumInfo != null && enumInfo.cases.exists(remainder[1])) {
				return EnumValue(enumName, remainder[1]);
			}
		}

		throw new ScriptError("Unknown module value '" + moduleName + "." + remainder.join(".") + "'.", span);
	}

	function resolveDirectCallTarget(
		path:ScriptPath,
		moduleInfo:ScriptModuleInfo,
		scope:NvslLocalScope
	):Null<NvslCallTarget> {
		if (path.length == 0) {
			return null;
		}

		if (scope.exists(path[0])) {
			return null;
		}

		if (path.length >= 2) {
			var builtinName = path.join(".");

			if (ScriptHost.has(builtinName)) {
				return Builtin(builtinName);
			}
		}

		if (path.length == 1 && moduleInfo.functions.exists(path[0])) {
			return Function(moduleInfo.name, path[0]);
		}

		var moduleTarget = resolveModuleReference(moduleInfo, path);

		if (moduleTarget != null && moduleTarget.remainder.length == 1) {
			var targetModule = info.modules.get(moduleTarget.moduleName);

			if (targetModule.functions.exists(moduleTarget.remainder[0])) {
				return Function(moduleTarget.moduleName, moduleTarget.remainder[0]);
			}
		}

		return null;
	}

	function compileFunctionBody(
		moduleInfo:ScriptModuleInfo,
		name:String,
		exposed:Bool,
		paramNames:Array<String>,
		paramTypes:Array<ScriptType>,
		returnType:ScriptType,
		body:ScriptExpr,
		scope:NvslLocalScope
	):NvbcFunction {
		var emitter = new NvslEmitter();

		for (paramName in paramNames) {
			scope.define(paramName);
		}

		compileExpr(body, moduleInfo, scope, emitter);
		emitter.emit(Return);

		return new NvbcFunction(moduleInfo.name, name, exposed, paramNames, paramTypes, returnType, emitter.code);
	}

	function nextLambdaName():String {
		if (currentFunctions == null) {
			throw new ScriptError("NVSL compiler lost its active function table.");
		}

		var name = "__nvsl_lambda$" + currentLambdaCounter;

		while (currentFunctions.exists(name)) {
			currentLambdaCounter++;
			name = "__nvsl_lambda$" + currentLambdaCounter;
		}

		currentLambdaCounter++;
		return name;
	}

	function getExprType(moduleInfo:ScriptModuleInfo, exprId:Int):ScriptType {
		var exprType = moduleInfo.exprTypes.get(exprId);

		if (exprType == null) {
			throw new ScriptError("Missing checked expression type for id '" + exprId + "' in module '" + moduleInfo.name + "'.");
		}

		return exprType;
	}

	function resolveBindingType(moduleInfo:ScriptModuleInfo, binding:ScriptValueDecl):ScriptType {
		return binding.type == null ? getExprType(moduleInfo, binding.value.id) : resolveTypeRef(moduleInfo, binding.type);
	}

	function resolveModuleReference(moduleInfo:ScriptModuleInfo, path:ScriptPath):Null<{ moduleName:String, remainder:ScriptPath }> {
		if (path.length >= 2) {
			var imported = moduleInfo.imports.get(path[0]);

			if (imported != null) {
				return { moduleName: imported, remainder: path.slice(1) };
			}
		}

		for (prefixLength in 1...path.length) {
			var moduleName = path.slice(0, prefixLength).join(".");

			if (info.modules.exists(moduleName)) {
				return { moduleName: moduleName, remainder: path.slice(prefixLength) };
			}
		}

		return null;
	}

	function resolveRecordTypeName(moduleInfo:ScriptModuleInfo, path:ScriptPath, span:ScriptSpan):String {
		return switch resolveNamedType(moduleInfo, path, span) {
			case TRecord(name):
				name;
			default:
				throw new ScriptError("Record literals require a struct type.", span);
		};
	}

	function resolveNamedType(moduleInfo:ScriptModuleInfo, path:ScriptPath, span:ScriptSpan):ScriptType {
		if (path.length == 1) {
			var localType = moduleInfo.name + "." + path[0];

			if (info.structs.exists(localType)) {
				return TRecord(localType);
			}

			if (info.enums.exists(localType)) {
				return TEnum(localType);
			}
		}

		var imported = moduleInfo.imports.get(path[0]);

		if (imported != null) {
			var importedName = imported + "." + path.slice(1).join(".");

			if (info.structs.exists(importedName)) {
				return TRecord(importedName);
			}

			if (info.enums.exists(importedName)) {
				return TEnum(importedName);
			}
		}

		var qualified = path.join(".");

		if (info.structs.exists(qualified)) {
			return TRecord(qualified);
		}

		if (info.enums.exists(qualified)) {
			return TEnum(qualified);
		}

		throw new ScriptError("Unknown type '" + qualified + "'.", span);
	}

	function resolveTypeRef(moduleInfo:ScriptModuleInfo, typeRef:ScriptTypeRef):ScriptType {
		if (typeRef.path.length == 1) {
			return switch typeRef.path[0] {
				case "Void":
					requireTypeArgs(typeRef, 0);
					TVoid;
				case "Int":
					requireTypeArgs(typeRef, 0);
					TInt;
				case "Float":
					requireTypeArgs(typeRef, 0);
					TFloat;
				case "String":
					requireTypeArgs(typeRef, 0);
					TString;
				case "Bool":
					requireTypeArgs(typeRef, 0);
					TBool;
				case "List":
					requireTypeArgs(typeRef, 1);
					TList(resolveTypeRef(moduleInfo, typeRef.args[0]));
				default:
					resolveNamedType(moduleInfo, typeRef.path, typeRef.span);
			};
		}

		return resolveNamedType(moduleInfo, typeRef.path, typeRef.span);
	}

	function requireTypeArgs(typeRef:ScriptTypeRef, expected:Int):Void {
		if (typeRef.args.length != expected) {
			throw new ScriptError("Type '" + typeRef.path.join(".") + "' expects " + expected + " type arguments.", typeRef.span);
		}
	}

	function extractFunctionParams(type:ScriptType):Array<ScriptType> {
		return switch type {
			case TFunction(paramTypes, _):
				paramTypes;
			default:
				throw new ScriptError("Expected a function type.");
		};
	}

	function extractFunctionReturn(type:ScriptType):ScriptType {
		return switch type {
			case TFunction(_, returnType):
				returnType;
			default:
				throw new ScriptError("Expected a function type.");
		};
	}
}

private class NvslEmitter {
	public var code(default, null):Array<NvbcOp>;

	public function new() {
		this.code = [];
	}

	public function emit(op:NvbcOp):Int {
		code.push(op);
		return code.length - 1;
	}

	public function patch(index:Int, op:NvbcOp):Void {
		code[index] = op;
	}

	public function position():Int {
		return code.length;
	}
}

private class NvslLocalScope {
	var parent:Null<NvslLocalScope>;
	var names:StringMap<Bool>;

	public function new(?parent:NvslLocalScope) {
		this.parent = parent;
		this.names = new StringMap();
	}

	public function define(name:String):Void {
		names.set(name, true);
	}

	public function exists(name:String):Bool {
		var current:Null<NvslLocalScope> = this;

		while (current != null) {
			if (current.names.exists(name)) {
				return true;
			}

			current = current.parent;
		}

		return false;
	}
}

private enum NvslValueTarget {
	Local(name:String, fields:Array<String>);
	Global(moduleName:String, name:String, fields:Array<String>);
	EnumValue(typeName:String, caseName:String);
	FunctionValue(moduleName:String, name:String);
	BuiltinValue(name:String);
}

private enum NvslCallTarget {
	Builtin(name:String);
	Function(moduleName:String, name:String);
}
