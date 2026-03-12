package novel.script.runtime;

import haxe.ds.StringMap;
import novel.script.semantics.ScriptType;

enum ScriptValue {
	VVoid;
	VInt(value:Int);
	VFloat(value:Float);
	VString(value:String);
	VBool(value:Bool);
	VList(items:Array<ScriptValue>);
	VRecord(typeName:String, fields:StringMap<ScriptValue>);
	VEnum(typeName:String, caseName:String);
	VClosure(closure:ScriptClosure);
	VBuiltin(name:String);
}

class ScriptValueTools {
	public static function typeOf(value:ScriptValue):ScriptType {
		return switch value {
			case VVoid: TVoid;
			case VInt(_): TInt;
			case VFloat(_): TFloat;
			case VString(_): TString;
			case VBool(_): TBool;
			case VList(items):
				if (items.length == 0) {
					TList(TVoid);
				} else {
					TList(typeOf(items[0]));
				}
			case VRecord(typeName, _):
				TRecord(typeName);
			case VEnum(typeName, _):
				TEnum(typeName);
			case VClosure(closure):
				TFunction(closure.paramTypes, closure.returnType == null ? TVoid : closure.returnType);
			case VBuiltin(name):
				TBuiltin(name);
		};
	}

	public static function format(value:ScriptValue):String {
		return switch value {
			case VVoid:
				"void";
			case VInt(number):
				Std.string(number);
			case VFloat(number):
				Std.string(number);
			case VString(text):
				text;
			case VBool(flag):
				flag ? "true" : "false";
			case VList(items):
				"[" + [for (item in items) format(item)].join(", ") + "]";
			case VRecord(typeName, fields):
				var parts:Array<String> = [];

				for (name => fieldValue in fields) {
					parts.push(name + ": " + format(fieldValue));
				}

				typeName + " { " + parts.join(", ") + " }";
			case VEnum(typeName, caseName):
				typeName + "." + caseName;
			case VClosure(closure):
				var label = closure.name == null ? "<lambda>" : closure.name;
				"<closure " + label + ">";
			case VBuiltin(name):
				"<builtin " + name + ">";
		};
	}

	public static function isSerializable(value:ScriptValue):Bool {
		return switch value {
			case VVoid | VInt(_) | VFloat(_) | VString(_) | VBool(_) | VEnum(_, _):
				true;
			case VList(items):
				var serializable = true;

				for (item in items) {
					if (!isSerializable(item)) {
						serializable = false;
						break;
					}
				}

				serializable;
			case VRecord(_, fields):
				var serializable = true;

				for (_ => fieldValue in fields) {
					if (!isSerializable(fieldValue)) {
						serializable = false;
						break;
					}
				}

				serializable;
			case VClosure(_) | VBuiltin(_):
				false;
		};
	}

	public static function equals(left:ScriptValue, right:ScriptValue):Bool {
		return switch [left, right] {
			case [VVoid, VVoid]: true;
			case [VInt(l), VInt(r)]: l == r;
			case [VFloat(l), VFloat(r)]: l == r;
			case [VString(l), VString(r)]: l == r;
			case [VBool(l), VBool(r)]: l == r;
			case [VEnum(lt, lc), VEnum(rt, rc)]: lt == rt && lc == rc;
			case [VList(l), VList(r)]:
				if (l.length != r.length) return false;
				for (i in 0...l.length) {
					if (!equals(l[i], r[i])) return false;
				}
				true;
			case [VRecord(lt, lf), VRecord(rt, rf)]:
				if (lt != rt) return false;
				var lKeys = [for (k in lf.keys()) k];
				var rKeys = [for (k in rf.keys()) k];
				if (lKeys.length != rKeys.length) return false;
				for (k in lKeys) {
					if (!rf.exists(k) || !equals(lf.get(k), rf.get(k))) return false;
				}
				true;
			case [VClosure(l), VClosure(r)]: l == r;
			case [VBuiltin(l), VBuiltin(r)]: l == r;
			default: false;
		};
	}
}
