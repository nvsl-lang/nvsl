package novel.script.syntax;

typedef ScriptPath = Array<String>;

class ScriptProgram {
	public var moduleName(default, null):Null<ScriptPath>;
	public var imports(default, null):Array<ScriptImportDecl>;
	public var declarations(default, null):Array<ScriptDecl>;
	public var span(default, null):ScriptSpan;
	public var sourceText(default, null):String;

	public function new(
		moduleName:Null<ScriptPath>,
		imports:Array<ScriptImportDecl>,
		declarations:Array<ScriptDecl>,
		span:ScriptSpan,
		sourceText:String
	) {
		this.moduleName = moduleName;
		this.imports = imports;
		this.declarations = declarations;
		this.span = span;
		this.sourceText = sourceText;
	}
}

class ScriptImportDecl {
	public var path(default, null):ScriptPath;
	public var alias(default, null):Null<String>;
	public var span(default, null):ScriptSpan;

	public function new(path:ScriptPath, alias:Null<String>, span:ScriptSpan) {
		this.path = path;
		this.alias = alias;
		this.span = span;
	}

	public function aliasOrDefault():String {
		return alias == null ? path[path.length - 1] : alias;
	}
}

enum ScriptDecl {
	DFunction(decl:ScriptFunctionDecl);
	DValue(decl:ScriptValueDecl);
	DStruct(decl:ScriptStructDecl);
	DEnum(decl:ScriptEnumDecl);
}

class ScriptFunctionDecl {
	public var id(default, null):Int;
	public var name(default, null):String;
	public var params(default, null):Array<ScriptParam>;
	public var returnType(default, null):Null<ScriptTypeRef>;
	public var body(default, null):ScriptExpr;
	public var span(default, null):ScriptSpan;

	public function new(
		id:Int,
		name:String,
		params:Array<ScriptParam>,
		returnType:Null<ScriptTypeRef>,
		body:ScriptExpr,
		span:ScriptSpan
	) {
		this.id = id;
		this.name = name;
		this.params = params;
		this.returnType = returnType;
		this.body = body;
		this.span = span;
	}
}

class ScriptValueDecl {
	public var id(default, null):Int;
	public var name(default, null):String;
	public var type(default, null):Null<ScriptTypeRef>;
	public var value(default, null):ScriptExpr;
	public var span(default, null):ScriptSpan;

	public function new(id:Int, name:String, type:Null<ScriptTypeRef>, value:ScriptExpr, span:ScriptSpan) {
		this.id = id;
		this.name = name;
		this.type = type;
		this.value = value;
		this.span = span;
	}
}

class ScriptStructDecl {
	public var name(default, null):String;
	public var fields(default, null):Array<ScriptFieldDecl>;
	public var span(default, null):ScriptSpan;

	public function new(name:String, fields:Array<ScriptFieldDecl>, span:ScriptSpan) {
		this.name = name;
		this.fields = fields;
		this.span = span;
	}
}

class ScriptFieldDecl {
	public var name(default, null):String;
	public var type(default, null):ScriptTypeRef;
	public var span(default, null):ScriptSpan;

	public function new(name:String, type:ScriptTypeRef, span:ScriptSpan) {
		this.name = name;
		this.type = type;
		this.span = span;
	}
}

class ScriptEnumDecl {
	public var name(default, null):String;
	public var cases(default, null):Array<ScriptEnumCaseDecl>;
	public var span(default, null):ScriptSpan;

	public function new(name:String, cases:Array<ScriptEnumCaseDecl>, span:ScriptSpan) {
		this.name = name;
		this.cases = cases;
		this.span = span;
	}
}

class ScriptEnumCaseDecl {
	public var name(default, null):String;
	public var span(default, null):ScriptSpan;

	public function new(name:String, span:ScriptSpan) {
		this.name = name;
		this.span = span;
	}
}

class ScriptParam {
	public var name(default, null):String;
	public var type(default, null):ScriptTypeRef;
	public var span(default, null):ScriptSpan;

	public function new(name:String, type:ScriptTypeRef, span:ScriptSpan) {
		this.name = name;
		this.type = type;
		this.span = span;
	}
}

class ScriptTypeRef {
	public var path(default, null):ScriptPath;
	public var args(default, null):Array<ScriptTypeRef>;
	public var span(default, null):ScriptSpan;

	public function new(path:ScriptPath, args:Array<ScriptTypeRef>, span:ScriptSpan) {
		this.path = path;
		this.args = args;
		this.span = span;
	}
}

class ScriptAssign {
	public var id(default, null):Int;
	public var target(default, null):ScriptPath;
	public var value(default, null):ScriptExpr;
	public var span(default, null):ScriptSpan;

	public function new(id:Int, target:ScriptPath, value:ScriptExpr, span:ScriptSpan) {
		this.id = id;
		this.target = target;
		this.value = value;
		this.span = span;
	}
}

class ScriptRecordFieldInit {
	public var name(default, null):String;
	public var value(default, null):ScriptExpr;
	public var span(default, null):ScriptSpan;

	public function new(name:String, value:ScriptExpr, span:ScriptSpan) {
		this.name = name;
		this.value = value;
		this.span = span;
	}
}

enum ScriptStmt {
	SLet(binding:ScriptValueDecl);
	SSet(assign:ScriptAssign);
	SExpr(expr:ScriptExpr);
}

class ScriptExpr {
	public var id(default, null):Int;
	public var def(default, null):ScriptExprDef;
	public var span(default, null):ScriptSpan;

	public function new(id:Int, def:ScriptExprDef, span:ScriptSpan) {
		this.id = id;
		this.def = def;
		this.span = span;
	}
}

enum ScriptExprDef {
	EInt(value:Int);
	EFloat(value:Float);
	EString(value:String);
	EBool(value:Bool);
	EPath(path:ScriptPath);
	EList(elements:Array<ScriptExpr>);
	ERecord(typePath:ScriptPath, fields:Array<ScriptRecordFieldInit>);
	ELambda(params:Array<ScriptParam>, returnType:Null<ScriptTypeRef>, body:ScriptExpr);
	ECall(callee:ScriptExpr, args:Array<ScriptExpr>);
	EField(target:ScriptExpr, name:String);
	EIndex(target:ScriptExpr, index:ScriptExpr);
	EUnary(op:ScriptUnaryOp, expr:ScriptExpr);
	EBinary(op:ScriptBinaryOp, left:ScriptExpr, right:ScriptExpr);
	EIf(condition:ScriptExpr, thenBranch:ScriptExpr, elseBranch:ScriptExpr);
	EBlock(statements:Array<ScriptStmt>, tail:Null<ScriptExpr>);
}

enum abstract ScriptUnaryOp(String) {
	var Negate = "-";
	var Not = "!";
}

enum abstract ScriptBinaryOp(String) {
	var Add = "+";
	var Subtract = "-";
	var Multiply = "*";
	var Divide = "/";
	var Modulo = "%";
	var Equal = "==";
	var NotEqual = "!=";
	var Less = "<";
	var LessEqual = "<=";
	var Greater = ">";
	var GreaterEqual = ">=";
	var And = "&&";
	var Or = "||";
}

class ScriptPathTools {
	public static function format(path:ScriptPath):String {
		return path.join(".");
	}
}
