package novel.script.bytecode;

import haxe.Json;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.ds.StringMap;
import novel.script.ScriptError;
import novel.script.bytecode.Nvbc.NvbcEnumType;
import novel.script.bytecode.Nvbc.NvbcFunction;
import novel.script.bytecode.Nvbc.NvbcGlobal;
import novel.script.bytecode.Nvbc.NvbcModule;
import novel.script.bytecode.Nvbc.NvbcOp;
import novel.script.bytecode.Nvbc.NvbcProgram;
import novel.script.bytecode.Nvbc.NvbcStructType;
import novel.script.runtime.ScriptSnapshot.ScriptSnapshotCodec;

class NvbcCodec {
	public static inline var FORMAT = "novelvisual.nvbc";
	public static inline var VERSION = 2;
	static inline var SERIAL_PREFIX = "NVBCS:";

	public static function stringifyProgram(program:NvbcProgram):String {
		return SERIAL_PREFIX + Serializer.run(encodeProgram(program));
	}

	public static function parseProgram(content:String):NvbcProgram {
		if (StringTools.startsWith(content, SERIAL_PREFIX)) {
			return decodeProgram(Unserializer.run(content.substr(SERIAL_PREFIX.length)));
		}

		return decodeProgram(Json.parse(content));
	}

	public static function encodeProgram(program:NvbcProgram):Dynamic {
		var moduleEntries:Array<Dynamic> = [];

		for (moduleName in program.moduleOrder) {
			moduleEntries.push(encodeModule(program.modules.get(moduleName)));
		}

		var structNames = [for (name => _ in program.structs) name];
		structNames.sort(compareStrings);
		var structEntries = [for (name in structNames) encodeStruct(program.structs.get(name))];

		var enumNames = [for (name => _ in program.enums) name];
		enumNames.sort(compareStrings);
		var enumEntries = [for (name in enumNames) encodeEnum(program.enums.get(name))];

		return {
			format: FORMAT,
			version: VERSION,
			snapshotSchema: program.snapshotSchema,
			defaultEntryModule: program.defaultEntryModule,
			defaultEntryExport: program.defaultEntryExport,
			modules: moduleEntries,
			structs: structEntries,
			enums: enumEntries,
		};
	}

	public static function decodeProgram(data:Dynamic):NvbcProgram {
		if (data == null) {
			throw new ScriptError("NVBC payload is empty.");
		}

		var format:Dynamic = Reflect.field(data, "format");
		var version:Dynamic = Reflect.field(data, "version");
		var modulesData:Dynamic = Reflect.field(data, "modules");
		var structsData:Dynamic = Reflect.field(data, "structs");
		var enumsData:Dynamic = Reflect.field(data, "enums");
		var snapshotSchema:Dynamic = Reflect.field(data, "snapshotSchema");

		if (!Std.isOfType(format, String) || format != FORMAT) {
			throw new ScriptError("Unsupported NVBC format.");
		}

		if (!Std.isOfType(version, Int) || version != VERSION) {
			throw new ScriptError("Unsupported NVBC version '" + Std.string(version) + "'.");
		}

		if (!Std.isOfType(modulesData, Array) || !Std.isOfType(structsData, Array) || !Std.isOfType(enumsData, Array)) {
			throw new ScriptError("NVBC payload is invalid.");
		}

		if (!Std.isOfType(snapshotSchema, String)) {
			throw new ScriptError("NVBC snapshot schema is missing.");
		}

		var modules = new StringMap<NvbcModule>();
		var moduleOrder:Array<String> = [];

		for (moduleEntry in cast(modulesData, Array<Dynamic>)) {
			var module = decodeModule(moduleEntry);
			modules.set(module.name, module);
			moduleOrder.push(module.name);
		}

		var structs = new StringMap<NvbcStructType>();

		for (structEntry in cast(structsData, Array<Dynamic>)) {
			var structType = decodeStruct(structEntry);
			structs.set(structType.name, structType);
		}

		var enums = new StringMap<NvbcEnumType>();

		for (enumEntry in cast(enumsData, Array<Dynamic>)) {
			var enumType = decodeEnum(enumEntry);
			enums.set(enumType.name, enumType);
		}

		var defaultEntryModule = cast Reflect.field(data, "defaultEntryModule");
		var defaultEntryExport = cast Reflect.field(data, "defaultEntryExport");
		return new NvbcProgram(modules, structs, enums, moduleOrder, snapshotSchema, defaultEntryModule, defaultEntryExport);
	}

	static function encodeModule(module:NvbcModule):Dynamic {
		var functionNames = [for (name => _ in module.functions) name];
		functionNames.sort(compareStrings);

		return {
			name: module.name,
			globals: [for (global in module.globals) encodeGlobal(global)],
			functions: [for (name in functionNames) encodeFunction(module.functions.get(name))],
		};
	}

	static function decodeModule(data:Dynamic):NvbcModule {
		var name:Dynamic = Reflect.field(data, "name");
		var globalsData:Dynamic = Reflect.field(data, "globals");
		var functionsData:Dynamic = Reflect.field(data, "functions");

		if (!Std.isOfType(name, String) || !Std.isOfType(globalsData, Array) || !Std.isOfType(functionsData, Array)) {
			throw new ScriptError("NVBC module payload is invalid.");
		}

		var globals:Array<NvbcGlobal> = [];

		for (globalEntry in cast(globalsData, Array<Dynamic>)) {
			globals.push(decodeGlobal(globalEntry));
		}

		var functions = new StringMap<NvbcFunction>();

		for (functionEntry in cast(functionsData, Array<Dynamic>)) {
			var fn = decodeFunction(functionEntry);
			functions.set(fn.name, fn);
		}

		return new NvbcModule(name, globals, functions);
	}

	static function encodeGlobal(global:NvbcGlobal):Dynamic {
		return {
			name: global.name,
			type: ScriptSnapshotCodec.encodeType(global.type),
			mutable: global.mutable,
			init: [for (op in global.init) encodeOp(op)],
		};
	}

	static function decodeGlobal(data:Dynamic):NvbcGlobal {
		return new NvbcGlobal(
			Reflect.field(data, "name"),
			ScriptSnapshotCodec.decodeType(Reflect.field(data, "type")),
			Reflect.field(data, "mutable"),
			[for (op in cast(Reflect.field(data, "init"), Array<Dynamic>)) decodeOp(op)]
		);
	}

	static function encodeFunction(fn:NvbcFunction):Dynamic {
		return {
			moduleName: fn.moduleName,
			name: fn.name,
			exposed: fn.exposed,
			paramNames: fn.paramNames.copy(),
			paramTypes: [for (paramType in fn.paramTypes) ScriptSnapshotCodec.encodeType(paramType)],
			returnType: ScriptSnapshotCodec.encodeType(fn.returnType),
			code: [for (op in fn.code) encodeOp(op)],
		};
	}

	static function decodeFunction(data:Dynamic):NvbcFunction {
		var paramTypes:Array<Dynamic> = cast Reflect.field(data, "paramTypes");
		var codeEntries:Array<Dynamic> = cast Reflect.field(data, "code");

		return new NvbcFunction(
			Reflect.field(data, "moduleName"),
			Reflect.field(data, "name"),
			Reflect.field(data, "exposed"),
			cast Reflect.field(data, "paramNames"),
			[for (paramType in paramTypes) ScriptSnapshotCodec.decodeType(paramType)],
			ScriptSnapshotCodec.decodeType(Reflect.field(data, "returnType")),
			[for (entry in codeEntries) decodeOp(entry)]
		);
	}

	static function encodeStruct(structType:NvbcStructType):Dynamic {
		return {
			name: structType.name,
			fieldOrder: structType.fieldOrder.copy(),
		};
	}

	static function decodeStruct(data:Dynamic):NvbcStructType {
		return new NvbcStructType(Reflect.field(data, "name"), cast Reflect.field(data, "fieldOrder"));
	}

	static function encodeEnum(enumType:NvbcEnumType):Dynamic {
		return {
			name: enumType.name,
			caseOrder: enumType.caseOrder.copy(),
		};
	}

	static function decodeEnum(data:Dynamic):NvbcEnumType {
		return new NvbcEnumType(Reflect.field(data, "name"), cast Reflect.field(data, "caseOrder"));
	}

	static function encodeOp(op:NvbcOp):Dynamic {
		return switch op {
			case PushVoid:
				{ op: "pushVoid" };
			case PushInt(value):
				{ op: "pushInt", value: value };
			case PushFloat(value):
				{ op: "pushFloat", value: value };
			case PushString(value):
				{ op: "pushString", value: value };
			case PushBool(value):
				{ op: "pushBool", value: value };
			case PushEnum(typeName, caseName):
				{ op: "pushEnum", typeName: typeName, caseName: caseName };
			case LoadLocal(name):
				{ op: "loadLocal", name: name };
			case DefineLocal(name, type):
				{ op: "defineLocal", name: name, type: type == null ? null : ScriptSnapshotCodec.encodeType(type) };
			case StoreLocal(name):
				{ op: "storeLocal", name: name };
			case LoadGlobal(moduleName, name):
				{ op: "loadGlobal", moduleName: moduleName, name: name };
			case StoreGlobal(moduleName, name):
				{ op: "storeGlobal", moduleName: moduleName, name: name };
			case EnterScope:
				{ op: "enterScope" };
			case ExitScope:
				{ op: "exitScope" };
			case Pop:
				{ op: "pop" };
			case MakeList(count):
				{ op: "makeList", count: count };
			case MakeRecord(typeName, fieldNames):
				{ op: "makeRecord", typeName: typeName, fieldNames: fieldNames.copy() };
			case GetField(name):
				{ op: "getField", name: name };
			case GetIndex:
				{ op: "getIndex" };
			case Unary(unaryOp):
				{ op: "unary", unaryOp: cast(unaryOp, String) };
			case Binary(binaryOp):
				{ op: "binary", binaryOp: cast(binaryOp, String) };
			case Jump(target):
				{ op: "jump", target: target };
			case JumpIfFalse(target):
				{ op: "jumpIfFalse", target: target };
			case MakeClosure(moduleName, name):
				{ op: "makeClosure", moduleName: moduleName, name: name };
			case CallBuiltin(name, argCount):
				{ op: "callBuiltin", name: name, argCount: argCount };
			case CallFunction(moduleName, name, argCount):
				{ op: "callFunction", moduleName: moduleName, name: name, argCount: argCount };
			case CallValue(argCount):
				{ op: "callValue", argCount: argCount };
			case Return:
				{ op: "return" };
		};
	}

	static function decodeOp(data:Dynamic):NvbcOp {
		var opName:String = Reflect.field(data, "op");

		return switch opName {
			case "pushVoid":
				PushVoid;
			case "pushInt":
				PushInt(Reflect.field(data, "value"));
			case "pushFloat":
				PushFloat(Reflect.field(data, "value"));
			case "pushString":
				PushString(Reflect.field(data, "value"));
			case "pushBool":
				PushBool(Reflect.field(data, "value"));
			case "pushEnum":
				PushEnum(Reflect.field(data, "typeName"), Reflect.field(data, "caseName"));
			case "loadLocal":
				LoadLocal(Reflect.field(data, "name"));
			case "defineLocal":
				var typeData = Reflect.field(data, "type");
				DefineLocal(Reflect.field(data, "name"), typeData == null ? null : ScriptSnapshotCodec.decodeType(typeData));
			case "storeLocal":
				StoreLocal(Reflect.field(data, "name"));
			case "loadGlobal":
				LoadGlobal(Reflect.field(data, "moduleName"), Reflect.field(data, "name"));
			case "storeGlobal":
				StoreGlobal(Reflect.field(data, "moduleName"), Reflect.field(data, "name"));
			case "enterScope":
				EnterScope;
			case "exitScope":
				ExitScope;
			case "pop":
				Pop;
			case "makeList":
				MakeList(Reflect.field(data, "count"));
			case "makeRecord":
				MakeRecord(Reflect.field(data, "typeName"), cast Reflect.field(data, "fieldNames"));
			case "getField":
				GetField(Reflect.field(data, "name"));
			case "getIndex":
				GetIndex;
			case "unary":
				Unary(cast Reflect.field(data, "unaryOp"));
			case "binary":
				Binary(cast Reflect.field(data, "binaryOp"));
			case "jump":
				Jump(Reflect.field(data, "target"));
			case "jumpIfFalse":
				JumpIfFalse(Reflect.field(data, "target"));
			case "makeClosure":
				MakeClosure(Reflect.field(data, "moduleName"), Reflect.field(data, "name"));
			case "callBuiltin":
				CallBuiltin(Reflect.field(data, "name"), Reflect.field(data, "argCount"));
			case "callFunction":
				CallFunction(Reflect.field(data, "moduleName"), Reflect.field(data, "name"), Reflect.field(data, "argCount"));
			case "callValue":
				CallValue(Reflect.field(data, "argCount"));
			case "return":
				Return;
			default:
				throw new ScriptError("Unknown NVBC op '" + opName + "'.");
		};
	}

	static function compareStrings(left:String, right:String):Int {
		return left < right ? -1 : left > right ? 1 : 0;
	}
}
