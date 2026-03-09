package novel.script.runtime;

import haxe.ds.StringMap;
import novel.script.ScriptError;
import novel.script.semantics.ScriptType;
import novel.script.semantics.ScriptType.ScriptTypeTools;
import novel.script.runtime.ScriptValue;
import novel.script.runtime.ScriptValue.ScriptValueTools;
import novel.script.syntax.ScriptSpan;

class ScriptCell {
	public var name(default, null):String;
	public var type(default, null):ScriptType;
	public var mutable(default, null):Bool;
	public var initialized(default, null):Bool;
	public var value(default, null):ScriptValue;

	public function new(name:String, type:ScriptType, mutable:Bool, value:ScriptValue, initialized:Bool) {
		this.name = name;
		this.type = type;
		this.mutable = mutable;
		this.initialized = initialized;
		this.value = value;
	}

	public function setValue(value:ScriptValue):Void {
		this.value = value;
		this.initialized = true;
	}

	public function restoreValue(value:ScriptValue, initialized:Bool):Void {
		this.value = value;
		this.initialized = initialized;
	}
}

class ScriptEnv {
	var parent:Null<ScriptEnv>;
	var bindings:StringMap<ScriptCell>;

	public function new(?parent:ScriptEnv) {
		this.parent = parent;
		this.bindings = new StringMap();
	}

	public function define(name:String, type:ScriptType, mutable:Bool, value:ScriptValue, initialized:Bool = true):ScriptCell {
		if (bindings.exists(name)) {
			throw new ScriptError("Duplicate binding '" + name + "'.");
		}

		var cell = new ScriptCell(name, type, mutable, value, initialized);
		bindings.set(name, cell);
		return cell;
	}

	public function resolve(name:String):Null<ScriptCell> {
		var current:Null<ScriptEnv> = this;

		while (current != null) {
			var cell = current.bindings.get(name);

			if (cell != null) {
				return cell;
			}

			current = current.parent;
		}

		return null;
	}

	public function resolveLocal(name:String):Null<ScriptCell> {
		return bindings.get(name);
	}

	public function parentEnv():Null<ScriptEnv> {
		return parent;
	}

	public function localCells():Array<ScriptCell> {
		var cells:Array<ScriptCell> = [];

		for (_ => cell in bindings) {
			cells.push(cell);
		}

		cells.sort(function(left, right) {
			return left.name < right.name ? -1 : left.name > right.name ? 1 : 0;
		});
		return cells;
	}

	public function get(name:String, ?span:ScriptSpan):ScriptValue {
		var cell = resolve(name);

		if (cell == null) {
			throw new ScriptError("Unknown binding '" + name + "'.", span);
		}

		if (!cell.initialized) {
			throw new ScriptError("Binding '" + name + "' was read before initialization.", span);
		}

		return cell.value;
	}

	public function assign(name:String, value:ScriptValue, ?span:ScriptSpan):Void {
		var cell = resolve(name);

		if (cell == null) {
			throw new ScriptError("Unknown binding '" + name + "'.", span);
		}

		if (!cell.mutable) {
			throw new ScriptError("Binding '" + name + "' is immutable.", span);
		}

		var actualType = ScriptValueTools.typeOf(value);

		if (!ScriptTypeTools.isAssignable(cell.type, actualType)) {
			throw new ScriptError(
				"Cannot assign " + ScriptTypeTools.format(actualType) + " to " + ScriptTypeTools.format(cell.type) + ".",
				span
			);
		}

		cell.setValue(value);
	}
}
