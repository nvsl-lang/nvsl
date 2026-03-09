package novel.script.runtime;

import novel.script.ScriptError;
import novel.script.semantics.ScriptType;
import novel.script.semantics.ScriptType.ScriptTypeTools;
import novel.script.runtime.ScriptValue;
import novel.script.runtime.ScriptValue.ScriptValueTools;
import novel.script.syntax.ScriptSpan;

class ScriptBuiltins {
	public static final NAMES = [
		"std.max",
		"std.min",
		"std.abs",
		"std.clamp",
		"std.len",
		"std.concat",
		"std.substr",
		"std.toString",
		"std.repeat",
		"std.join",
		"std.listPush",
		"std.listSet"
	];

	public static function installInto(env:ScriptEnv):Void {
		for (name in NAMES) {
			env.define(name, TBuiltin(name), false, VBuiltin(name));
		}
	}

	public static function has(name:String):Bool {
		return Lambda.has(NAMES, name);
	}

	public static function typeCheckCall(name:String, argTypes:Array<ScriptType>, span:ScriptSpan):ScriptType {
		return switch name {
			case "std.max" | "std.min":
				expectNumericPair(name, argTypes, span);
			case "std.abs":
				expectCount(name, argTypes, 1, span);
				var argType = argTypes[0];

				if (!ScriptTypeTools.isNumeric(argType)) {
					throw new ScriptError(name + " expects an Int or Float.", span);
				}

				argType;
			case "std.clamp":
				expectCount(name, argTypes, 3, span);
				var valueType = argTypes[0];

				if (!ScriptTypeTools.isNumeric(valueType)) {
					throw new ScriptError(name + " expects numeric arguments.", span);
				}

				if (!ScriptTypeTools.equals(valueType, argTypes[1]) || !ScriptTypeTools.equals(valueType, argTypes[2])) {
					throw new ScriptError(name + " expects all arguments to have the same numeric type.", span);
				}

				valueType;
			case "std.len":
				expectCount(name, argTypes, 1, span);
				switch argTypes[0] {
					case TString | TList(_):
						TInt;
					default:
						throw new ScriptError(name + " expects a String or List.", span);
				}
			case "std.concat":
				expectCount(name, argTypes, 2, span);
				expectType(name, argTypes[0], TString, span);
				expectType(name, argTypes[1], TString, span);
				TString;
			case "std.substr":
				expectCount(name, argTypes, 3, span);
				expectType(name, argTypes[0], TString, span);
				expectType(name, argTypes[1], TInt, span);
				expectType(name, argTypes[2], TInt, span);
				TString;
			case "std.toString":
				expectCount(name, argTypes, 1, span);
				if (!ScriptTypeTools.isSerializable(argTypes[0])) {
					throw new ScriptError(name + " does not support " + ScriptTypeTools.format(argTypes[0]) + ".", span);
				}
				TString;
			case "std.repeat":
				expectCount(name, argTypes, 2, span);
				expectType(name, argTypes[0], TString, span);
				expectType(name, argTypes[1], TInt, span);
				TString;
			case "std.join":
				expectCount(name, argTypes, 2, span);
				switch argTypes[0] {
					case TList(itemType):
						expectType(name, itemType, TString, span);
					default:
						throw new ScriptError(name + " expects List<String> as its first argument.", span);
				}
				expectType(name, argTypes[1], TString, span);
				TString;
			case "std.listPush":
				expectCount(name, argTypes, 2, span);
				switch argTypes[0] {
					case TList(itemType):
						if (!ScriptTypeTools.isAssignable(itemType, argTypes[1])) {
							throw new ScriptError(
								name + " expects " + ScriptTypeTools.format(itemType)
									+ " as its second argument, but found " + ScriptTypeTools.format(argTypes[1]) + ".",
								span
							);
						}
						TList(itemType);
					default:
						throw new ScriptError(name + " expects a List as its first argument.", span);
				}
			case "std.listSet":
				expectCount(name, argTypes, 3, span);
				expectType(name, argTypes[1], TInt, span);
				switch argTypes[0] {
					case TList(itemType):
						if (!ScriptTypeTools.isAssignable(itemType, argTypes[2])) {
							throw new ScriptError(
								name + " expects " + ScriptTypeTools.format(itemType)
									+ " as its third argument, but found " + ScriptTypeTools.format(argTypes[2]) + ".",
								span
							);
						}
						TList(itemType);
					default:
						throw new ScriptError(name + " expects a List as its first argument.", span);
				}
			default:
				throw new ScriptError("Unknown builtin '" + name + "'.", span);
		};
	}

	public static function invoke(name:String, args:Array<ScriptValue>, span:ScriptSpan):ScriptValue {
		return switch name {
			case "std.max":
				expectRuntimeCount(name, args, 2, span);
				switch [args[0], args[1]] {
					case [VInt(left), VInt(right)]:
						VInt(left > right ? left : right);
					case [VFloat(left), VFloat(right)]:
						VFloat(left > right ? left : right);
					default:
						throw runtimeTypeError(name, args, span);
				}
			case "std.min":
				expectRuntimeCount(name, args, 2, span);
				switch [args[0], args[1]] {
					case [VInt(left), VInt(right)]:
						VInt(left < right ? left : right);
					case [VFloat(left), VFloat(right)]:
						VFloat(left < right ? left : right);
					default:
						throw runtimeTypeError(name, args, span);
				}
			case "std.abs":
				expectRuntimeCount(name, args, 1, span);
				switch args[0] {
					case VInt(value):
						VInt(value < 0 ? -value : value);
					case VFloat(value):
						VFloat(value < 0 ? -value : value);
					default:
						throw runtimeTypeError(name, args, span);
				}
			case "std.clamp":
				expectRuntimeCount(name, args, 3, span);
				switch [args[0], args[1], args[2]] {
					case [VInt(value), VInt(minValue), VInt(maxValue)]:
						VInt(value < minValue ? minValue : value > maxValue ? maxValue : value);
					case [VFloat(value), VFloat(minValue), VFloat(maxValue)]:
						VFloat(value < minValue ? minValue : value > maxValue ? maxValue : value);
					default:
						throw runtimeTypeError(name, args, span);
				}
			case "std.len":
				expectRuntimeCount(name, args, 1, span);
				switch args[0] {
					case VString(text):
						VInt(text.length);
					case VList(items):
						VInt(items.length);
					default:
						throw runtimeTypeError(name, args, span);
				}
			case "std.concat":
				expectRuntimeCount(name, args, 2, span);
				switch [args[0], args[1]] {
					case [VString(left), VString(right)]:
						VString(left + right);
					default:
						throw runtimeTypeError(name, args, span);
				}
			case "std.substr":
				expectRuntimeCount(name, args, 3, span);
				switch [args[0], args[1], args[2]] {
					case [VString(text), VInt(start), VInt(length)]:
						if (start < 0 || length < 0) {
							throw new ScriptError(name + " expects non-negative indices.", span);
						}

						VString(text.substr(start, length));
					default:
						throw runtimeTypeError(name, args, span);
				}
			case "std.toString":
				expectRuntimeCount(name, args, 1, span);
				VString(ScriptValueTools.format(args[0]));
			case "std.repeat":
				expectRuntimeCount(name, args, 2, span);
				switch [args[0], args[1]] {
					case [VString(text), VInt(count)]:
						if (count < 0) {
							throw new ScriptError(name + " expects a non-negative repeat count.", span);
						}

						var result = new StringBuf();

						for (_ in 0...count) {
							result.add(text);
						}

						VString(result.toString());
					default:
						throw runtimeTypeError(name, args, span);
				}
			case "std.join":
				expectRuntimeCount(name, args, 2, span);
				switch [args[0], args[1]] {
					case [VList(items), VString(separator)]:
						var parts:Array<String> = [];

						for (item in items) {
							switch item {
								case VString(text):
									parts.push(text);
								default:
									throw runtimeTypeError(name, args, span);
							}
						}

						VString(parts.join(separator));
					default:
						throw runtimeTypeError(name, args, span);
				}
			case "std.listPush":
				expectRuntimeCount(name, args, 2, span);
				switch args[0] {
					case VList(items):
						var next = items.copy();
						next.push(args[1]);
						VList(next);
					default:
						throw runtimeTypeError(name, args, span);
				}
			case "std.listSet":
				expectRuntimeCount(name, args, 3, span);
				switch [args[0], args[1]] {
					case [VList(items), VInt(index)]:
						if (index < 0 || index >= items.length) {
							throw new ScriptError(name + " index " + index + " is out of bounds.", span);
						}

						var next = items.copy();
						next[index] = args[2];
						VList(next);
					default:
						throw runtimeTypeError(name, args, span);
				}
			default:
				throw new ScriptError("Unknown builtin '" + name + "'.", span);
		};
	}

	static function expectNumericPair(name:String, argTypes:Array<ScriptType>, span:ScriptSpan):ScriptType {
		expectCount(name, argTypes, 2, span);
		var left = argTypes[0];
		var right = argTypes[1];

		if (!ScriptTypeTools.isNumeric(left) || !ScriptTypeTools.equals(left, right)) {
			throw new ScriptError(name + " expects two numeric arguments of the same type.", span);
		}

		return left;
	}

	static function expectCount(name:String, argTypes:Array<ScriptType>, expected:Int, span:ScriptSpan):Void {
		if (argTypes.length != expected) {
			throw new ScriptError(name + " expects " + expected + " arguments.", span);
		}
	}

	static function expectType(name:String, actual:ScriptType, expected:ScriptType, span:ScriptSpan):Void {
		if (!ScriptTypeTools.isAssignable(expected, actual)) {
			throw new ScriptError(
				name + " expects " + ScriptTypeTools.format(expected) + " but found " + ScriptTypeTools.format(actual) + ".",
				span
			);
		}
	}

	static function expectRuntimeCount(name:String, args:Array<ScriptValue>, expected:Int, span:ScriptSpan):Void {
		if (args.length != expected) {
			throw new ScriptError(name + " expects " + expected + " arguments.", span);
		}
	}

	static function runtimeTypeError(name:String, args:Array<ScriptValue>, span:ScriptSpan):ScriptError {
		var argTypes = [for (arg in args) ScriptTypeTools.format(ScriptValueTools.typeOf(arg))];
		return new ScriptError(name + " received invalid arguments: " + argTypes.join(", ") + ".", span);
	}
}
