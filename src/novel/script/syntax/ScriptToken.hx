package novel.script.syntax;

enum abstract ScriptTokenKind(Int) {
	var TEndOfFile = 0;
	var TIdentifier = 1;
	var TIntLiteral = 2;
	var TFloatLiteral = 3;
	var TStringLiteral = 4;
	var TModule = 5;
	var TImport = 6;
	var TAs = 7;
	var TStruct = 8;
	var TEnum = 9;
	var TFn = 10;
	var TLet = 11;
	var TSet = 12;
	var TIf = 13;
	var TElse = 14;
	var TTrue = 15;
	var TFalse = 16;
	var TLeftParen = 17;
	var TRightParen = 18;
	var TLeftBrace = 19;
	var TRightBrace = 20;
	var TLeftBracket = 21;
	var TRightBracket = 22;
	var TComma = 23;
	var TColon = 24;
	var TSemicolon = 25;
	var TDot = 26;
	var TEqual = 27;
	var TArrow = 28;
	var TFatArrow = 29;
	var TPlus = 30;
	var TMinus = 31;
	var TStar = 32;
	var TSlash = 33;
	var TPercent = 34;
	var TBang = 35;
	var TAndAnd = 36;
	var TOrOr = 37;
	var TEqualEqual = 38;
	var TBangEqual = 39;
	var TLess = 40;
	var TLessEqual = 41;
	var TGreater = 42;
	var TGreaterEqual = 43;
}

class ScriptTokenKindTools {
	public static function label(kind:ScriptTokenKind):String {
		return switch kind {
			case TEndOfFile: "end of file";
			case TIdentifier: "identifier";
			case TIntLiteral: "integer";
			case TFloatLiteral: "float";
			case TStringLiteral: "string";
			case TModule: "module";
			case TImport: "import";
			case TAs: "as";
			case TStruct: "struct";
			case TEnum: "enum";
			case TFn: "fn";
			case TLet: "let";
			case TSet: "set";
			case TIf: "if";
			case TElse: "else";
			case TTrue: "true";
			case TFalse: "false";
			case TLeftParen: "(";
			case TRightParen: ")";
			case TLeftBrace: "{";
			case TRightBrace: "}";
			case TLeftBracket: "[";
			case TRightBracket: "]";
			case TComma: ",";
			case TColon: ":";
			case TSemicolon: ";";
			case TDot: ".";
			case TEqual: "=";
			case TArrow: "->";
			case TFatArrow: "=>";
			case TPlus: "+";
			case TMinus: "-";
			case TStar: "*";
			case TSlash: "/";
			case TPercent: "%";
			case TBang: "!";
			case TAndAnd: "&&";
			case TOrOr: "||";
			case TEqualEqual: "==";
			case TBangEqual: "!=";
			case TLess: "<";
			case TLessEqual: "<=";
			case TGreater: ">";
			case TGreaterEqual: ">=";
		};
	}
}

class ScriptToken {
	public var kind(default, null):ScriptTokenKind;
	public var text(default, null):String;
	public var span(default, null):ScriptSpan;

	public function new(kind:ScriptTokenKind, text:String, span:ScriptSpan) {
		this.kind = kind;
		this.text = text;
		this.span = span;
	}

	public inline function is(kind:ScriptTokenKind):Bool {
		return this.kind == kind;
	}

	public function toString():String {
		return ScriptTokenKindTools.label(kind) + " \"" + text + "\" at " + span.toString();
	}
}
