package novel.script.semantics;

import novel.script.syntax.ScriptSpan;

class ScriptBindingInfo {
	public var name(default, null):String;
	public var type(default, null):ScriptType;
	public var mutable(default, null):Bool;
	public var span(default, null):ScriptSpan;

	public function new(name:String, type:ScriptType, mutable:Bool, span:ScriptSpan) {
		this.name = name;
		this.type = type;
		this.mutable = mutable;
		this.span = span;
	}
}
