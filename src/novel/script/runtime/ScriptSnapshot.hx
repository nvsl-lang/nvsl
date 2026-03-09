package novel.script.runtime;

import haxe.Json;
import haxe.ds.StringMap;
import novel.script.ScriptError;
import novel.script.syntax.ScriptAst.ScriptBinaryOp;
import novel.script.syntax.ScriptAst.ScriptUnaryOp;
import novel.script.runtime.ScriptExecOp;
import novel.script.semantics.ScriptType;

typedef ScriptGlobalSnapshotEntry = {
	var initialized:Bool;
	@:optional var value:Dynamic;
}

typedef ScriptModuleSnapshotEntry = {
	var name:String;
	var values:Dynamic;
}

typedef ScriptProjectSnapshotPayload = {
	var format:String;
	var version:Int;
	var schema:String;
	var modules:Array<ScriptModuleSnapshotEntry>;
}

typedef ScriptCellSnapshotEntry = {
	var name:String;
	var type:Dynamic;
	var mutable:Bool;
	var initialized:Bool;
	@:optional var value:Dynamic;
}

typedef ScriptScopeSnapshotEntry = {
	var cells:Array<ScriptCellSnapshotEntry>;
}

typedef ScriptExecutionEnvSnapshotEntry = {
	var id:Int;
	var moduleName:String;
	@:optional var parentId:Null<Int>;
	var cells:Array<ScriptCellSnapshotEntry>;
}

typedef ScriptFrameSnapshotEntry = {
	var moduleName:String;
	@:optional var functionName:Null<String>;
	@:optional var returnType:Dynamic;
	@:optional var envId:Null<Int>;
	var ops:Array<Dynamic>;
	var values:Array<Dynamic>;
}

typedef ScriptExecutionSnapshotPayload = {
	var format:String;
	var version:Int;
	var project:ScriptProjectSnapshotPayload;
	var envs:Array<ScriptExecutionEnvSnapshotEntry>;
	var frames:Array<ScriptFrameSnapshotEntry>;
}

typedef ScriptVmEnvSnapshotEntry = {
	var id:Int;
	var moduleName:String;
	@:optional var parentId:Null<Int>;
	var cells:Array<ScriptCellSnapshotEntry>;
}

typedef ScriptVmFrameSnapshotEntry = {
	var moduleName:String;
	var functionName:String;
	@:optional var envId:Null<Int>;
	var ip:Int;
	var values:Array<Dynamic>;
}

typedef ScriptVmExecutionSnapshotPayload = {
	var format:String;
	var version:Int;
	var project:ScriptProjectSnapshotPayload;
	var envs:Array<ScriptVmEnvSnapshotEntry>;
	var frames:Array<ScriptVmFrameSnapshotEntry>;
}

class ScriptSnapshotCodec {
	public static inline var SNAPSHOT_FORMAT = "novelvisual.script.snapshot";
	public static inline var SNAPSHOT_VERSION = 1;
	public static inline var EXECUTION_SNAPSHOT_FORMAT = "novelvisual.script.execution";
	public static inline var EXECUTION_SNAPSHOT_VERSION = 2;
	public static inline var VM_EXECUTION_SNAPSHOT_FORMAT = "novelvisual.nvslvm.execution";
	public static inline var VM_EXECUTION_SNAPSHOT_VERSION = 1;

	public static function encodeValue(value:ScriptValue):Dynamic {
		return switch value {
			case VVoid:
				{ kind: "void" };
			case VInt(number):
				{ kind: "int", value: number };
			case VFloat(number):
				{ kind: "float", value: number };
			case VString(text):
				{ kind: "string", value: text };
			case VBool(flag):
				{ kind: "bool", value: flag };
			case VList(items):
				{ kind: "list", items: [for (item in items) encodeValue(item)] };
			case VRecord(typeName, fields):
				var encodedFields = {};

				for (name => fieldValue in fields) {
					Reflect.setField(encodedFields, name, encodeValue(fieldValue));
				}

				{ kind: "record", type: typeName, fields: encodedFields };
			case VEnum(typeName, caseName):
				{ kind: "enum", type: typeName, caseName: caseName };
			case VClosure(_) | VBuiltin(_):
				throw new ScriptError("Cannot snapshot non-serializable runtime values.");
		};
	}

	public static function decodeValue(data:Dynamic):ScriptValue {
		var kind:String = Reflect.field(data, "kind");

		return switch kind {
			case "void":
				VVoid;
			case "int":
				VInt(Reflect.field(data, "value"));
			case "float":
				VFloat(Reflect.field(data, "value"));
			case "string":
				VString(Reflect.field(data, "value"));
			case "bool":
				VBool(Reflect.field(data, "value"));
			case "list":
				var items:Array<ScriptValue> = [];

				for (item in cast(Reflect.field(data, "items"), Array<Dynamic>)) {
					items.push(decodeValue(item));
				}

				VList(items);
			case "record":
				var fields = new StringMap<ScriptValue>();
				var encodedFields = Reflect.field(data, "fields");

				for (fieldName in Reflect.fields(encodedFields)) {
					fields.set(fieldName, decodeValue(Reflect.field(encodedFields, fieldName)));
				}

				VRecord(Reflect.field(data, "type"), fields);
			case "enum":
				VEnum(Reflect.field(data, "type"), Reflect.field(data, "caseName"));
			default:
				throw new ScriptError("Unknown snapshot value kind '" + kind + "'.");
		};
	}

	public static function stringify(data:Dynamic):String {
		return Json.stringify(data);
	}

	public static function parse(json:String):Dynamic {
		return Json.parse(json);
	}

	public static function encodeType(type:ScriptType):Dynamic {
		return switch type {
			case TVoid:
				{ kind: "void" };
			case TInt:
				{ kind: "int" };
			case TFloat:
				{ kind: "float" };
			case TString:
				{ kind: "string" };
			case TBool:
				{ kind: "bool" };
			case TList(itemType):
				{ kind: "list", itemType: encodeType(itemType) };
			case TRecord(name):
				{ kind: "record", name: name };
			case TEnum(name):
				{ kind: "enum", name: name };
			case TFunction(paramTypes, returnType):
				{ kind: "function", params: [for (paramType in paramTypes) encodeType(paramType)], returnType: encodeType(returnType) };
			case TBuiltin(name):
				{ kind: "builtin", name: name };
		};
	}

	public static function decodeType(data:Dynamic):ScriptType {
		var kind:String = Reflect.field(data, "kind");

		return switch kind {
			case "void":
				TVoid;
			case "int":
				TInt;
			case "float":
				TFloat;
			case "string":
				TString;
			case "bool":
				TBool;
			case "list":
				TList(decodeType(Reflect.field(data, "itemType")));
			case "record":
				TRecord(Reflect.field(data, "name"));
			case "enum":
				TEnum(Reflect.field(data, "name"));
			case "function":
				var params:Array<ScriptType> = [];
				for (param in cast(Reflect.field(data, "params"), Array<Dynamic>)) {
					params.push(decodeType(param));
				}
				TFunction(params, decodeType(Reflect.field(data, "returnType")));
			case "builtin":
				TBuiltin(Reflect.field(data, "name"));
			default:
				throw new ScriptError("Unknown snapshot type kind '" + kind + "'.");
		};
	}

	public static function encodeProjectSnapshot(schema:String, modules:Array<ScriptModuleSnapshotEntry>):ScriptProjectSnapshotPayload {
		return {
			format: SNAPSHOT_FORMAT,
			version: SNAPSHOT_VERSION,
			schema: schema,
			modules: modules,
		};
	}

	public static function decodeProjectSnapshot(data:Dynamic):ScriptProjectSnapshotPayload {
		if (data == null) {
			throw new ScriptError("Snapshot payload is empty.");
		}

		var format:Dynamic = Reflect.field(data, "format");
		var version:Dynamic = Reflect.field(data, "version");
		var schema:Dynamic = Reflect.field(data, "schema");
		var modules:Dynamic = Reflect.field(data, "modules");

		if (!Std.isOfType(format, String) || format != SNAPSHOT_FORMAT) {
			throw new ScriptError("Unsupported snapshot format.");
		}

		if (!Std.isOfType(version, Int) || version != SNAPSHOT_VERSION) {
			throw new ScriptError("Unsupported snapshot version '" + Std.string(version) + "'.");
		}

		if (!Std.isOfType(schema, String)) {
			throw new ScriptError("Snapshot schema is missing.");
		}

		if (!Std.isOfType(modules, Array)) {
			throw new ScriptError("Snapshot modules payload is invalid.");
		}

		return cast data;
	}

	public static function encodeExecutionSnapshot(
		project:ScriptProjectSnapshotPayload,
		envs:Array<ScriptExecutionEnvSnapshotEntry>,
		frames:Array<ScriptFrameSnapshotEntry>
	):ScriptExecutionSnapshotPayload {
		return {
			format: EXECUTION_SNAPSHOT_FORMAT,
			version: EXECUTION_SNAPSHOT_VERSION,
			project: project,
			envs: envs,
			frames: frames,
		};
	}

	public static function decodeExecutionSnapshot(data:Dynamic):ScriptExecutionSnapshotPayload {
		if (data == null) {
			throw new ScriptError("Execution snapshot payload is empty.");
		}

		var format:Dynamic = Reflect.field(data, "format");
		var version:Dynamic = Reflect.field(data, "version");
		var project:Dynamic = Reflect.field(data, "project");
		var envs:Dynamic = Reflect.field(data, "envs");
		var frames:Dynamic = Reflect.field(data, "frames");

		if (!Std.isOfType(format, String) || format != EXECUTION_SNAPSHOT_FORMAT) {
			throw new ScriptError("Unsupported execution snapshot format.");
		}

		if (!Std.isOfType(version, Int) || version != EXECUTION_SNAPSHOT_VERSION) {
			throw new ScriptError("Unsupported execution snapshot version '" + Std.string(version) + "'.");
		}

		decodeProjectSnapshot(project);

		if (!Std.isOfType(envs, Array) || !Std.isOfType(frames, Array)) {
			throw new ScriptError("Execution snapshot frames payload is invalid.");
		}

		return cast data;
	}

	public static function encodeVmExecutionSnapshot(
		project:ScriptProjectSnapshotPayload,
		envs:Array<ScriptVmEnvSnapshotEntry>,
		frames:Array<ScriptVmFrameSnapshotEntry>
	):ScriptVmExecutionSnapshotPayload {
		return {
			format: VM_EXECUTION_SNAPSHOT_FORMAT,
			version: VM_EXECUTION_SNAPSHOT_VERSION,
			project: project,
			envs: envs,
			frames: frames,
		};
	}

	public static function decodeVmExecutionSnapshot(data:Dynamic):ScriptVmExecutionSnapshotPayload {
		if (data == null) {
			throw new ScriptError("VM execution snapshot payload is empty.");
		}

		var format:Dynamic = Reflect.field(data, "format");
		var version:Dynamic = Reflect.field(data, "version");
		var project:Dynamic = Reflect.field(data, "project");
		var envs:Dynamic = Reflect.field(data, "envs");
		var frames:Dynamic = Reflect.field(data, "frames");

		if (!Std.isOfType(format, String) || format != VM_EXECUTION_SNAPSHOT_FORMAT) {
			throw new ScriptError("Unsupported VM execution snapshot format.");
		}

		if (!Std.isOfType(version, Int) || version != VM_EXECUTION_SNAPSHOT_VERSION) {
			throw new ScriptError("Unsupported VM execution snapshot version '" + Std.string(version) + "'.");
		}

		decodeProjectSnapshot(project);

		if (!Std.isOfType(envs, Array) || !Std.isOfType(frames, Array)) {
			throw new ScriptError("VM execution snapshot payload is invalid.");
		}

		return cast data;
	}

	public static function encodeExecOp(op:Dynamic):Dynamic {
		return switch cast(op, ScriptExecOp) {
			case OEval(exprId):
				{ kind: "eval", exprId: exprId };
			case OPushVoid:
				{ kind: "pushVoid" };
			case OEnterScope:
				{ kind: "enterScope" };
			case OExitScope:
				{ kind: "exitScope" };
			case ODiscard:
				{ kind: "discard" };
			case OBind(valueDeclId):
				{ kind: "bind", valueDeclId: valueDeclId };
			case OAssign(assignId):
				{ kind: "assign", assignId: assignId };
			case OBuildList(count):
				{ kind: "buildList", count: count };
			case OBuildRecord(typeName, fieldNames):
				{ kind: "buildRecord", typeName: typeName, fieldNames: fieldNames.copy() };
			case OApplyUnary(unaryOp):
				{ kind: "applyUnary", op: cast(unaryOp, String) };
			case OApplyBinary(binaryOp):
				{ kind: "applyBinary", op: cast(binaryOp, String) };
			case OApplyField(name):
				{ kind: "applyField", name: name };
			case OApplyIndex:
				{ kind: "applyIndex" };
			case OBranch(thenExprId, elseExprId):
				{ kind: "branch", thenExprId: thenExprId, elseExprId: elseExprId };
			case OCall(argCount):
				{ kind: "call", argCount: argCount };
		};
	}

	public static function decodeExecOp(data:Dynamic):Dynamic {
		var kind:String = Reflect.field(data, "kind");

		return switch kind {
			case "eval":
				OEval(Reflect.field(data, "exprId"));
			case "pushVoid":
				OPushVoid;
			case "enterScope":
				OEnterScope;
			case "exitScope":
				OExitScope;
			case "discard":
				ODiscard;
			case "bind":
				OBind(Reflect.field(data, "valueDeclId"));
			case "assign":
				OAssign(Reflect.field(data, "assignId"));
			case "buildList":
				OBuildList(Reflect.field(data, "count"));
			case "buildRecord":
				OBuildRecord(Reflect.field(data, "typeName"), cast Reflect.field(data, "fieldNames"));
			case "applyUnary":
				OApplyUnary(cast Reflect.field(data, "op"));
			case "applyBinary":
				OApplyBinary(cast Reflect.field(data, "op"));
			case "applyField":
				OApplyField(Reflect.field(data, "name"));
			case "applyIndex":
				OApplyIndex;
			case "branch":
				OBranch(Reflect.field(data, "thenExprId"), Reflect.field(data, "elseExprId"));
			case "call":
				OCall(Reflect.field(data, "argCount"));
			default:
				throw new ScriptError("Unknown execution op kind '" + kind + "'.");
		};
	}
}
