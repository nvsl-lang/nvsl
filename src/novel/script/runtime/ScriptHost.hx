package novel.script.runtime;

import haxe.ds.StringMap;
import novel.script.ScriptError;
import novel.script.semantics.ScriptType;
import novel.script.semantics.ScriptType.ScriptTypeTools;
import novel.script.runtime.ScriptValue;
import novel.script.syntax.ScriptSpan;

typedef HostTypeChecker = (Array<ScriptType>, ScriptSpan) -> ScriptType;
typedef HostImplementation = (Array<ScriptValue>, ScriptSpan) -> ScriptValue;

class HostFunction {
	public var name(default, null):String;
	public var check(default, null):HostTypeChecker;
	public var call(default, null):HostImplementation;

	public function new(name:String, check:HostTypeChecker, call:HostImplementation) {
		this.name = name;
		this.check = check;
		this.call = call;
	}
}

/**
	The ScriptHost is the registry for all built-in and host-provided functions.
	It allows engine developers to register custom APIs (like `vn.*` or `ui.*`)
	without modifying the NVSL core source code.
**/
class ScriptHost {
	static var registry = new StringMap<HostFunction>();
	static var initialized = false;

	/**
		Registers a new host function with a custom type checker and implementation.
	**/
	public static function register(name:String, check:HostTypeChecker, call:HostImplementation):Void {
		if (registry.exists(name)) {
			throw new ScriptError("Host function '" + name + "' is already registered.");
		}

		registry.set(name, new HostFunction(name, check, call));
	}

	/**
		Registers a host function with a fixed signature.
	**/
	public static function registerSimple(name:String, params:Array<ScriptType>, returnType:ScriptType, call:HostImplementation):Void {
		register(name, function(argTypes, span) {
			if (argTypes.length != params.length) {
				throw new ScriptError(name + " expects " + params.length + " arguments, but found " + argTypes.length + ".", span);
			}

			for (i in 0...params.length) {
				if (!ScriptTypeTools.isAssignable(params[i], argTypes[i])) {
					throw new ScriptError(
						name + " argument " + (i + 1) + " expects " + ScriptTypeTools.format(params[i])
							+ " but found " + ScriptTypeTools.format(argTypes[i]) + ".",
						span
					);
				}
			}

			return returnType;
		}, call);
	}

	public static function has(name:String):Bool {
		ensureInitialized();
		return registry.exists(name);
	}

	public static function typeCheckCall(name:String, argTypes:Array<ScriptType>, span:ScriptSpan):ScriptType {
		ensureInitialized();
		var func = registry.get(name);

		if (func == null) {
			throw new ScriptError("Unknown host function '" + name + "'.", span);
		}

		return func.check(argTypes, span);
	}

	public static function invoke(name:String, args:Array<ScriptValue>, span:ScriptSpan):ScriptValue {
		ensureInitialized();
		var func = registry.get(name);

		if (func == null) {
			throw new ScriptError("Unknown host function '" + name + "'.", span);
		}

		return func.call(args, span);
	}

	static function ensureInitialized():Void {
		if (initialized) {
			return;
		}

		initialized = true;
		ScriptBuiltins.installIntoHost();
	}
}
