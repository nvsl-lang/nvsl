package novel.script;

import novel.script.syntax.ScriptSpan;

class ScriptError extends haxe.Exception {
	public var span(default, null):Null<ScriptSpan>;

	public function new(message:String, ?span:ScriptSpan) {
		super(span == null ? message : message + " at " + span.toString());
		this.span = span;
	}
}
