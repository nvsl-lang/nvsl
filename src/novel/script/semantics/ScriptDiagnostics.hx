package novel.script.semantics;

import novel.script.ScriptError;
import novel.script.project.ScriptProject.ScriptSourceMap;

class ScriptDiagnostics {
	public static function format(error:ScriptError, ?sourceMap:ScriptSourceMap):String {
		if (error.span == null || sourceMap == null) {
			return error.message;
		}

		var source = sourceMap.get(error.span.sourceName);

		if (source == null) {
			return error.message;
		}

		var lines = source.split("\n");
		var startLine = clamp(error.span.startLine, 1, lines.length == 0 ? 1 : lines.length);
		var endLine = clamp(error.span.endLine, startLine, lines.length == 0 ? startLine : lines.length);
		var gutterWidth = Std.string(endLine).length;
		var output:Array<String> = [
			"error: " + error.message,
			" --> " + error.span.sourceName + ":" + error.span.startLine + ":" + error.span.startColumn,
		];

		for (lineNumber in startLine...endLine + 1) {
			var lineText = safeLine(lines, lineNumber);
			output.push(padLeft(Std.string(lineNumber), gutterWidth) + " | " + lineText);

			var highlightStart = lineNumber == startLine ? max(1, error.span.startColumn) : 1;
			var highlightEndExclusive = lineNumber == endLine
				? max(highlightStart + 1, error.span.endColumn)
				: lineText.length + 1;
			var underlineWidth = max(1, highlightEndExclusive - highlightStart);
			output.push(repeat(" ", gutterWidth) + " | " + repeat(" ", highlightStart - 1) + repeat("^", underlineWidth));
		}

		return output.join("\n");
	}

	static function safeLine(lines:Array<String>, lineNumber:Int):String {
		var index = lineNumber - 1;
		return index >= 0 && index < lines.length ? lines[index] : "";
	}

	static function clamp(value:Int, minValue:Int, maxValue:Int):Int {
		return value < minValue ? minValue : value > maxValue ? maxValue : value;
	}

	static function max(left:Int, right:Int):Int {
		return left > right ? left : right;
	}

	static function padLeft(value:String, width:Int):String {
		return value.length >= width ? value : repeat(" ", width - value.length) + value;
	}

	static function repeat(text:String, count:Int):String {
		var result = new StringBuf();

		for (_ in 0...count) {
			result.add(text);
		}

		return result.toString();
	}
}
