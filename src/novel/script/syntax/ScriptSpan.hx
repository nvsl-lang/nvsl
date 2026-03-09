package novel.script.syntax;

class ScriptSpan {
	public var sourceName(default, null):String;
	public var startIndex(default, null):Int;
	public var endIndex(default, null):Int;
	public var startLine(default, null):Int;
	public var startColumn(default, null):Int;
	public var endLine(default, null):Int;
	public var endColumn(default, null):Int;

	public function new(
		sourceName:String,
		startIndex:Int,
		endIndex:Int,
		startLine:Int,
		startColumn:Int,
		endLine:Int,
		endColumn:Int
	) {
		this.sourceName = sourceName;
		this.startIndex = startIndex;
		this.endIndex = endIndex;
		this.startLine = startLine;
		this.startColumn = startColumn;
		this.endLine = endLine;
		this.endColumn = endColumn;
	}

	public static function merge(start:ScriptSpan, finish:ScriptSpan):ScriptSpan {
		return new ScriptSpan(
			start.sourceName,
			start.startIndex,
			finish.endIndex,
			start.startLine,
			start.startColumn,
			finish.endLine,
			finish.endColumn
		);
	}

	public function toString():String {
		return sourceName + ":" + startLine + ":" + startColumn;
	}
}
