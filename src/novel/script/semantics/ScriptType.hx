package novel.script.semantics;

enum ScriptType {
	TVoid;
	TInt;
	TFloat;
	TString;
	TBool;
	TList(itemType:ScriptType);
	TRecord(name:String);
	TEnum(name:String);
	TFunction(paramTypes:Array<ScriptType>, returnType:ScriptType);
	TBuiltin(name:String);
}

class ScriptTypeTools {
	public static function format(type:ScriptType):String {
		return switch type {
			case TVoid: "Void";
			case TInt: "Int";
			case TFloat: "Float";
			case TString: "String";
			case TBool: "Bool";
			case TList(itemType):
				"List<" + format(itemType) + ">";
			case TRecord(name):
				name;
			case TEnum(name):
				name;
			case TBuiltin(name):
				"Builtin<" + name + ">";
			case TFunction(paramTypes, returnType):
				var args = [for (paramType in paramTypes) format(paramType)];
				"fn(" + args.join(", ") + ") -> " + format(returnType);
		};
	}

	public static function equals(left:ScriptType, right:ScriptType):Bool {
		return switch [left, right] {
			case [TVoid, TVoid] | [TInt, TInt] | [TFloat, TFloat] | [TString, TString] | [TBool, TBool]:
				true;
			case [TBuiltin(leftName), TBuiltin(rightName)]:
				leftName == rightName;
			case [TRecord(leftName), TRecord(rightName)]:
				leftName == rightName;
			case [TEnum(leftName), TEnum(rightName)]:
				leftName == rightName;
			case [TList(leftItem), TList(rightItem)]:
				equals(leftItem, rightItem);
			case [TFunction(leftParams, leftReturn), TFunction(rightParams, rightReturn)]:
				if (leftParams.length != rightParams.length) {
					false;
				} else {
					var matches = true;

					for (index in 0...leftParams.length) {
						if (!equals(leftParams[index], rightParams[index])) {
							matches = false;
							break;
						}
					}

					matches && equals(leftReturn, rightReturn);
				}
			default:
				false;
		};
	}

	public static function isAssignable(expected:ScriptType, actual:ScriptType):Bool {
		return equals(expected, actual);
	}

	public static function isNumeric(type:ScriptType):Bool {
		return switch type {
			case TInt | TFloat: true;
			default: false;
		};
	}

	public static function isPrimitive(type:ScriptType):Bool {
		return switch type {
			case TInt | TFloat | TString | TBool: true;
			default: false;
		};
	}

	public static function isSerializable(type:ScriptType):Bool {
		return switch type {
			case TVoid | TInt | TFloat | TString | TBool | TEnum(_):
				true;
			case TList(itemType):
				isSerializable(itemType);
			case TRecord(_):
				true;
			case TFunction(_, _) | TBuiltin(_):
				false;
		};
	}
}
