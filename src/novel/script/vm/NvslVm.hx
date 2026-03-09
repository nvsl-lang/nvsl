package novel.script.vm;

import haxe.ds.IntMap;
import haxe.ds.ObjectMap;
import haxe.ds.StringMap;
import novel.script.ScriptError;
import novel.script.bytecode.Nvbc.NvbcFunction;
import novel.script.bytecode.Nvbc.NvbcGlobal;
import novel.script.bytecode.Nvbc.NvbcModule;
import novel.script.bytecode.Nvbc.NvbcOp;
import novel.script.bytecode.Nvbc.NvbcProgram;
import novel.script.bytecode.NvbcCodec;
import novel.script.runtime.ScriptBuiltins;
import novel.script.runtime.ScriptClosure;
import novel.script.runtime.ScriptEnv;
import novel.script.runtime.ScriptSnapshot.ScriptProjectSnapshotPayload;
import novel.script.runtime.ScriptSnapshot.ScriptVmEnvSnapshotEntry;
import novel.script.runtime.ScriptSnapshot.ScriptVmExecutionSnapshotPayload;
import novel.script.runtime.ScriptSnapshot.ScriptVmFrameSnapshotEntry;
import novel.script.runtime.ScriptSnapshot.ScriptSnapshotCodec;
import novel.script.runtime.ScriptValue;
import novel.script.runtime.ScriptValue.ScriptValueTools;
import novel.script.semantics.ScriptType;
import novel.script.semantics.ScriptType.ScriptTypeTools;
import novel.script.syntax.ScriptAst.ScriptBinaryOp;
import novel.script.syntax.ScriptAst.ScriptUnaryOp;

class NvslVmModuleInstance {
	public var name(default, null):String;
	public var module(default, null):NvbcModule;
	public var env(default, null):ScriptEnv;

	var runtime:NvslVmRuntime;

	public function new(name:String, module:NvbcModule, env:ScriptEnv, runtime:NvslVmRuntime) {
		this.name = name;
		this.module = module;
		this.env = env;
		this.runtime = runtime;
	}

	public function getGlobal(name:String):ScriptValue {
		return env.get(name);
	}

	public function call(name:String, args:Array<ScriptValue>):ScriptValue {
		return runtime.callExport(this, name, args);
	}
}

class NvslVmProjectInstance {
	public var program(default, null):NvbcProgram;
	public var modules(default, null):StringMap<NvslVmModuleInstance>;

	var runtime:NvslVmRuntime;

	public function new(program:NvbcProgram, modules:StringMap<NvslVmModuleInstance>, runtime:NvslVmRuntime) {
		this.program = program;
		this.modules = modules;
		this.runtime = runtime;
	}

	public function getModule(name:String):NvslVmModuleInstance {
		var module = modules.get(name);

		if (module == null) {
			throw new ScriptError("Unknown VM module '" + name + "'.");
		}

		return module;
	}

	public function call(moduleName:String, exportName:String, args:Array<ScriptValue>):ScriptValue {
		return getModule(moduleName).call(exportName, args);
	}

	public function callDefault(args:Array<ScriptValue>):ScriptValue {
		if (program.defaultEntryModule == null || program.defaultEntryExport == null) {
			throw new ScriptError("NVBC program does not define a default entrypoint.");
		}

		return call(program.defaultEntryModule, program.defaultEntryExport, args);
	}

	public function beginExecution(moduleName:String, exportName:String, args:Array<ScriptValue>):NvslVmExecution {
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

	public function restoreExecutionSnapshotData(payload:ScriptVmExecutionSnapshotPayload):NvslVmExecution {
		return runtime.restoreExecutionSnapshotData(payload);
	}

	public function restoreExecutionSnapshot(json:String):NvslVmExecution {
		return restoreExecutionSnapshotData(ScriptSnapshotCodec.decodeVmExecutionSnapshot(ScriptSnapshotCodec.parse(json)));
	}
}

class NvslVm {
	public static function loadProgram(program:NvbcProgram):NvslVmProjectInstance {
		return new NvslVmRuntime(program).load();
	}

	public static function loadJson(json:String):NvslVmProjectInstance {
		return loadProgram(NvbcCodec.parseProgram(json));
	}
}

class NvslVmExecutionFrame {
	public var moduleName(default, null):String;
	public var functionName(default, null):String;
	public var displayName(default, null):Null<String>;
	public var returnType(default, null):ScriptType;
	public var env:ScriptEnv;
	public var code(default, null):Array<NvbcOp>;
	public var ip:Int;
	public var values:Array<ScriptValue>;

	public function new(
		moduleName:String,
		functionName:String,
		displayName:Null<String>,
		returnType:ScriptType,
		env:ScriptEnv,
		code:Array<NvbcOp>,
		ip:Int,
		values:Array<ScriptValue>
	) {
		this.moduleName = moduleName;
		this.functionName = functionName;
		this.displayName = displayName;
		this.returnType = returnType;
		this.env = env;
		this.code = code;
		this.ip = ip;
		this.values = values;
	}
}

class NvslVmExecution {
	var runtime:NvslVmRuntime;
	var frames:Array<NvslVmExecutionFrame>;
	var completed:Bool;
	var result:Null<ScriptValue>;

	public function new(runtime:NvslVmRuntime, frames:Array<NvslVmExecutionFrame>) {
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
			throw new ScriptError("VM execution has not completed yet.");
		}

		return result;
	}

	public function step(?budget:Int = 1):Void {
		if (budget < 1) {
			throw new ScriptError("VM execution step budget must be at least 1.");
		}

		for (_ in 0...budget) {
			if (completed) {
				return;
			}

			if (frames.length == 0) {
				throw new ScriptError("VM execution has no frames.");
			}

			var frame = frames[frames.length - 1];

			if (frame.ip < 0 || frame.ip >= frame.code.length) {
				throw new ScriptError(
					"VM execution frame '" + frame.moduleName + "." + frame.functionName + "' reached invalid instruction pointer " + frame.ip + "."
				);
			}

			applyOp(frame, frame.code[frame.ip]);
		}
	}

	public function run(?budget:Int = 100000):ScriptValue {
		var remaining = budget;

		while (!completed) {
			if (remaining <= 0) {
				throw new ScriptError("VM execution did not complete within the provided step budget.");
			}

			step(1);
			remaining--;
		}

		return result;
	}

	public function createSnapshotData():ScriptVmExecutionSnapshotPayload {
		if (completed) {
			throw new ScriptError("Cannot snapshot a completed VM execution.");
		}

		return new NvslVmExecutionSnapshotBuilder(runtime).build(frames);
	}

	public function createSnapshot():String {
		return ScriptSnapshotCodec.stringify(createSnapshotData());
	}

	function applyOp(frame:NvslVmExecutionFrame, op:NvbcOp):Void {
		switch op {
			case PushVoid:
				frame.values.push(VVoid);
				frame.ip++;
			case PushInt(value):
				frame.values.push(VInt(value));
				frame.ip++;
			case PushFloat(value):
				frame.values.push(VFloat(value));
				frame.ip++;
			case PushString(value):
				frame.values.push(VString(value));
				frame.ip++;
			case PushBool(value):
				frame.values.push(VBool(value));
				frame.ip++;
			case PushEnum(typeName, caseName):
				runtime.validateEnumValue(typeName, caseName);
				frame.values.push(VEnum(typeName, caseName));
				frame.ip++;
			case LoadLocal(name):
				frame.values.push(frame.env.get(name));
				frame.ip++;
			case DefineLocal(name, type):
				var value = popValue(frame, "a local binding");
				var bindingType = type == null ? ScriptValueTools.typeOf(value) : type;

				if (ScriptTypeTools.equals(bindingType, TVoid)) {
					throw new ScriptError("Bindings cannot store Void values.");
				}

				if (!ScriptTypeTools.isAssignable(bindingType, ScriptValueTools.typeOf(value))) {
					throw new ScriptError(
						"Binding '" + name + "' expects " + ScriptTypeTools.format(bindingType)
							+ " but found " + ScriptTypeTools.format(ScriptValueTools.typeOf(value)) + "."
					);
				}

				frame.env.define(name, bindingType, true, value);
				frame.ip++;
			case StoreLocal(name):
				frame.env.assign(name, popValue(frame, "an assignment value"));
				frame.ip++;
			case LoadGlobal(targetModule, name):
				frame.values.push(runtime.getModule(targetModule).env.get(name));
				frame.ip++;
			case StoreGlobal(targetModule, name):
				runtime.getModule(targetModule).env.assign(name, popValue(frame, "a global assignment value"));
				frame.ip++;
			case EnterScope:
				frame.env = new ScriptEnv(frame.env);
				frame.ip++;
			case ExitScope:
				var parent = frame.env.parentEnv();

				if (parent == null) {
					throw new ScriptError("Cannot exit the root VM execution scope for '" + frame.moduleName + "." + frame.functionName + "'.");
				}

				frame.env = parent;
				frame.ip++;
			case Pop:
				popValue(frame, "a discarded expression result");
				frame.ip++;
			case MakeList(count):
				var items:Array<ScriptValue> = [];

				for (_ in 0...count) {
					items.push(popValue(frame, "a list element"));
				}

				items.reverse();
				frame.values.push(VList(items));
				frame.ip++;
			case MakeRecord(typeName, fieldNames):
				var fieldValues:Array<ScriptValue> = [];

				for (_ in 0...fieldNames.length) {
					fieldValues.push(popValue(frame, "a record field value"));
				}

				fieldValues.reverse();
				frame.values.push(runtime.createRecordValue(typeName, fieldNames, fieldValues));
				frame.ip++;
			case GetField(name):
				frame.values.push(runtime.evalFieldAccess(popValue(frame, "a field target"), name));
				frame.ip++;
			case GetIndex:
				var index = popValue(frame, "an index");
				var target = popValue(frame, "an index target");
				frame.values.push(runtime.evalIndexAccess(target, index));
				frame.ip++;
			case Unary(unaryOp):
				frame.values.push(runtime.evalUnary(unaryOp, popValue(frame, "a unary operand")));
				frame.ip++;
			case Binary(binaryOp):
				var right = popValue(frame, "the right-hand operand");
				var left = popValue(frame, "the left-hand operand");
				frame.values.push(runtime.evalBinary(binaryOp, left, right));
				frame.ip++;
			case Jump(target):
				runtime.validateJumpTarget(frame.code, target, frame.moduleName, frame.functionName);
				frame.ip = target;
			case JumpIfFalse(target):
				runtime.validateJumpTarget(frame.code, target, frame.moduleName, frame.functionName);
				switch popValue(frame, "an if condition") {
					case VBool(false):
						frame.ip = target;
					case VBool(true):
						frame.ip++;
					default:
						throw new ScriptError("If conditions must evaluate to Bool.");
				}
			case MakeClosure(targetModule, name):
				frame.values.push(runtime.createFunctionValue(runtime.getModule(targetModule), runtime.getFunction(targetModule, name), frame.env));
				frame.ip++;
			case CallBuiltin(name, argCount):
				var args = runtime.popArgs(frame.values, argCount, "builtin '" + name + "'");
				frame.values.push(ScriptBuiltins.invoke(name, args, null));
				frame.ip++;
			case CallFunction(targetModule, name, argCount):
				var args = runtime.popArgs(frame.values, argCount, "function '" + targetModule + "." + name + "'");
				frame.ip++;
				frames.push(runtime.createExecutionFrameFromFunction(targetModule, name, args));
			case CallValue(argCount):
				var args = runtime.popArgs(frame.values, argCount, "a function value call");
				var callee = popValue(frame, "a function value");
				frame.ip++;

				switch callee {
					case VBuiltin(name):
						frame.values.push(ScriptBuiltins.invoke(name, args, null));
					case VClosure(closure):
						frames.push(runtime.createExecutionFrameFromClosure(closure, args));
					default:
						throw new ScriptError("Cannot call non-function value " + ScriptValueTools.format(callee) + ".");
				}
			case Return:
				completeTopFrame();
		}
	}

	function completeTopFrame():Void {
		var frame = frames.pop();
		var frameResult = frame.values.length == 0 ? VVoid : frame.values.pop();

		if (frame.values.length != 0) {
			throw new ScriptError("VM execution frame '" + frame.moduleName + "." + frame.functionName + "' returned with leftover stack values.");
		}

		var actualType = ScriptValueTools.typeOf(frameResult);

		if (!ScriptTypeTools.isAssignable(frame.returnType, actualType)) {
			throw new ScriptError(
				(frame.displayName == null ? "Lambda" : "Function '" + frame.displayName + "'")
					+ " returned " + ScriptTypeTools.format(actualType)
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

	function popValue(frame:NvslVmExecutionFrame, context:String):ScriptValue {
		if (frame.values.length == 0) {
			throw new ScriptError("VM execution expected " + context + " but the value stack was empty.");
		}

		return frame.values.pop();
	}
}

private class NvslVmRuntime {
	var program:NvbcProgram;
	var modules:StringMap<NvslVmModuleInstance>;

	public function new(program:NvbcProgram) {
		this.program = program;
		this.modules = new StringMap();
	}

	public function load():NvslVmProjectInstance {
		createModuleEnvs();
		predeclareFunctions();
		evaluateGlobals();
		return new NvslVmProjectInstance(program, modules, this);
	}

	public function beginExecution(moduleName:String, exportName:String, args:Array<ScriptValue>):NvslVmExecution {
		var module = getModule(moduleName);
		var value = module.env.get(exportName);
		return new NvslVmExecution(this, [createExecutionFrame(value, args, moduleName, exportName)]);
	}

	public function callExport(module:NvslVmModuleInstance, exportName:String, args:Array<ScriptValue>):ScriptValue {
		return callValue(module.env.get(exportName), args, module, module.name + "." + exportName);
	}

	public function callFunction(moduleName:String, functionName:String, args:Array<ScriptValue>):ScriptValue {
		var module = getModule(moduleName);
		var fn = module.module.functions.get(functionName);

		if (fn == null) {
			throw new ScriptError("Unknown VM function '" + moduleName + "." + functionName + "'.");
		}

		return executeFunction(module, fn, args);
	}

	public function createSnapshotData():ScriptProjectSnapshotPayload {
		var moduleEntries:Array<Dynamic> = [];

		for (moduleName in program.moduleOrder) {
			var module = getModule(moduleName);
			var values = {};

			for (global in module.module.globals) {
				if (!global.mutable || !ScriptTypeTools.isSerializable(global.type)) {
					continue;
				}

				var cell = module.env.resolveLocal(global.name);

				if (cell == null) {
					throw new ScriptError("Missing VM global '" + moduleName + "." + global.name + "'.");
				}

				if (cell.initialized && !ScriptValueTools.isSerializable(cell.value)) {
					throw new ScriptError("Global '" + moduleName + "." + global.name + "' is not serializable.");
				}

				Reflect.setField(values, global.name, cell.initialized
					? { initialized: true, value: ScriptSnapshotCodec.encodeValue(cell.value) }
					: { initialized: false });
			}

			moduleEntries.push({
				name: moduleName,
				values: values,
			});
		}

		return ScriptSnapshotCodec.encodeProjectSnapshot(program.snapshotSchema, cast moduleEntries);
	}

	public function restoreSnapshotData(payload:ScriptProjectSnapshotPayload):Void {
		if (payload.schema != program.snapshotSchema) {
			throw new ScriptError("Snapshot schema does not match the current NVBC program.");
		}

		for (entry in payload.modules) {
			var moduleName:String = Reflect.field(entry, "name");
			var module = modules.get(moduleName);

			if (module == null) {
				throw new ScriptError("Snapshot references unknown VM module '" + moduleName + "'.");
			}

			var values = Reflect.field(entry, "values");

			for (globalName in Reflect.fields(values)) {
				var cell = module.env.resolveLocal(globalName);

				if (cell == null) {
					throw new ScriptError("Snapshot references unknown VM global '" + moduleName + "." + globalName + "'.");
				}

				if (!cell.mutable) {
					throw new ScriptError("Snapshot cannot restore immutable VM global '" + moduleName + "." + globalName + "'.");
				}

				var encodedEntry = Reflect.field(values, globalName);
				var initialized = Reflect.field(encodedEntry, "initialized");

				if (!Std.isOfType(initialized, Bool)) {
					throw new ScriptError("Snapshot entry '" + moduleName + "." + globalName + "' is invalid.");
				}

				if (initialized) {
					cell.restoreValue(ScriptSnapshotCodec.decodeValue(Reflect.field(encodedEntry, "value")), true);
				} else {
					cell.restoreValue(VVoid, false);
				}
			}
		}
	}

	public function restoreExecutionSnapshotData(payload:ScriptVmExecutionSnapshotPayload):NvslVmExecution {
		restoreSnapshotData(payload.project);
		var envs = new IntMap<ScriptEnv>();

		for (entry in payload.envs) {
			var parent = entry.parentId == null ? getModule(entry.moduleName).env : envs.get(entry.parentId);

			if (parent == null) {
				throw new ScriptError("VM execution snapshot references unknown parent environment '" + Std.string(entry.parentId) + "'.");
			}

			var env = new ScriptEnv(parent);
			envs.set(entry.id, env);

			for (cell in entry.cells) {
				var value = cell.initialized ? restoreExecutionValue(cell.value, envs) : VVoid;
				env.define(cell.name, ScriptSnapshotCodec.decodeType(cell.type), cell.mutable, value, cell.initialized);
			}
		}

		var frames:Array<NvslVmExecutionFrame> = [];

		for (entry in payload.frames) {
			var fn = getFunction(entry.moduleName, entry.functionName);
			var env = entry.envId == null ? getModule(entry.moduleName).env : envs.get(entry.envId);

			if (env == null) {
				throw new ScriptError("VM execution snapshot references unknown frame environment '" + Std.string(entry.envId) + "'.");
			}

			if (entry.ip < 0 || entry.ip >= fn.code.length) {
				throw new ScriptError(
					"VM execution snapshot has invalid instruction pointer " + entry.ip + " for '" + entry.moduleName + "." + entry.functionName + "'."
				);
			}

			frames.push(new NvslVmExecutionFrame(
				entry.moduleName,
				fn.name,
				fn.exposed ? fn.name : null,
				fn.returnType,
				env,
				fn.code,
				entry.ip,
				[for (value in entry.values) restoreExecutionValue(value, envs)]
			));
		}

		if (frames.length == 0) {
			throw new ScriptError("VM execution snapshot does not contain any frames.");
		}

		return new NvslVmExecution(this, frames);
	}

	function createModuleEnvs():Void {
		for (moduleName in program.moduleOrder) {
			var module = program.modules.get(moduleName);

			if (module == null) {
				throw new ScriptError("NVBC is missing module '" + moduleName + "'.");
			}

			var env = new ScriptEnv();
			ScriptBuiltins.installInto(env);

			for (global in module.globals) {
				env.define(global.name, global.type, global.mutable, VVoid, false);
			}

			modules.set(moduleName, new NvslVmModuleInstance(moduleName, module, env, this));
		}
	}

	function predeclareFunctions():Void {
		for (moduleName in program.moduleOrder) {
			var module = getModule(moduleName);

			for (functionName => fn in module.module.functions) {
				if (!fn.exposed) {
					continue;
				}

				module.env.define(functionName, TFunction(fn.paramTypes, fn.returnType), false, createFunctionValue(module, fn, module.env));
			}
		}
	}

	function evaluateGlobals():Void {
		for (moduleName in program.moduleOrder) {
			var module = getModule(moduleName);

			for (global in module.module.globals) {
				var value = executeCode(module, global.name, global.init, new ScriptEnv(module.env), global.type);
				module.env.assign(global.name, value);
			}
		}
	}

	function executeFunction(module:NvslVmModuleInstance, fn:NvbcFunction, args:Array<ScriptValue>):ScriptValue {
		var env = bindCallEnv(fn.paramNames, fn.paramTypes, args, module.env, fn.moduleName + "." + fn.name);
		return executeCode(module, fn.name, fn.code, env, fn.returnType);
	}

	function createExecutionFrame(
		value:ScriptValue,
		args:Array<ScriptValue>,
		moduleName:String,
		contextName:String
	):NvslVmExecutionFrame {
		return switch value {
			case VClosure(closure):
				createExecutionFrameFromClosure(closure, args);
			case VBuiltin(name):
				throw new ScriptError("Cannot start a VM execution from builtin '" + name + "'.");
			default:
				throw new ScriptError("Cannot execute non-function value " + ScriptValueTools.format(value) + " from '" + moduleName + "." + contextName + "'.");
		};
	}

	public function createExecutionFrameFromFunction(moduleName:String, functionName:String, args:Array<ScriptValue>):NvslVmExecutionFrame {
		var module = getModule(moduleName);
		var fn = getFunction(moduleName, functionName);
		var env = bindCallEnv(fn.paramNames, fn.paramTypes, args, module.env, moduleName + "." + functionName);
		return new NvslVmExecutionFrame(moduleName, fn.name, fn.exposed ? fn.name : null, fn.returnType, env, fn.code, 0, []);
	}

	function callValue(value:ScriptValue, args:Array<ScriptValue>, module:NvslVmModuleInstance, contextName:String):ScriptValue {
		return switch value {
			case VBuiltin(name):
				ScriptBuiltins.invoke(name, args, null);
			case VClosure(closure):
				executeClosure(closure, args, module, contextName);
			default:
				throw new ScriptError("Cannot call non-function value " + ScriptValueTools.format(value) + ".");
		};
	}

	function executeClosure(
		closure:ScriptClosure,
		args:Array<ScriptValue>,
		module:NvslVmModuleInstance,
		contextName:String
	):ScriptValue {
		if (closure.code == null) {
			throw new ScriptError("AST closures are not supported by the NVSL VM.");
		}

		var returnType = closure.returnType;
		var codeName = closure.codeName;

		if (returnType == null) {
			throw new ScriptError("VM closures must declare a return type.");
		}

		if (codeName == null) {
			throw new ScriptError("VM closures must carry a bytecode function name.");
		}
		var env = bindCallEnv(
			closure.paramNames,
			closure.paramTypes,
			args,
			closure.env,
			closure.name == null ? "lambda" : closure.moduleName + "." + closure.name
		);

		return executeCode(getModule(closure.moduleName), codeName, closure.code, env, returnType);
	}

	public function createExecutionFrameFromClosure(closure:ScriptClosure, args:Array<ScriptValue>):NvslVmExecutionFrame {
		if (closure.code == null) {
			throw new ScriptError("AST closures are not supported by the NVSL VM execution runner.");
		}

		if (closure.returnType == null) {
			throw new ScriptError("VM closures must declare a return type.");
		}

		if (closure.codeName == null) {
			throw new ScriptError("VM closures must carry a bytecode function name.");
		}

		var env = bindCallEnv(
			closure.paramNames,
			closure.paramTypes,
			args,
			closure.env,
			closure.name == null ? "lambda" : closure.moduleName + "." + closure.name
		);
		return new NvslVmExecutionFrame(
			closure.moduleName,
			closure.codeName,
			closure.name,
			closure.returnType,
			env,
			closure.code,
			0,
			[]
		);
	}

	function bindCallEnv(
		paramNames:Array<String>,
		paramTypes:Array<ScriptType>,
		args:Array<ScriptValue>,
		parentEnv:ScriptEnv,
		context:String
	):ScriptEnv {
		if (paramNames.length != args.length) {
			throw new ScriptError("Function '" + context + "' expects " + paramNames.length + " arguments.");
		}

		var env = new ScriptEnv(parentEnv);

		for (index in 0...paramNames.length) {
			var actualType = ScriptValueTools.typeOf(args[index]);
			var expectedType = paramTypes[index];

			if (!ScriptTypeTools.isAssignable(expectedType, actualType)) {
				throw new ScriptError(
					"Argument " + (index + 1) + " for '" + context + "' expects "
						+ ScriptTypeTools.format(expectedType) + " but found " + ScriptTypeTools.format(actualType) + "."
				);
			}

			env.define(paramNames[index], expectedType, true, args[index]);
		}

		return env;
	}

	function executeCode(
		module:NvslVmModuleInstance,
		contextName:String,
		code:Array<NvbcOp>,
		env:ScriptEnv,
		expectedType:ScriptType
	):ScriptValue {
		var stack:Array<ScriptValue> = [];
		var ip = 0;

		while (ip < code.length) {
			switch code[ip] {
				case PushVoid:
					stack.push(VVoid);
					ip++;
				case PushInt(value):
					stack.push(VInt(value));
					ip++;
				case PushFloat(value):
					stack.push(VFloat(value));
					ip++;
				case PushString(value):
					stack.push(VString(value));
					ip++;
				case PushBool(value):
					stack.push(VBool(value));
					ip++;
				case PushEnum(typeName, caseName):
					validateEnumValue(typeName, caseName);
					stack.push(VEnum(typeName, caseName));
					ip++;
				case LoadLocal(name):
					stack.push(env.get(name));
					ip++;
				case DefineLocal(name, type):
					var value = popValue(stack, "a local binding");
					var bindingType = type == null ? ScriptValueTools.typeOf(value) : type;

					if (ScriptTypeTools.equals(bindingType, TVoid)) {
						throw new ScriptError("Bindings cannot store Void values.");
					}

					if (!ScriptTypeTools.isAssignable(bindingType, ScriptValueTools.typeOf(value))) {
						throw new ScriptError(
							"Binding '" + name + "' expects " + ScriptTypeTools.format(bindingType)
								+ " but found " + ScriptTypeTools.format(ScriptValueTools.typeOf(value)) + "."
						);
					}

					env.define(name, bindingType, true, value);
					ip++;
				case StoreLocal(name):
					env.assign(name, popValue(stack, "an assignment value"));
					ip++;
				case LoadGlobal(targetModule, name):
					stack.push(getModule(targetModule).env.get(name));
					ip++;
				case StoreGlobal(targetModule, name):
					getModule(targetModule).env.assign(name, popValue(stack, "a global assignment value"));
					ip++;
				case EnterScope:
					env = new ScriptEnv(env);
					ip++;
				case ExitScope:
					var parent = env.parentEnv();

					if (parent == null) {
						throw new ScriptError("Cannot exit the root VM scope for '" + module.name + "." + contextName + "'.");
					}

					env = parent;
					ip++;
				case Pop:
					popValue(stack, "a discarded expression result");
					ip++;
				case MakeList(count):
					var items:Array<ScriptValue> = [];

					for (_ in 0...count) {
						items.push(popValue(stack, "a list element"));
					}

					items.reverse();
					stack.push(VList(items));
					ip++;
				case MakeRecord(typeName, fieldNames):
					var fieldValues:Array<ScriptValue> = [];

					for (_ in 0...fieldNames.length) {
						fieldValues.push(popValue(stack, "a record field value"));
					}

					fieldValues.reverse();
					stack.push(createRecordValue(typeName, fieldNames, fieldValues));
					ip++;
				case GetField(name):
					stack.push(evalFieldAccess(popValue(stack, "a field target"), name));
					ip++;
				case GetIndex:
					var index = popValue(stack, "an index");
					var target = popValue(stack, "an index target");
					stack.push(evalIndexAccess(target, index));
					ip++;
				case Unary(op):
					stack.push(evalUnary(op, popValue(stack, "a unary operand")));
					ip++;
				case Binary(op):
					var right = popValue(stack, "the right-hand operand");
					var left = popValue(stack, "the left-hand operand");
					stack.push(evalBinary(op, left, right));
					ip++;
				case Jump(target):
					validateJumpTarget(code, target, module.name, contextName);
					ip = target;
				case JumpIfFalse(target):
					validateJumpTarget(code, target, module.name, contextName);
					switch popValue(stack, "an if condition") {
						case VBool(false):
							ip = target;
						case VBool(true):
							ip++;
						default:
							throw new ScriptError("If conditions must evaluate to Bool.");
					}
				case MakeClosure(targetModule, name):
					stack.push(createFunctionValue(getModule(targetModule), getFunction(targetModule, name), env));
					ip++;
				case CallBuiltin(name, argCount):
					var args = popArgs(stack, argCount, "builtin '" + name + "'");
					stack.push(ScriptBuiltins.invoke(name, args, null));
					ip++;
				case CallFunction(targetModule, name, argCount):
					var args = popArgs(stack, argCount, "function '" + targetModule + "." + name + "'");
					stack.push(callFunction(targetModule, name, args));
					ip++;
				case CallValue(argCount):
					var args = popArgs(stack, argCount, "a function value call");
					var callee = popValue(stack, "a function value");
					stack.push(callValue(callee, args, module, contextName));
					ip++;
				case Return:
					var result = stack.length == 0 ? VVoid : stack.pop();

					if (stack.length != 0) {
						throw new ScriptError(
							"VM frame '" + module.name + "." + contextName + "' returned with leftover stack values."
						);
					}

					var actualType = ScriptValueTools.typeOf(result);

					if (!ScriptTypeTools.isAssignable(expectedType, actualType)) {
						throw new ScriptError(
							"'" + module.name + "." + contextName + "' returned " + ScriptTypeTools.format(actualType)
								+ " but expected " + ScriptTypeTools.format(expectedType) + "."
						);
					}

					return result;
			}
		}

		throw new ScriptError("VM reached the end of '" + module.name + "." + contextName + "' without a return.");
	}

	public function getFunction(moduleName:String, functionName:String):NvbcFunction {
		var module = getModule(moduleName);
		var fn = module.module.functions.get(functionName);

		if (fn == null) {
			throw new ScriptError("Unknown VM function '" + moduleName + "." + functionName + "'.");
		}

		return fn;
	}

	public function createFunctionValue(module:NvslVmModuleInstance, fn:NvbcFunction, env:ScriptEnv):ScriptValue {
		return VClosure(ScriptClosure.forBytecode(
			fn.exposed ? fn.name : null,
			fn.name,
			module.name,
			fn.paramNames,
			fn.paramTypes,
			fn.returnType,
			fn.code,
			env
		));
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
				var functionName:Dynamic = Reflect.field(data, "functionName");
				var envId:Dynamic = Reflect.field(data, "envId");

				if (!Std.isOfType(moduleName, String) || !Std.isOfType(functionName, String)) {
					throw new ScriptError("Invalid closure execution value in VM snapshot.");
				}

				var env = envId == null ? getModule(moduleName).env : envs.get(envId);

				if (env == null) {
					throw new ScriptError("VM execution snapshot references unknown closure environment '" + Std.string(envId) + "'.");
				}

				createFunctionValue(getModule(moduleName), getFunction(moduleName, functionName), env);
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
				throw new ScriptError("Unknown VM execution value kind '" + Std.string(kind) + "'.");
		};
	}

	public function getModule(name:String):NvslVmModuleInstance {
		var module = modules.get(name);

		if (module == null) {
			throw new ScriptError("Unknown VM module '" + name + "'.");
		}

		return module;
	}

	public function validateEnumValue(typeName:String, caseName:String):Void {
		var enumType = program.enums.get(typeName);

		if (enumType == null) {
			throw new ScriptError("Unknown enum '" + typeName + "' in NVBC.");
		}

		if (!Lambda.has(enumType.caseOrder, caseName)) {
			throw new ScriptError("Unknown enum case '" + typeName + "." + caseName + "' in NVBC.");
		}
	}

	public function validateJumpTarget(code:Array<NvbcOp>, target:Int, moduleName:String, contextName:String):Void {
		if (target < 0 || target >= code.length) {
			throw new ScriptError("Invalid jump target " + target + " in '" + moduleName + "." + contextName + "'.");
		}
	}

	public function popArgs(stack:Array<ScriptValue>, count:Int, context:String):Array<ScriptValue> {
		var args:Array<ScriptValue> = [];

		for (_ in 0...count) {
			args.push(popValue(stack, "an argument for " + context));
		}

		args.reverse();
		return args;
	}

	function popValue(stack:Array<ScriptValue>, context:String):ScriptValue {
		if (stack.length == 0) {
			throw new ScriptError("VM expected " + context + " but the stack was empty.");
		}

		return stack.pop();
	}

	public function createRecordValue(typeName:String, fieldNames:Array<String>, fieldValues:Array<ScriptValue>):ScriptValue {
		var structType = program.structs.get(typeName);

		if (structType == null) {
			throw new ScriptError("Unknown struct '" + typeName + "' in NVBC.");
		}

		if (fieldNames.length != fieldValues.length) {
			throw new ScriptError("Record build for '" + typeName + "' has mismatched field values.");
		}

		var fields = new StringMap<ScriptValue>();

		for (index in 0...fieldNames.length) {
			fields.set(fieldNames[index], fieldValues[index]);
		}

		for (fieldName in structType.fieldOrder) {
			if (!fields.exists(fieldName)) {
				throw new ScriptError("Missing field '" + fieldName + "' in record literal for '" + typeName + "'.");
			}
		}

		return VRecord(typeName, fields);
	}

	public function evalFieldAccess(target:ScriptValue, fieldName:String):ScriptValue {
		return switch target {
			case VRecord(_, fields):
				var value = fields.get(fieldName);

				if (value == null) {
					throw new ScriptError("Unknown record field '" + fieldName + "'.");
				}

				value;
			default:
				throw new ScriptError("Value " + ScriptValueTools.format(target) + " does not expose field '" + fieldName + "'.");
		};
	}

	public function evalIndexAccess(target:ScriptValue, index:ScriptValue):ScriptValue {
		return switch [target, index] {
			case [VList(items), VInt(position)]:
				if (position < 0 || position >= items.length) {
					throw new ScriptError("List index " + position + " is out of bounds.");
				}

				items[position];
			case [VList(_), _]:
				throw new ScriptError("List indices must be Int.");
			default:
				throw new ScriptError("Value " + ScriptValueTools.format(target) + " is not indexable.");
		};
	}

	public function evalUnary(op:ScriptUnaryOp, operand:ScriptValue):ScriptValue {
		return switch op {
			case Negate:
				switch operand {
					case VInt(value):
						VInt(-value);
					case VFloat(value):
						VFloat(-value);
					default:
						throw new ScriptError("Unary '-' expects an Int or Float.");
				}
			case Not:
				switch operand {
					case VBool(flag):
						VBool(!flag);
					default:
						throw new ScriptError("Unary '!' expects a Bool.");
				}
		};
	}

	public function evalBinary(op:ScriptBinaryOp, left:ScriptValue, right:ScriptValue):ScriptValue {
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
						throw new ScriptError("Operator '+' requires matching numeric types or two Strings.");
				}
			case Subtract:
				switch [left, right] {
					case [VInt(a), VInt(b)]:
						VInt(a - b);
					case [VFloat(a), VFloat(b)]:
						VFloat(a - b);
					default:
						throw new ScriptError("Operator '-' requires matching numeric types.");
				}
			case Multiply:
				switch [left, right] {
					case [VInt(a), VInt(b)]:
						VInt(a * b);
					case [VFloat(a), VFloat(b)]:
						VFloat(a * b);
					default:
						throw new ScriptError("Operator '*' requires matching numeric types.");
				}
			case Divide:
				switch [left, right] {
					case [VInt(a), VInt(b)]:
						if (b == 0) {
							throw new ScriptError("Division by zero.");
						}

						VInt(Std.int(a / b));
					case [VFloat(a), VFloat(b)]:
						if (b == 0.0) {
							throw new ScriptError("Division by zero.");
						}

						VFloat(a / b);
					default:
						throw new ScriptError("Operator '/' requires matching numeric types.");
				}
			case Modulo:
				switch [left, right] {
					case [VInt(a), VInt(b)]:
						if (b == 0) {
							throw new ScriptError("Modulo by zero.");
						}

						VInt(a % b);
					case [VFloat(a), VFloat(b)]:
						if (b == 0.0) {
							throw new ScriptError("Modulo by zero.");
						}

						VFloat(a % b);
					default:
						throw new ScriptError("Operator '%' requires matching numeric types.");
				}
			case Equal:
				VBool(valuesEqual(left, right));
			case NotEqual:
				VBool(!valuesEqual(left, right));
			case Less:
				compareNumeric(left, right, function(a, b) return a < b);
			case LessEqual:
				compareNumeric(left, right, function(a, b) return a <= b);
			case Greater:
				compareNumeric(left, right, function(a, b) return a > b);
			case GreaterEqual:
				compareNumeric(left, right, function(a, b) return a >= b);
			case And:
				switch [left, right] {
					case [VBool(a), VBool(b)]:
						VBool(a && b);
					default:
						throw new ScriptError("Operator '&&' requires Bool operands.");
				}
			case Or:
				switch [left, right] {
					case [VBool(a), VBool(b)]:
						VBool(a || b);
					default:
						throw new ScriptError("Operator '||' requires Bool operands.");
				}
		};
	}

	function compareNumeric(left:ScriptValue, right:ScriptValue, cmp:Float->Float->Bool):ScriptValue {
		return switch [left, right] {
			case [VInt(a), VInt(b)]:
				VBool(cmp(a, b));
			case [VFloat(a), VFloat(b)]:
				VBool(cmp(a, b));
			default:
				throw new ScriptError("Comparison operators require matching numeric types.");
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
}

private class NvslVmExecutionSnapshotBuilder {
	var runtime:NvslVmRuntime;
	var envIds:ObjectMap<ScriptEnv, Int>;
	var envEntries:Array<ScriptVmEnvSnapshotEntry>;
	var nextEnvId:Int;

	public function new(runtime:NvslVmRuntime) {
		this.runtime = runtime;
		this.envIds = new ObjectMap();
		this.envEntries = [];
		this.nextEnvId = 1;
	}

	public function build(frames:Array<NvslVmExecutionFrame>):ScriptVmExecutionSnapshotPayload {
		for (frame in frames) {
			captureEnv(frame.env, frame.moduleName);

			for (value in frame.values) {
				encodeValue(value);
			}
		}

		return ScriptSnapshotCodec.encodeVmExecutionSnapshot(
			runtime.createSnapshotData(),
			envEntries,
			[for (frame in frames) snapshotFrame(frame)]
		);
	}

	function snapshotFrame(frame:NvslVmExecutionFrame):ScriptVmFrameSnapshotEntry {
		return {
			moduleName: frame.moduleName,
			functionName: frame.functionName,
			envId: captureEnv(frame.env, frame.moduleName),
			ip: frame.ip,
			values: [for (value in frame.values) encodeValue(value)],
		};
	}

	function captureEnv(env:ScriptEnv, moduleName:String):Null<Int> {
		var moduleEnv = runtime.getModule(moduleName).env;

		if (env == moduleEnv) {
			return null;
		}

		var existing = envIds.get(env);

		if (existing != null) {
			return existing;
		}

		var parent = env.parentEnv();

		if (parent == null) {
			throw new ScriptError("Cannot snapshot VM environment without a module root for '" + moduleName + "'.");
		}

		var id = nextEnvId++;
		var parentId = captureEnv(parent, moduleName);
		var entry:ScriptVmEnvSnapshotEntry = {
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
				value: cell.initialized ? encodeValue(cell.value) : null,
			});
		}

		return id;
	}

	function encodeValue(value:ScriptValue):Dynamic {
		return switch value {
			case VVoid | VInt(_) | VFloat(_) | VString(_) | VBool(_) | VEnum(_, _):
				ScriptSnapshotCodec.encodeValue(value);
			case VBuiltin(name):
				{ kind: "builtin", name: name };
			case VClosure(closure):
				if (closure.code == null || closure.codeName == null) {
					throw new ScriptError("Cannot snapshot VM execution values containing non-bytecode closures.");
				}

				{
					kind: "closure",
					moduleName: closure.moduleName,
					functionName: closure.codeName,
					envId: captureEnv(closure.env, closure.moduleName),
				};
			case VList(items):
				{ kind: "list", items: [for (item in items) encodeValue(item)] };
			case VRecord(typeName, fields):
				var encodedFields = {};

				for (fieldName => fieldValue in fields) {
					Reflect.setField(encodedFields, fieldName, encodeValue(fieldValue));
				}

				{ kind: "record", type: typeName, fields: encodedFields };
		};
	}
}
