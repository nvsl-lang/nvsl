package novel.script.runtime;

import haxe.ds.IntMap;
import haxe.ds.ObjectMap;
import haxe.ds.StringMap;
import novel.script.ScriptError;
import novel.script.semantics.ScriptChecker;
import novel.script.syntax.ScriptAst.ScriptAssign;
import novel.script.syntax.ScriptAst.ScriptBinaryOp;
import novel.script.syntax.ScriptAst.ScriptDecl;
import novel.script.syntax.ScriptAst.ScriptExpr;
import novel.script.syntax.ScriptAst.ScriptExprDef;
import novel.script.syntax.ScriptAst.ScriptFunctionDecl;
import novel.script.syntax.ScriptAst.ScriptPath;
import novel.script.syntax.ScriptAst.ScriptProgram;
import novel.script.syntax.ScriptAst.ScriptRecordFieldInit;
import novel.script.syntax.ScriptAst.ScriptStmt;
import novel.script.syntax.ScriptAst.ScriptTypeRef;
import novel.script.syntax.ScriptAst.ScriptUnaryOp;
import novel.script.syntax.ScriptAst.ScriptValueDecl;
import novel.script.syntax.ScriptSpan;
import novel.script.runtime.ScriptExecOp;
import novel.script.project.ScriptProject.ScriptModuleInfo;
import novel.script.project.ScriptProject.ScriptProject;
import novel.script.project.ScriptProject.ScriptProjectInfo;
import novel.script.project.ScriptProject.ScriptSourceMap;
import novel.script.runtime.ScriptSnapshot.ScriptCellSnapshotEntry;
import novel.script.runtime.ScriptSnapshot.ScriptExecutionEnvSnapshotEntry;
import novel.script.runtime.ScriptSnapshot.ScriptExecutionSnapshotPayload;
import novel.script.runtime.ScriptSnapshot.ScriptFrameSnapshotEntry;
import novel.script.runtime.ScriptSnapshot.ScriptProjectSnapshotPayload;
import novel.script.runtime.ScriptSnapshot.ScriptScopeSnapshotEntry;
import novel.script.runtime.ScriptSnapshot.ScriptSnapshotCodec;
import novel.script.semantics.ScriptType;
import novel.script.semantics.ScriptType.ScriptTypeTools;
import novel.script.runtime.ScriptValue;
import novel.script.runtime.ScriptValue.ScriptValueTools;

class ScriptModuleInstance {
	public var name(default, null):String;
	public var info(default, null):ScriptModuleInfo;
	public var env(default, null):ScriptEnv;

	var runtime:ScriptProjectRuntime;

	public function new(name:String, info:ScriptModuleInfo, env:ScriptEnv, runtime:ScriptProjectRuntime) {
		this.name = name;
		this.info = info;
		this.env = env;
		this.runtime = runtime;
	}

	public function getGlobal(name:String):ScriptValue {
		return env.get(name, info.program.span);
	}

	public function call(name:String, args:Array<ScriptValue>):ScriptValue {
		var value = env.get(name, info.program.span);
		return runtime.callValue(value, args, info.program.span);
	}
}

class ScriptProjectInstance {
	public var info(default, null):ScriptProjectInfo;
	public var modules(default, null):StringMap<ScriptModuleInstance>;

	var runtime:ScriptProjectRuntime;

	public function new(info:ScriptProjectInfo, modules:StringMap<ScriptModuleInstance>, runtime:ScriptProjectRuntime) {
		this.info = info;
		this.modules = modules;
		this.runtime = runtime;
	}

	public function getModule(name:String):ScriptModuleInstance {
		var module = modules.get(name);

		if (module == null) {
			throw new ScriptError("Unknown runtime module '" + name + "'.");
		}

		return module;
	}

	public function call(moduleName:String, exportName:String, args:Array<ScriptValue>):ScriptValue {
		return getModule(moduleName).call(exportName, args);
	}

	public function beginExecution(moduleName:String, exportName:String, args:Array<ScriptValue>):ScriptExecution {
		return runtime.beginExecution(moduleName, exportName, args);
	}

	public function createSnapshotData():ScriptProjectSnapshotPayload {
		return runtime.createSnapshotData();
	}

	public function createSnapshot():String {
		return ScriptSnapshotCodec.stringify(createSnapshotData());
	}

	public function restoreSnapshotData(payload:ScriptProjectSnapshotPayload):Void {
		runtime.restoreSnapshotData(payload);
	}

	public function restoreSnapshot(json:String):Void {
		restoreSnapshotData(ScriptSnapshotCodec.decodeProjectSnapshot(ScriptSnapshotCodec.parse(json)));
	}

	public function restoreExecutionSnapshotData(payload:ScriptExecutionSnapshotPayload):ScriptExecution {
		return runtime.restoreExecutionSnapshotData(payload);
	}

	public function restoreExecutionSnapshot(json:String):ScriptExecution {
		return restoreExecutionSnapshotData(ScriptSnapshotCodec.decodeExecutionSnapshot(ScriptSnapshotCodec.parse(json)));
	}
}

class ScriptInterpreter {
	public static function load(program:ScriptProgram):ScriptModuleInstance {
		var sourceMap = new ScriptSourceMap();
		sourceMap.add(program.span.sourceName, program.sourceText);
		var moduleName = program.moduleName == null ? ["__main__"] : program.moduleName;
		var wrapped = new ScriptProgram(moduleName, program.imports, program.declarations, program.span, program.sourceText);
		var modules = new StringMap<ScriptProgram>();
		var name = moduleName.join(".");
		modules.set(name, wrapped);
		var project = new ScriptProject(modules, sourceMap);
		return loadProject(project).getModule(name);
	}

	public static function loadProject(project:ScriptProject):ScriptProjectInstance {
		var info = ScriptChecker.checkProject(project);
		return loadInfo(info);
	}

	public static function loadInfo(info:ScriptProjectInfo):ScriptProjectInstance {
		return new ScriptProjectRuntime(info).load();
	}
}

private class ScriptProjectRuntime {
	var info:ScriptProjectInfo;
	var modules:StringMap<ScriptModuleInstance>;

	public function new(info:ScriptProjectInfo) {
		this.info = info;
		this.modules = new StringMap();
	}

	public function load():ScriptProjectInstance {
		createModuleEnvs();
		predeclareExports();
		evaluateTopLevelValues();
		return new ScriptProjectInstance(info, modules, this);
	}

	public function callValue(value:ScriptValue, args:Array<ScriptValue>, span:ScriptSpan):ScriptValue {
		return switch value {
			case VBuiltin(name):
				ScriptBuiltins.invoke(name, args, span);
			case VClosure(closure):
				callClosure(closure, args, span);
			default:
				throw new ScriptError("Cannot call non-function value " + ScriptValueTools.format(value) + ".", span);
		};
	}

	public function beginExecution(moduleName:String, exportName:String, args:Array<ScriptValue>):ScriptExecution {
		var module = modules.get(moduleName);

		if (module == null) {
			throw new ScriptError("Unknown runtime module '" + moduleName + "'.");
		}

		var value = module.env.get(exportName, module.info.program.span);
		var frame = createExecutionFrame(value, args, module.info.program.span);
		return new ScriptExecution(this, [frame]);
	}

	public function createSnapshotData():ScriptProjectSnapshotPayload {
		var moduleEntries:Array<Dynamic> = [];

		for (moduleName in info.moduleOrder) {
			var module = modules.get(moduleName);
			var values = {};

			for (exportName => binding in module.info.exports) {
				if (!binding.mutable) {
					continue;
				}

				var cell = module.env.resolveLocal(exportName);

				if (cell == null) {
					continue;
				}

				if (cell.initialized && !ScriptValueTools.isSerializable(cell.value)) {
					throw new ScriptError("Global '" + moduleName + "." + exportName + "' is not serializable.");
				}

				Reflect.setField(values, exportName, cell.initialized
					? { initialized: true, value: ScriptSnapshotCodec.encodeValue(cell.value) }
					: { initialized: false });
			}

			moduleEntries.push({
				name: moduleName,
				values: values,
			});
		}

		return ScriptSnapshotCodec.encodeProjectSnapshot(info.snapshotSchema, cast moduleEntries);
	}

	public function restoreSnapshotData(payload:ScriptProjectSnapshotPayload):Void {
		if (payload.schema != info.snapshotSchema) {
			throw new ScriptError("Snapshot schema does not match the current project state.");
		}

		var moduleEntries = payload.modules;

		for (entry in moduleEntries) {
			var moduleName:String = Reflect.field(entry, "name");
			var module = modules.get(moduleName);

			if (module == null) {
				throw new ScriptError("Snapshot references unknown module '" + moduleName + "'.");
			}

			var values = Reflect.field(entry, "values");

			for (exportName in Reflect.fields(values)) {
				var cell = module.env.resolveLocal(exportName);

				if (cell == null) {
					throw new ScriptError("Snapshot references unknown global '" + moduleName + "." + exportName + "'.");
				}

				var encodedEntry = Reflect.field(values, exportName);
				var initialized = Reflect.field(encodedEntry, "initialized");

				if (!Std.isOfType(initialized, Bool)) {
					throw new ScriptError("Snapshot entry '" + moduleName + "." + exportName + "' is invalid.");
				}

				if (initialized) {
					cell.restoreValue(ScriptSnapshotCodec.decodeValue(Reflect.field(encodedEntry, "value")), true);
				} else {
					cell.restoreValue(VVoid, false);
				}
			}
		}
	}

	public function restoreExecutionSnapshotData(payload:ScriptExecutionSnapshotPayload):ScriptExecution {
		restoreSnapshotData(payload.project);
		var envs = new IntMap<ScriptEnv>();

		for (envEntry in payload.envs) {
			var parent = envEntry.parentId == null ? getModuleInstance(envEntry.moduleName).env : envs.get(envEntry.parentId);

			if (parent == null) {
				throw new ScriptError("Execution snapshot references unknown parent environment '" + Std.string(envEntry.parentId) + "'.");
			}

			var env = new ScriptEnv(parent);
			envs.set(envEntry.id, env);

			for (cellEntry in envEntry.cells) {
				var value = cellEntry.initialized ? restoreExecutionValue(Reflect.field(cellEntry, "value"), envs) : VVoid;
				env.define(
					cellEntry.name,
					ScriptSnapshotCodec.decodeType(cellEntry.type),
					cellEntry.mutable,
					value,
					cellEntry.initialized
				);
			}
		}

		var frames:Array<ScriptExecutionFrame> = [];

		for (frameEntry in payload.frames) {
			frames.push(restoreExecutionFrame(frameEntry, envs));
		}

		if (frames.length == 0) {
			throw new ScriptError("Execution snapshot does not contain any frames.");
		}

		return new ScriptExecution(this, frames);
	}

	public function getModuleInfo(name:String):ScriptModuleInfo {
		var moduleInfo = info.modules.get(name);

		if (moduleInfo == null) {
			throw new ScriptError("Unknown module '" + name + "'.");
		}

		return moduleInfo;
	}

	public function getModuleInstance(name:String):ScriptModuleInstance {
		var module = modules.get(name);

		if (module == null) {
			throw new ScriptError("Unknown runtime module '" + name + "'.");
		}

		return module;
	}

	public function getExpr(moduleName:String, exprId:Int):ScriptExpr {
		var expr = getModuleInfo(moduleName).exprs.get(exprId);

		if (expr == null) {
			throw new ScriptError("Unknown expression id '" + exprId + "' in module '" + moduleName + "'.");
		}

		return expr;
	}

	public function getExprType(moduleName:String, exprId:Int):ScriptType {
		var exprType = getModuleInfo(moduleName).exprTypes.get(exprId);

		if (exprType == null) {
			throw new ScriptError("Unknown expression type for id '" + exprId + "' in module '" + moduleName + "'.");
		}

		return exprType;
	}

	public function getValueDecl(moduleName:String, valueDeclId:Int):ScriptValueDecl {
		var valueDecl = getModuleInfo(moduleName).values.get(valueDeclId);

		if (valueDecl == null) {
			throw new ScriptError("Unknown binding id '" + valueDeclId + "' in module '" + moduleName + "'.");
		}

		return valueDecl;
	}

	public function getFunctionDecl(moduleName:String, functionName:String):ScriptFunctionDecl {
		var functionDecl = getModuleInfo(moduleName).functions.get(functionName);

		if (functionDecl == null) {
			throw new ScriptError("Unknown function '" + moduleName + "." + functionName + "'.");
		}

		return functionDecl;
	}

	public function getAssign(moduleName:String, assignId:Int):ScriptAssign {
		var assign = getModuleInfo(moduleName).assigns.get(assignId);

		if (assign == null) {
			throw new ScriptError("Unknown assignment id '" + assignId + "' in module '" + moduleName + "'.");
		}

		return assign;
	}

	public function createRecordValue(recordName:String, fieldNames:Array<String>, values:Array<ScriptValue>, span:ScriptSpan):ScriptValue {
		var structInfo = info.structs.get(recordName);

		if (structInfo == null) {
			throw new ScriptError("Unknown struct '" + recordName + "'.", span);
		}

		if (fieldNames.length != values.length) {
			throw new ScriptError("Record build for '" + recordName + "' has mismatched field values.", span);
		}

		var fields = new StringMap<ScriptValue>();

		for (index in 0...fieldNames.length) {
			fields.set(fieldNames[index], values[index]);
		}

		for (fieldName in structInfo.fieldOrder) {
			if (!fields.exists(fieldName)) {
				throw new ScriptError("Missing field '" + fieldName + "' in record literal.", span);
			}
		}

		return VRecord(recordName, fields);
	}

	function restoreExecutionValue(data:Dynamic, envs:IntMap<ScriptEnv>):ScriptValue {
		var kind:String = Reflect.field(data, "kind");

		return switch kind {
			case "builtin":
				var name:Dynamic = Reflect.field(data, "name");

				if (!Std.isOfType(name, String) || !ScriptBuiltins.has(name)) {
					throw new ScriptError("Unknown builtin execution value '" + Std.string(name) + "'.");
				}

				VBuiltin(name);
			case "closure":
				var moduleName:Dynamic = Reflect.field(data, "moduleName");
				var bodyExprId:Dynamic = Reflect.field(data, "bodyExprId");
				var envId:Dynamic = Reflect.field(data, "envId");
				var paramNames:Dynamic = Reflect.field(data, "paramNames");
				var paramTypesData:Dynamic = Reflect.field(data, "paramTypes");
				var returnTypeData:Dynamic = Reflect.field(data, "returnType");
				var closureName:Dynamic = Reflect.field(data, "name");

				if (!Std.isOfType(moduleName, String) || !Std.isOfType(bodyExprId, Int) || !Std.isOfType(paramNames, Array)
					|| !Std.isOfType(paramTypesData, Array)) {
					throw new ScriptError("Invalid closure execution value.");
				}

				var env = envId == null ? getModuleInstance(moduleName).env : envs.get(envId);

				if (env == null) {
					throw new ScriptError("Execution snapshot references unknown closure environment '" + Std.string(envId) + "'.");
				}

				var closure = ScriptClosure.forAst(
					Std.isOfType(closureName, String) ? cast closureName : null,
					moduleName,
					cast paramNames,
					[for (paramType in cast(paramTypesData, Array<Dynamic>)) ScriptSnapshotCodec.decodeType(paramType)],
					returnTypeData == null ? null : ScriptSnapshotCodec.decodeType(returnTypeData),
					getExpr(moduleName, bodyExprId),
					env
				);
				VClosure(closure);
			case "list":
				VList([for (item in cast(Reflect.field(data, "items"), Array<Dynamic>)) restoreExecutionValue(item, envs)]);
			case "record":
				var fields = new StringMap<ScriptValue>();
				var encodedFields = Reflect.field(data, "fields");

				for (fieldName in Reflect.fields(encodedFields)) {
					fields.set(fieldName, restoreExecutionValue(Reflect.field(encodedFields, fieldName), envs));
				}

				VRecord(Reflect.field(data, "type"), fields);
			case "void" | "int" | "float" | "string" | "bool" | "enum":
				ScriptSnapshotCodec.decodeValue(data);
			default:
				throw new ScriptError("Unknown execution value kind '" + Std.string(kind) + "'.");
		};
	}

	function createExecutionFrame(value:ScriptValue, args:Array<ScriptValue>, span:ScriptSpan):ScriptExecutionFrame {
		return switch value {
			case VClosure(closure):
				createExecutionFrameFromClosure(closure, args, span);
			case VBuiltin(name):
				throw new ScriptError("Cannot start an execution from builtin '" + name + "'.", span);
			default:
				throw new ScriptError("Cannot execute non-function value " + ScriptValueTools.format(value) + ".", span);
		};
	}

	public function createExecutionFrameFromClosure(closure:ScriptClosure, args:Array<ScriptValue>, span:ScriptSpan):ScriptExecutionFrame {
		if (closure.body == null) {
			throw new ScriptError("Bytecode closures are not supported by the AST execution runtime.", span);
		}

		if (closure.paramNames.length != args.length) {
			throw new ScriptError(
				(closure.name == null ? "Lambda" : "Function '" + closure.name + "'")
					+ " expects " + closure.paramNames.length + " arguments.",
				span
			);
		}

		var env = new ScriptEnv(closure.env);

		for (index in 0...closure.paramNames.length) {
			var argType = ScriptValueTools.typeOf(args[index]);
			var expectedType = closure.paramTypes[index];

			if (!ScriptTypeTools.isAssignable(expectedType, argType)) {
				throw new ScriptError(
					"Argument " + (index + 1) + " expects " + ScriptTypeTools.format(expectedType)
						+ " but found " + ScriptTypeTools.format(argType) + ".",
					span
				);
			}

			env.define(closure.paramNames[index], expectedType, true, args[index]);
		}

		return new ScriptExecutionFrame(
			closure.moduleName,
			closure.name,
			closure.returnType,
			env,
			[OEval(closure.body.id)],
			[]
		);
	}

	function restoreExecutionFrame(frameEntry:ScriptFrameSnapshotEntry, envs:IntMap<ScriptEnv>):ScriptExecutionFrame {
		var module = getModuleInstance(frameEntry.moduleName);
		var env = frameEntry.envId == null ? module.env : envs.get(frameEntry.envId);
		var returnTypeData:Dynamic = Reflect.field(frameEntry, "returnType");
		var returnType = returnTypeData == null ? null : ScriptSnapshotCodec.decodeType(returnTypeData);
		var ops = [for (op in frameEntry.ops) cast ScriptSnapshotCodec.decodeExecOp(op)];
		var values = [for (value in frameEntry.values) restoreExecutionValue(value, envs)];

		if (env == null) {
			throw new ScriptError("Execution snapshot references unknown frame environment '" + Std.string(frameEntry.envId) + "'.");
		}

		return new ScriptExecutionFrame(
			frameEntry.moduleName,
			frameEntry.functionName,
			returnType,
			env,
			ops,
			values
		);
	}

	function createModuleEnvs():Void {
		for (moduleName => moduleInfo in info.modules) {
			var env = new ScriptEnv();
			ScriptBuiltins.installInto(env);
			modules.set(moduleName, new ScriptModuleInstance(moduleName, moduleInfo, env, this));
		}
	}

	function predeclareExports():Void {
		for (moduleName in info.moduleOrder) {
			var module = modules.get(moduleName);

			for (decl in module.info.program.declarations) {
				switch decl {
					case DFunction(fnDecl):
						predeclareFunction(module, fnDecl);
					case DValue(valueDecl):
						predeclareValue(module, valueDecl);
					case DStruct(_) | DEnum(_):
				}
			}
		}
	}

	function predeclareFunction(module:ScriptModuleInstance, fnDecl:ScriptFunctionDecl):Void {
		var binding = module.info.exports.get(fnDecl.name);
		var fnType = binding.type;
		var paramTypes = extractFunctionParams(fnType);
		var returnType = extractFunctionReturn(fnType);
		var closure = ScriptClosure.forAst(
			fnDecl.name,
			module.name,
			[for (param in fnDecl.params) param.name],
			paramTypes,
			returnType,
			fnDecl.body,
			module.env
		);
		module.env.define(fnDecl.name, fnType, false, VClosure(closure));
	}

	function predeclareValue(module:ScriptModuleInstance, valueDecl:ScriptValueDecl):Void {
		var binding = module.info.exports.get(valueDecl.name);
		module.env.define(valueDecl.name, binding.type, true, VVoid, false);
	}

	function evaluateTopLevelValues():Void {
		for (moduleName in info.moduleOrder) {
			var module = modules.get(moduleName);

			for (decl in module.info.program.declarations) {
				switch decl {
					case DValue(valueDecl):
						var value = evalExpr(valueDecl.value, module.info, module.env);
						module.env.assign(valueDecl.name, value, valueDecl.span);
					case DFunction(_) | DStruct(_) | DEnum(_):
				}
			}
		}
	}

	function callClosure(closure:ScriptClosure, args:Array<ScriptValue>, span:ScriptSpan):ScriptValue {
		if (closure.body == null) {
			throw new ScriptError("Bytecode closures are not supported by the AST runtime.", span);
		}

		if (closure.paramNames.length != args.length) {
			throw new ScriptError(
				(closure.name == null ? "Lambda" : "Function '" + closure.name + "'")
					+ " expects " + closure.paramNames.length + " arguments.",
				span
			);
		}

		var env = new ScriptEnv(closure.env);

		for (index in 0...closure.paramNames.length) {
			var argType = ScriptValueTools.typeOf(args[index]);
			var expectedType = closure.paramTypes[index];

			if (!ScriptTypeTools.isAssignable(expectedType, argType)) {
				throw new ScriptError(
					"Argument " + (index + 1) + " expects " + ScriptTypeTools.format(expectedType)
						+ " but found " + ScriptTypeTools.format(argType) + ".",
					span
				);
			}

			env.define(closure.paramNames[index], expectedType, true, args[index]);
		}

		var moduleInfo = info.modules.get(closure.moduleName);
		var result = evalExpr(closure.body, moduleInfo, env);

		if (closure.returnType != null && !ScriptTypeTools.isAssignable(closure.returnType, ScriptValueTools.typeOf(result))) {
			throw new ScriptError(
				(closure.name == null ? "Lambda" : "Function '" + closure.name + "'")
					+ " returned " + ScriptTypeTools.format(ScriptValueTools.typeOf(result))
					+ " but expected " + ScriptTypeTools.format(closure.returnType) + ".",
				closure.body.span
			);
		}

		return result;
	}

	function evalExpr(expr:ScriptExpr, moduleInfo:ScriptModuleInfo, env:ScriptEnv):ScriptValue {
		return switch expr.def {
			case EInt(value):
				VInt(value);
			case EFloat(value):
				VFloat(value);
			case EString(value):
				VString(value);
			case EBool(value):
				VBool(value);
			case EPath(path):
				resolveValuePath(path, moduleInfo, env, expr.span);
			case EList(elements):
				VList([for (element in elements) evalExpr(element, moduleInfo, env)]);
			case ERecord(typePath, fields):
				evalRecord(typePath, fields, moduleInfo, env, expr.span);
			case ELambda(params, returnTypeRef, body):
				var paramTypes = [for (param in params) resolveTypeRef(moduleInfo, param.type)];
				var returnType = returnTypeRef == null ? extractFunctionReturn(getExprType(moduleInfo.name, expr.id)) : resolveTypeRef(moduleInfo, returnTypeRef);
				VClosure(ScriptClosure.forAst(
					null,
					moduleInfo.name,
					[for (param in params) param.name],
					paramTypes,
					returnType,
					body,
					env
				));
			case ECall(callee, args):
				var calleeValue = evalExpr(callee, moduleInfo, env);
				var argValues = [for (arg in args) evalExpr(arg, moduleInfo, env)];
				callValue(calleeValue, argValues, expr.span);
			case EField(target, name):
				evalFieldAccess(evalExpr(target, moduleInfo, env), name, expr.span);
			case EIndex(target, index):
				evalIndexAccess(evalExpr(target, moduleInfo, env), evalExpr(index, moduleInfo, env), expr.span);
			case EUnary(op, inner):
				evalUnary(op, evalExpr(inner, moduleInfo, env), expr.span);
			case EBinary(op, left, right):
				evalBinary(op, evalExpr(left, moduleInfo, env), evalExpr(right, moduleInfo, env), expr.span);
			case EIf(condition, thenBranch, elseBranch):
				switch evalExpr(condition, moduleInfo, env) {
					case VBool(true):
						evalExpr(thenBranch, moduleInfo, env);
					case VBool(false):
						evalExpr(elseBranch, moduleInfo, env);
					default:
						throw new ScriptError("If conditions must evaluate to Bool.", condition.span);
				}
			case EBlock(statements, tail):
				evalBlock(statements, tail, moduleInfo, env);
		};
	}

	function evalRecord(
		typePath:ScriptPath,
		fields:Array<ScriptRecordFieldInit>,
		moduleInfo:ScriptModuleInfo,
		env:ScriptEnv,
		span:ScriptSpan
	):ScriptValue {
		var type = resolveNamedTypePath(moduleInfo, typePath, span);
		var recordName = switch type {
			case TRecord(name): name;
			default:
				throw new ScriptError("Record literals require a struct type.", span);
		};

		var structInfo = info.structs.get(recordName);
		var fieldValues = new StringMap<ScriptValue>();

		for (field in fields) {
			if (fieldValues.exists(field.name)) {
				throw new ScriptError("Duplicate field '" + field.name + "' in record literal.", field.span);
			}

			fieldValues.set(field.name, evalExpr(field.value, moduleInfo, env));
		}

		for (fieldName in structInfo.fieldOrder) {
			if (!fieldValues.exists(fieldName)) {
				throw new ScriptError("Missing field '" + fieldName + "' in record literal.", span);
			}
		}

		return VRecord(recordName, fieldValues);
	}

	function evalBlock(statements:Array<ScriptStmt>, tail:Null<ScriptExpr>, moduleInfo:ScriptModuleInfo, env:ScriptEnv):ScriptValue {
		var blockEnv = new ScriptEnv(env);

		for (statement in statements) {
			switch statement {
				case SLet(binding):
					var value = evalExpr(binding.value, moduleInfo, blockEnv);
					var type = binding.type == null ? getExprType(moduleInfo.name, binding.value.id) : resolveTypeRef(moduleInfo, binding.type);
					blockEnv.define(binding.name, type, true, value);
				case SSet(assign):
					if (assign.target.length != 1) {
						throw new ScriptError("Assignments only support simple identifiers.", assign.span);
					}

					var value = evalExpr(assign.value, moduleInfo, blockEnv);
					blockEnv.assign(assign.target[0], value, assign.span);
				case SExpr(expr):
					evalExpr(expr, moduleInfo, blockEnv);
			}
		}

		return tail == null ? VVoid : evalExpr(tail, moduleInfo, blockEnv);
	}

	public function resolveTypeRef(moduleInfo:ScriptModuleInfo, typeRef:ScriptTypeRef):ScriptType {
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
					resolveNamedTypePath(moduleInfo, typeRef.path, typeRef.span);
			};
		}

		return resolveNamedTypePath(moduleInfo, typeRef.path, typeRef.span);
	}

	function requireTypeArgs(typeRef:ScriptTypeRef, expected:Int):Void {
		if (typeRef.args.length != expected) {
			throw new ScriptError("Type '" + typeRef.path.join(".") + "' expects " + expected + " type arguments.", typeRef.span);
		}
	}

	public function resolveNamedTypePath(moduleInfo:ScriptModuleInfo, path:ScriptPath, span:ScriptSpan):ScriptType {
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
			var qualified = imported + "." + path.slice(1).join(".");

			if (info.structs.exists(qualified)) {
				return TRecord(qualified);
			}

			if (info.enums.exists(qualified)) {
				return TEnum(qualified);
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

	public function resolveValuePath(path:ScriptPath, moduleInfo:ScriptModuleInfo, env:ScriptEnv, span:ScriptSpan):ScriptValue {
		if (path.length == 0) {
			throw new ScriptError("Expected a value path.", span);
		}

		var local = env.resolve(path[0]);

		if (local != null) {
			return resolveFieldValue(local.value, path.slice(1), span);
		}

		if (path.length == 2) {
			var localEnumName = moduleInfo.name + "." + path[0];
			var localEnum = info.enums.get(localEnumName);

			if (localEnum != null && localEnum.cases.exists(path[1])) {
				return VEnum(localEnumName, path[1]);
			}
		}

		if (path[0] == "std") {
			var builtinName = path.join(".");

			if (!ScriptBuiltins.has(builtinName) || path.length != 2) {
				throw new ScriptError("Unknown builtin '" + builtinName + "'.", span);
			}

			return modules.get(moduleInfo.name).env.get(builtinName, span);
		}

		var moduleTarget = resolveModuleReference(moduleInfo, path);

		if (moduleTarget != null) {
			return resolveModuleValue(moduleTarget.moduleName, moduleTarget.remainder, span);
		}

		throw new ScriptError("Unknown value '" + path.join(".") + "'.", span);
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

			if (modules.exists(moduleName)) {
				return { moduleName: moduleName, remainder: path.slice(prefixLength) };
			}
		}

		return null;
	}

	function resolveModuleValue(moduleName:String, remainder:ScriptPath, span:ScriptSpan):ScriptValue {
		if (remainder.length == 0) {
			throw new ScriptError("Module '" + moduleName + "' is not a value.", span);
		}

		var module = modules.get(moduleName);
		var exportCell = module.env.resolveLocal(remainder[0]);

		if (exportCell != null) {
			return resolveFieldValue(exportCell.value, remainder.slice(1), span);
		}

		if (remainder.length == 2) {
			var enumName = moduleName + "." + remainder[0];
			var enumInfo = info.enums.get(enumName);

			if (enumInfo != null && enumInfo.cases.exists(remainder[1])) {
				return VEnum(enumName, remainder[1]);
			}
		}

		throw new ScriptError("Unknown module value '" + moduleName + "." + remainder.join(".") + "'.", span);
	}

	function resolveFieldValue(value:ScriptValue, fields:Array<String>, span:ScriptSpan):ScriptValue {
		var current = value;

		for (fieldName in fields) {
			switch current {
				case VRecord(_, recordFields):
					var next = recordFields.get(fieldName);

					if (next == null) {
						throw new ScriptError("Unknown record field '" + fieldName + "'.", span);
					}

					current = next;
				default:
					throw new ScriptError("Value " + ScriptValueTools.format(current) + " does not expose field '" + fieldName + "'.", span);
			}
		}

		return current;
	}

	public function evalFieldAccess(target:ScriptValue, fieldName:String, span:ScriptSpan):ScriptValue {
		return resolveFieldValue(target, [fieldName], span);
	}

	public function evalIndexAccess(target:ScriptValue, index:ScriptValue, span:ScriptSpan):ScriptValue {
		return switch [target, index] {
			case [VList(items), VInt(position)]:
				if (position < 0 || position >= items.length) {
					throw new ScriptError("List index " + position + " is out of bounds.", span);
				}

				items[position];
			case [VList(_), _]:
				throw new ScriptError("List indices must be Int.", span);
			default:
				throw new ScriptError("Value " + ScriptValueTools.format(target) + " is not indexable.", span);
		};
	}

	public function evalUnary(op:ScriptUnaryOp, operand:ScriptValue, span:ScriptSpan):ScriptValue {
		return switch op {
			case Negate:
				switch operand {
					case VInt(value):
						VInt(-value);
					case VFloat(value):
						VFloat(-value);
					default:
						throw new ScriptError("Unary '-' expects an Int or Float.", span);
				}
			case Not:
				switch operand {
					case VBool(flag):
						VBool(!flag);
					default:
						throw new ScriptError("Unary '!' expects a Bool.", span);
				}
		};
	}

	public function evalBinary(op:ScriptBinaryOp, left:ScriptValue, right:ScriptValue, span:ScriptSpan):ScriptValue {
		return switch op {
			case Add:
				switch [left, right] {
					case [VInt(a), VInt(b)]:
						VInt(a + b);
					case [VFloat(a), VFloat(b)]:
						VFloat(a + b);
					case [VString(a), VString(b)]:
						VString(a + b);
					default:
						throw new ScriptError("Operator '+' requires matching numeric types or two Strings.", span);
				}
			case Subtract:
				switch [left, right] {
					case [VInt(a), VInt(b)]:
						VInt(a - b);
					case [VFloat(a), VFloat(b)]:
						VFloat(a - b);
					default:
						throw new ScriptError("Operator '-' requires matching numeric types.", span);
				}
			case Multiply:
				switch [left, right] {
					case [VInt(a), VInt(b)]:
						VInt(a * b);
					case [VFloat(a), VFloat(b)]:
						VFloat(a * b);
					default:
						throw new ScriptError("Operator '*' requires matching numeric types.", span);
				}
			case Divide:
				switch [left, right] {
					case [VInt(a), VInt(b)]:
						if (b == 0) {
							throw new ScriptError("Division by zero.", span);
						}

						VInt(Std.int(a / b));
					case [VFloat(a), VFloat(b)]:
						if (b == 0.0) {
							throw new ScriptError("Division by zero.", span);
						}

						VFloat(a / b);
					default:
						throw new ScriptError("Operator '/' requires matching numeric types.", span);
				}
			case Modulo:
				switch [left, right] {
					case [VInt(a), VInt(b)]:
						if (b == 0) {
							throw new ScriptError("Modulo by zero.", span);
						}

						VInt(a % b);
					case [VFloat(a), VFloat(b)]:
						if (b == 0.0) {
							throw new ScriptError("Modulo by zero.", span);
						}

						VFloat(a % b);
					default:
						throw new ScriptError("Operator '%' requires matching numeric types.", span);
				}
			case Equal:
				VBool(valuesEqual(left, right));
			case NotEqual:
				VBool(!valuesEqual(left, right));
			case Less:
				compareNumeric(left, right, span, function(a, b) return a < b);
			case LessEqual:
				compareNumeric(left, right, span, function(a, b) return a <= b);
			case Greater:
				compareNumeric(left, right, span, function(a, b) return a > b);
			case GreaterEqual:
				compareNumeric(left, right, span, function(a, b) return a >= b);
			case And:
				switch [left, right] {
					case [VBool(a), VBool(b)]:
						VBool(a && b);
					default:
						throw new ScriptError("Operator '&&' requires Bool operands.", span);
				}
			case Or:
				switch [left, right] {
					case [VBool(a), VBool(b)]:
						VBool(a || b);
					default:
						throw new ScriptError("Operator '||' requires Bool operands.", span);
				}
		};
	}

	function compareNumeric(left:ScriptValue, right:ScriptValue, span:ScriptSpan, cmp:Float->Float->Bool):ScriptValue {
		return switch [left, right] {
			case [VInt(a), VInt(b)]:
				VBool(cmp(a, b));
			case [VFloat(a), VFloat(b)]:
				VBool(cmp(a, b));
			default:
				throw new ScriptError("Comparison operators require matching numeric types.", span);
		};
	}

	function valuesEqual(left:ScriptValue, right:ScriptValue):Bool {
		return switch [left, right] {
			case [VVoid, VVoid]:
				true;
			case [VInt(a), VInt(b)]:
				a == b;
			case [VFloat(a), VFloat(b)]:
				a == b;
			case [VString(a), VString(b)]:
				a == b;
			case [VBool(a), VBool(b)]:
				a == b;
			case [VEnum(typeA, caseA), VEnum(typeB, caseB)]:
				typeA == typeB && caseA == caseB;
			default:
				false;
		};
	}

	function extractFunctionParams(type:ScriptType):Array<ScriptType> {
		return switch type {
			case TFunction(paramTypes, _):
				paramTypes;
			default:
				throw new ScriptError("Expected a function type.");
		};
	}

	public function extractFunctionReturn(type:ScriptType):ScriptType {
		return switch type {
			case TFunction(_, returnType):
				returnType;
			default:
				throw new ScriptError("Expected a function type.");
		};
	}
}

class ScriptExecutionFrame {
	public var moduleName(default, null):String;
	public var functionName(default, null):Null<String>;
	public var returnType(default, null):Null<ScriptType>;
	public var env:ScriptEnv;
	public var ops:Array<ScriptExecOp>;
	public var values:Array<ScriptValue>;

	public function new(
		moduleName:String,
		functionName:Null<String>,
		returnType:Null<ScriptType>,
		env:ScriptEnv,
		ops:Array<ScriptExecOp>,
		values:Array<ScriptValue>
	) {
		this.moduleName = moduleName;
		this.functionName = functionName;
		this.returnType = returnType;
		this.env = env;
		this.ops = ops;
		this.values = values;
	}
}

class ScriptExecution {
	var runtime:ScriptProjectRuntime;
	var frames:Array<ScriptExecutionFrame>;
	var completed:Bool;
	var result:Null<ScriptValue>;

	public function new(runtime:ScriptProjectRuntime, frames:Array<ScriptExecutionFrame>) {
		this.runtime = runtime;
		this.frames = frames;
		this.completed = false;
		this.result = null;
	}

	public function isComplete():Bool {
		return completed;
	}

	public function frameDepth():Int {
		return frames.length;
	}

	public function getResult():ScriptValue {
		if (!completed || result == null) {
			throw new ScriptError("Execution has not completed yet.");
		}

		return result;
	}

	public function step(?budget:Int = 1):Void {
		if (budget < 1) {
			throw new ScriptError("Execution step budget must be at least 1.");
		}

		for (_ in 0...budget) {
			if (completed) {
				return;
			}

			if (frames.length == 0) {
				throw new ScriptError("Execution has no frames.");
			}

			var frame = frames[frames.length - 1];

			if (frame.ops.length == 0) {
				completeTopFrame();
				continue;
			}

			applyOp(frame, frame.ops.pop());
		}
	}

	public function run(?budget:Int = 100000):ScriptValue {
		var remaining = budget;

		while (!completed) {
			if (remaining <= 0) {
				throw new ScriptError("Execution did not complete within the provided step budget.");
			}

			step(1);
			remaining--;
		}

		return result;
	}

	public function createSnapshotData():ScriptExecutionSnapshotPayload {
		if (completed) {
			throw new ScriptError("Cannot snapshot a completed execution.");
		}

		return new ScriptExecutionSnapshotBuilder(runtime).build(frames);
	}

	public function createSnapshot():String {
		return ScriptSnapshotCodec.stringify(createSnapshotData());
	}

	function applyOp(frame:ScriptExecutionFrame, op:ScriptExecOp):Void {
		var moduleInfo = runtime.getModuleInfo(frame.moduleName);

		switch op {
			case OEval(exprId):
				var expr = runtime.getExpr(frame.moduleName, exprId);
				evalExpr(frame, moduleInfo, expr);
			case OPushVoid:
				frame.values.push(VVoid);
			case OEnterScope:
				frame.env = new ScriptEnv(frame.env);
			case OExitScope:
				var parent = frame.env.parentEnv();

				if (parent == null) {
					throw new ScriptError("Cannot exit the root execution scope.");
				}

				frame.env = parent;
			case ODiscard:
				popValue(frame, "a discarded expression result");
			case OBind(valueDeclId):
				var binding = runtime.getValueDecl(frame.moduleName, valueDeclId);
				var value = popValue(frame, "a binding value");
				var bindingType = binding.type == null ? runtime.getExprType(frame.moduleName, binding.value.id) : runtime.resolveTypeRef(moduleInfo, binding.type);

				if (!ScriptTypeTools.isAssignable(bindingType, ScriptValueTools.typeOf(value))) {
					throw new ScriptError(
						"Binding '" + binding.name + "' expects " + ScriptTypeTools.format(bindingType)
							+ " but found " + ScriptTypeTools.format(ScriptValueTools.typeOf(value)) + ".",
						binding.span
					);
				}

				if (ScriptTypeTools.equals(bindingType, TVoid)) {
					throw new ScriptError("Bindings cannot store Void values.", binding.span);
				}

				frame.env.define(binding.name, bindingType, true, value);
			case OAssign(assignId):
				var assign = runtime.getAssign(frame.moduleName, assignId);
				var assignedValue = popValue(frame, "an assignment value");

				if (assign.target.length != 1) {
					throw new ScriptError("Assignments only support simple identifiers.", assign.span);
				}

				frame.env.assign(assign.target[0], assignedValue, assign.span);
			case OBuildList(count):
				var items:Array<ScriptValue> = [];

				for (_ in 0...count) {
					items.push(popValue(frame, "a list element"));
				}

				items.reverse();
				frame.values.push(VList(items));
			case OBuildRecord(typeName, fieldNames):
				var fieldValues:Array<ScriptValue> = [];

				for (_ in 0...fieldNames.length) {
					fieldValues.push(popValue(frame, "a record field value"));
				}

				fieldValues.reverse();
				frame.values.push(runtime.createRecordValue(typeName, fieldNames, fieldValues, moduleInfo.program.span));
			case OApplyUnary(unaryOp):
				var operand = popValue(frame, "a unary operand");
				frame.values.push(runtime.evalUnary(unaryOp, operand, moduleInfo.program.span));
			case OApplyBinary(binaryOp):
				var right = popValue(frame, "the right-hand side of a binary operation");
				var left = popValue(frame, "the left-hand side of a binary operation");
				frame.values.push(runtime.evalBinary(binaryOp, left, right, moduleInfo.program.span));
			case OApplyField(name):
				var target = popValue(frame, "a field access target");
				frame.values.push(runtime.evalFieldAccess(target, name, moduleInfo.program.span));
			case OApplyIndex:
				var index = popValue(frame, "an index expression");
				var target = popValue(frame, "an index target");
				frame.values.push(runtime.evalIndexAccess(target, index, moduleInfo.program.span));
			case OBranch(thenExprId, elseExprId):
				switch popValue(frame, "an if condition") {
					case VBool(true):
						frame.ops.push(OEval(thenExprId));
					case VBool(false):
						frame.ops.push(OEval(elseExprId));
					default:
						throw new ScriptError("If conditions must evaluate to Bool.", moduleInfo.program.span);
				}
			case OCall(argCount):
				var args:Array<ScriptValue> = [];

				for (_ in 0...argCount) {
					args.push(popValue(frame, "a call argument"));
				}

				args.reverse();
				var callee = popValue(frame, "a call target");

				switch callee {
					case VBuiltin(name):
						frame.values.push(ScriptBuiltins.invoke(name, args, moduleInfo.program.span));
					case VClosure(closure):
						frames.push(runtime.createExecutionFrameFromClosure(closure, args, moduleInfo.program.span));
					default:
						throw new ScriptError("Cannot call non-function value " + ScriptValueTools.format(callee) + ".", moduleInfo.program.span);
				}
		}
	}

	function evalExpr(frame:ScriptExecutionFrame, moduleInfo:ScriptModuleInfo, expr:ScriptExpr):Void {
		switch expr.def {
			case EInt(value):
				frame.values.push(VInt(value));
			case EFloat(value):
				frame.values.push(VFloat(value));
			case EString(value):
				frame.values.push(VString(value));
			case EBool(value):
				frame.values.push(VBool(value));
			case EPath(path):
				frame.values.push(runtime.resolveValuePath(path, moduleInfo, frame.env, expr.span));
			case EList(elements):
				frame.ops.push(OBuildList(elements.length));
				for (index in 0...elements.length) {
					frame.ops.push(OEval(elements[elements.length - 1 - index].id));
				}
			case ERecord(typePath, fields):
				var recordType = runtime.resolveNamedTypePath(moduleInfo, typePath, expr.span);
				var recordName = switch recordType {
					case TRecord(name):
						name;
					default:
						throw new ScriptError("Record literals require a struct type.", expr.span);
				};
				frame.ops.push(OBuildRecord(recordName, [for (field in fields) field.name]));
				for (index in 0...fields.length) {
					frame.ops.push(OEval(fields[fields.length - 1 - index].value.id));
				}
			case ELambda(params, returnTypeRef, body):
				var paramTypes = [for (param in params) runtime.resolveTypeRef(moduleInfo, param.type)];
				var returnType = returnTypeRef == null ? runtime.extractFunctionReturn(runtime.getExprType(moduleInfo.name, expr.id)) : runtime.resolveTypeRef(moduleInfo, returnTypeRef);
				frame.values.push(VClosure(ScriptClosure.forAst(
					null,
					moduleInfo.name,
					[for (param in params) param.name],
					paramTypes,
					returnType,
					body,
					frame.env
				)));
			case ECall(callee, args):
				frame.ops.push(OCall(args.length));
				for (index in 0...args.length) {
					frame.ops.push(OEval(args[args.length - 1 - index].id));
				}
				frame.ops.push(OEval(callee.id));
			case EField(target, name):
				frame.ops.push(OApplyField(name));
				frame.ops.push(OEval(target.id));
			case EIndex(target, index):
				frame.ops.push(OApplyIndex);
				frame.ops.push(OEval(index.id));
				frame.ops.push(OEval(target.id));
			case EUnary(unaryOp, inner):
				frame.ops.push(OApplyUnary(unaryOp));
				frame.ops.push(OEval(inner.id));
			case EBinary(binaryOp, left, right):
				frame.ops.push(OApplyBinary(binaryOp));
				frame.ops.push(OEval(right.id));
				frame.ops.push(OEval(left.id));
			case EIf(condition, thenBranch, elseBranch):
				frame.ops.push(OBranch(thenBranch.id, elseBranch.id));
				frame.ops.push(OEval(condition.id));
			case EBlock(statements, tail):
				frame.ops.push(OExitScope);
				frame.ops.push(tail == null ? OPushVoid : OEval(tail.id));

				for (index in 0...statements.length) {
					var statement = statements[statements.length - 1 - index];

					switch statement {
						case SLet(binding):
							frame.ops.push(OBind(binding.id));
							frame.ops.push(OEval(binding.value.id));
						case SSet(assign):
							frame.ops.push(OAssign(assign.id));
							frame.ops.push(OEval(assign.value.id));
						case SExpr(statementExpr):
							frame.ops.push(ODiscard);
							frame.ops.push(OEval(statementExpr.id));
					}
				}

				frame.ops.push(OEnterScope);
		}
	}

	function completeTopFrame():Void {
		var frame = frames.pop();
		var frameResult = frame.values.length == 0 ? VVoid : frame.values.pop();

		if (frame.values.length != 0) {
			throw new ScriptError("Execution frame for module '" + frame.moduleName + "' completed with leftover values.");
		}

		if (frame.returnType != null && !ScriptTypeTools.isAssignable(frame.returnType, ScriptValueTools.typeOf(frameResult))) {
			throw new ScriptError(
				(frame.functionName == null ? "Lambda" : "Function '" + frame.functionName + "'")
					+ " returned " + ScriptTypeTools.format(ScriptValueTools.typeOf(frameResult))
					+ " but expected " + ScriptTypeTools.format(frame.returnType) + "."
			);
		}

		if (frames.length == 0) {
			completed = true;
			result = frameResult;
		} else {
			frames[frames.length - 1].values.push(frameResult);
		}
	}

	function popValue(frame:ScriptExecutionFrame, context:String):ScriptValue {
		if (frame.values.length == 0) {
			throw new ScriptError("Execution expected " + context + " but the value stack was empty.");
		}

		return frame.values.pop();
	}
}

private class ScriptExecutionSnapshotBuilder {
	var runtime:ScriptProjectRuntime;
	var envIds:ObjectMap<ScriptEnv, Int>;
	var envEntries:Array<ScriptExecutionEnvSnapshotEntry>;
	var nextEnvId:Int;

	public function new(runtime:ScriptProjectRuntime) {
		this.runtime = runtime;
		this.envIds = new ObjectMap();
		this.envEntries = [];
		this.nextEnvId = 1;
	}

	public function build(frames:Array<ScriptExecutionFrame>):ScriptExecutionSnapshotPayload {
		for (frame in frames) {
			captureEnv(frame.env, frame.moduleName);

			for (value in frame.values) {
				encodeValue(value, "execution value stack");
			}
		}

		return ScriptSnapshotCodec.encodeExecutionSnapshot(
			runtime.createSnapshotData(),
			envEntries,
			[for (frame in frames) snapshotFrame(frame)]
		);
	}

	function snapshotFrame(frame:ScriptExecutionFrame):ScriptFrameSnapshotEntry {
		return {
			moduleName: frame.moduleName,
			functionName: frame.functionName,
			returnType: frame.returnType == null ? null : ScriptSnapshotCodec.encodeType(frame.returnType),
			envId: captureEnv(frame.env, frame.moduleName),
			ops: [for (op in frame.ops) ScriptSnapshotCodec.encodeExecOp(op)],
			values: [for (value in frame.values) encodeValue(value, "execution value stack")],
		};
	}

	function captureEnv(env:ScriptEnv, moduleName:String):Null<Int> {
		var moduleEnv = runtime.getModuleInstance(moduleName).env;

		if (env == moduleEnv) {
			return null;
		}

		var existing = envIds.get(env);

		if (existing != null) {
			return existing;
		}

		var parent = env.parentEnv();

		if (parent == null) {
			throw new ScriptError("Cannot snapshot execution environment without a module root for '" + moduleName + "'.");
		}

		var id = nextEnvId++;
		var parentId = captureEnv(parent, moduleName);
		var entry:ScriptExecutionEnvSnapshotEntry = {
			id: id,
			moduleName: moduleName,
			parentId: parentId,
			cells: [],
		};
		envIds.set(env, id);
		envEntries.push(entry);

		for (cell in env.localCells()) {
			entry.cells.push({
				name: cell.name,
				type: ScriptSnapshotCodec.encodeType(cell.type),
				mutable: cell.mutable,
				initialized: cell.initialized,
				value: cell.initialized ? encodeValue(cell.value, "execution scope cell '" + cell.name + "'") : null,
			});
		}

		return id;
	}

	function encodeValue(value:ScriptValue, context:String):Dynamic {
		return switch value {
			case VVoid | VInt(_) | VFloat(_) | VString(_) | VBool(_) | VEnum(_, _):
				ScriptSnapshotCodec.encodeValue(value);
			case VBuiltin(name):
				{ kind: "builtin", name: name };
			case VClosure(closure):
				if (closure.body == null) {
					throw new ScriptError("Cannot snapshot " + context + " containing bytecode closures through the AST execution runtime.");
				}

				{
					kind: "closure",
					name: closure.name,
					moduleName: closure.moduleName,
					bodyExprId: closure.body.id,
					paramNames: closure.paramNames.copy(),
					paramTypes: [for (paramType in closure.paramTypes) ScriptSnapshotCodec.encodeType(paramType)],
					returnType: closure.returnType == null ? null : ScriptSnapshotCodec.encodeType(closure.returnType),
					envId: captureEnv(closure.env, closure.moduleName),
				};
			case VList(items):
				{ kind: "list", items: [for (item in items) encodeValue(item, context)] };
			case VRecord(typeName, fields):
				var encodedFields = {};

				for (fieldName => fieldValue in fields) {
					Reflect.setField(encodedFields, fieldName, encodeValue(fieldValue, context));
				}

				{ kind: "record", type: typeName, fields: encodedFields };
		};
	}
}
