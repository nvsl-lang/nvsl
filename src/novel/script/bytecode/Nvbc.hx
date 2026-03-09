package novel.script.bytecode;

import haxe.ds.StringMap;
import novel.script.semantics.ScriptType;
import novel.script.syntax.ScriptAst.ScriptBinaryOp;
import novel.script.syntax.ScriptAst.ScriptUnaryOp;

class NvbcProgram {
	public var modules(default, null):StringMap<NvbcModule>;
	public var structs(default, null):StringMap<NvbcStructType>;
	public var enums(default, null):StringMap<NvbcEnumType>;
	public var moduleOrder(default, null):Array<String>;
	public var snapshotSchema(default, null):String;
	public var defaultEntryModule(default, null):Null<String>;
	public var defaultEntryExport(default, null):Null<String>;

	public function new(
		modules:StringMap<NvbcModule>,
		structs:StringMap<NvbcStructType>,
		enums:StringMap<NvbcEnumType>,
		moduleOrder:Array<String>,
		snapshotSchema:String,
		defaultEntryModule:Null<String>,
		defaultEntryExport:Null<String>
	) {
		this.modules = modules;
		this.structs = structs;
		this.enums = enums;
		this.moduleOrder = moduleOrder;
		this.snapshotSchema = snapshotSchema;
		this.defaultEntryModule = defaultEntryModule;
		this.defaultEntryExport = defaultEntryExport;
	}
}

class NvbcModule {
	public var name(default, null):String;
	public var globals(default, null):Array<NvbcGlobal>;
	public var functions(default, null):StringMap<NvbcFunction>;

	public function new(name:String, globals:Array<NvbcGlobal>, functions:StringMap<NvbcFunction>) {
		this.name = name;
		this.globals = globals;
		this.functions = functions;
	}
}

class NvbcGlobal {
	public var name(default, null):String;
	public var type(default, null):ScriptType;
	public var mutable(default, null):Bool;
	public var init(default, null):Array<NvbcOp>;

	public function new(name:String, type:ScriptType, mutable:Bool, init:Array<NvbcOp>) {
		this.name = name;
		this.type = type;
		this.mutable = mutable;
		this.init = init;
	}
}

class NvbcFunction {
	public var moduleName(default, null):String;
	public var name(default, null):String;
	public var exposed(default, null):Bool;
	public var paramNames(default, null):Array<String>;
	public var paramTypes(default, null):Array<ScriptType>;
	public var returnType(default, null):ScriptType;
	public var code(default, null):Array<NvbcOp>;

	public function new(
		moduleName:String,
		name:String,
		exposed:Bool,
		paramNames:Array<String>,
		paramTypes:Array<ScriptType>,
		returnType:ScriptType,
		code:Array<NvbcOp>
	) {
		this.moduleName = moduleName;
		this.name = name;
		this.exposed = exposed;
		this.paramNames = paramNames;
		this.paramTypes = paramTypes;
		this.returnType = returnType;
		this.code = code;
	}
}

class NvbcStructType {
	public var name(default, null):String;
	public var fieldOrder(default, null):Array<String>;

	public function new(name:String, fieldOrder:Array<String>) {
		this.name = name;
		this.fieldOrder = fieldOrder;
	}
}

class NvbcEnumType {
	public var name(default, null):String;
	public var caseOrder(default, null):Array<String>;

	public function new(name:String, caseOrder:Array<String>) {
		this.name = name;
		this.caseOrder = caseOrder;
	}
}

enum NvbcOp {
	PushVoid;
	PushInt(value:Int);
	PushFloat(value:Float);
	PushString(value:String);
	PushBool(value:Bool);
	PushEnum(typeName:String, caseName:String);
	LoadLocal(name:String);
	DefineLocal(name:String, type:Null<ScriptType>);
	StoreLocal(name:String);
	LoadGlobal(moduleName:String, name:String);
	StoreGlobal(moduleName:String, name:String);
	EnterScope;
	ExitScope;
	Pop;
	MakeList(count:Int);
	MakeRecord(typeName:String, fieldNames:Array<String>);
	GetField(name:String);
	GetIndex;
	Unary(op:ScriptUnaryOp);
	Binary(op:ScriptBinaryOp);
	Jump(target:Int);
	JumpIfFalse(target:Int);
	MakeClosure(moduleName:String, name:String);
	CallBuiltin(name:String, argCount:Int);
	CallFunction(moduleName:String, name:String, argCount:Int);
	CallValue(argCount:Int);
	Return;
}
