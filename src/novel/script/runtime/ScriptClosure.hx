package novel.script.runtime;

import novel.script.bytecode.Nvbc.NvbcOp;
import novel.script.syntax.ScriptAst.ScriptExpr;
import novel.script.semantics.ScriptType;

class ScriptClosure {
	public var name(default, null):Null<String>;
	public var codeName(default, null):Null<String>;
	public var moduleName(default, null):String;
	public var paramNames(default, null):Array<String>;
	public var paramTypes(default, null):Array<ScriptType>;
	public var returnType(default, null):Null<ScriptType>;
	public var body(default, null):Null<ScriptExpr>;
	public var code(default, null):Null<Array<NvbcOp>>;
	public var env(default, null):ScriptEnv;

	public function new(
		name:Null<String>,
		codeName:Null<String>,
		moduleName:String,
		paramNames:Array<String>,
		paramTypes:Array<ScriptType>,
		returnType:Null<ScriptType>,
		body:Null<ScriptExpr>,
		code:Null<Array<NvbcOp>>,
		env:ScriptEnv
	) {
		this.name = name;
		this.codeName = codeName;
		this.moduleName = moduleName;
		this.paramNames = paramNames;
		this.paramTypes = paramTypes;
		this.returnType = returnType;
		this.body = body;
		this.code = code;
		this.env = env;
	}

	public static function forAst(
		name:Null<String>,
		moduleName:String,
		paramNames:Array<String>,
		paramTypes:Array<ScriptType>,
		returnType:Null<ScriptType>,
		body:ScriptExpr,
		env:ScriptEnv
	):ScriptClosure {
		return new ScriptClosure(name, name, moduleName, paramNames, paramTypes, returnType, body, null, env);
	}

	public static function forBytecode(
		name:Null<String>,
		codeName:String,
		moduleName:String,
		paramNames:Array<String>,
		paramTypes:Array<ScriptType>,
		returnType:ScriptType,
		code:Array<NvbcOp>,
		env:ScriptEnv
	):ScriptClosure {
		return new ScriptClosure(name, codeName, moduleName, paramNames, paramTypes, returnType, null, code, env);
	}
}
