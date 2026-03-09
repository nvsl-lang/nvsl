package novel.script.syntax;

import novel.script.ScriptError;
import novel.script.syntax.ScriptToken.ScriptTokenKind;

class ScriptLexer {
	var sourceName:String;
	var source:String;
	var length:Int;
	var index:Int;
	var line:Int;
	var column:Int;

	public function new(sourceName:String, source:String) {
		this.sourceName = sourceName;
		this.source = source;
		this.length = source.length;
		this.index = 0;
		this.line = 1;
		this.column = 1;
	}

	public static function tokenize(sourceName:String, source:String):Array<ScriptToken> {
		var lexer = new ScriptLexer(sourceName, source);
		var tokens:Array<ScriptToken> = [];

		while (true) {
			var token = lexer.nextToken();
			tokens.push(token);

			if (token.kind == TEndOfFile) {
				return tokens;
			}
		}

		return tokens;
	}

	function nextToken():ScriptToken {
		skipTrivia();

		var startIndex = index;
		var startLine = line;
		var startColumn = column;

		if (isAtEnd()) {
			return makeToken(TEndOfFile, "", startIndex, startLine, startColumn);
		}

		var ch = advance();

		return switch ch {
			case "(": makeToken(TLeftParen, ch, startIndex, startLine, startColumn);
			case ")": makeToken(TRightParen, ch, startIndex, startLine, startColumn);
			case "{": makeToken(TLeftBrace, ch, startIndex, startLine, startColumn);
			case "}": makeToken(TRightBrace, ch, startIndex, startLine, startColumn);
			case "[": makeToken(TLeftBracket, ch, startIndex, startLine, startColumn);
			case "]": makeToken(TRightBracket, ch, startIndex, startLine, startColumn);
			case ",": makeToken(TComma, ch, startIndex, startLine, startColumn);
			case ":": makeToken(TColon, ch, startIndex, startLine, startColumn);
			case ";": makeToken(TSemicolon, ch, startIndex, startLine, startColumn);
			case ".": makeToken(TDot, ch, startIndex, startLine, startColumn);
			case "+": makeToken(TPlus, ch, startIndex, startLine, startColumn);
			case "*": makeToken(TStar, ch, startIndex, startLine, startColumn);
			case "/": makeToken(TSlash, ch, startIndex, startLine, startColumn);
			case "%": makeToken(TPercent, ch, startIndex, startLine, startColumn);
			case "-":
				if (match(">")) {
					makeToken(TArrow, source.substring(startIndex, index), startIndex, startLine, startColumn);
				} else {
					makeToken(TMinus, ch, startIndex, startLine, startColumn);
				}
			case "=":
				if (match(">")) {
					makeToken(TFatArrow, source.substring(startIndex, index), startIndex, startLine, startColumn);
				} else if (match("=")) {
					makeToken(TEqualEqual, source.substring(startIndex, index), startIndex, startLine, startColumn);
				} else {
					makeToken(TEqual, ch, startIndex, startLine, startColumn);
				}
			case "!":
				if (match("=")) {
					makeToken(TBangEqual, source.substring(startIndex, index), startIndex, startLine, startColumn);
				} else {
					makeToken(TBang, ch, startIndex, startLine, startColumn);
				}
			case "<":
				if (match("=")) {
					makeToken(TLessEqual, source.substring(startIndex, index), startIndex, startLine, startColumn);
				} else {
					makeToken(TLess, ch, startIndex, startLine, startColumn);
				}
			case ">":
				if (match("=")) {
					makeToken(TGreaterEqual, source.substring(startIndex, index), startIndex, startLine, startColumn);
				} else {
					makeToken(TGreater, ch, startIndex, startLine, startColumn);
				}
			case "&":
				if (match("&")) {
					makeToken(TAndAnd, source.substring(startIndex, index), startIndex, startLine, startColumn);
				} else {
					throw error("Unexpected '&'. Use '&&' for logical and.", startIndex, startLine, startColumn);
				}
			case "|":
				if (match("|")) {
					makeToken(TOrOr, source.substring(startIndex, index), startIndex, startLine, startColumn);
				} else {
					throw error("Unexpected '|'. Use '||' for logical or.", startIndex, startLine, startColumn);
				}
			case "\"": readString(startIndex, startLine, startColumn);
			default:
				if (isDigit(ch)) {
					readNumber(startIndex, startLine, startColumn);
				} else if (isIdentifierStart(ch)) {
					readIdentifier(startIndex, startLine, startColumn);
				} else {
					throw error("Unexpected character '" + ch + "'.", startIndex, startLine, startColumn);
				}
		};
	}

	function skipTrivia():Void {
		while (!isAtEnd()) {
			var ch = peek();

			switch ch {
				case " " | "\t" | "\r" | "\n":
					advance();
				case "/":
					if (peek(1) == "/") {
						advance();
						advance();

						while (!isAtEnd() && peek() != "\n") {
							advance();
						}
					} else if (peek(1) == "*") {
						advance();
						advance();

						while (!(peek() == "*" && peek(1) == "/")) {
							if (isAtEnd()) {
								throw error("Unterminated block comment.", index, line, column);
							}

							advance();
						}

						advance();
						advance();
					} else {
						return;
					}
				default:
					return;
			}
		}
	}

	function readIdentifier(startIndex:Int, startLine:Int, startColumn:Int):ScriptToken {
		while (isIdentifierPart(peek())) {
			advance();
		}

		var text = source.substring(startIndex, index);
		var kind = switch text {
			case "module": TModule;
			case "import": TImport;
			case "as": TAs;
			case "struct": TStruct;
			case "enum": TEnum;
			case "fn": TFn;
			case "let": TLet;
			case "set": TSet;
			case "if": TIf;
			case "else": TElse;
			case "true": TTrue;
			case "false": TFalse;
			default: TIdentifier;
		};

		return makeToken(kind, text, startIndex, startLine, startColumn);
	}

	function readNumber(startIndex:Int, startLine:Int, startColumn:Int):ScriptToken {
		while (isDigit(peek())) {
			advance();
		}

		var kind = TIntLiteral;

		if (peek() == "." && isDigit(peek(1))) {
			kind = TFloatLiteral;
			advance();

			while (isDigit(peek())) {
				advance();
			}
		}

		return makeToken(kind, source.substring(startIndex, index), startIndex, startLine, startColumn);
	}

	function readString(startIndex:Int, startLine:Int, startColumn:Int):ScriptToken {
		var value = new StringBuf();

		while (!isAtEnd()) {
			var ch = advance();

			if (ch == "\"") {
				return makeToken(TStringLiteral, value.toString(), startIndex, startLine, startColumn);
			}

			if (ch == "\\") {
				if (isAtEnd()) {
					throw error("Unterminated string literal.", startIndex, startLine, startColumn);
				}

				var escaped = advance();

				switch escaped {
					case "\"": value.add("\"");
					case "\\": value.add("\\");
					case "n": value.add("\n");
					case "r": value.add("\r");
					case "t": value.add("\t");
					default:
						throw error("Unsupported escape sequence '\\" + escaped + "'.", startIndex, startLine, startColumn);
				}
			} else {
				value.add(ch);
			}
		}

		throw error("Unterminated string literal.", startIndex, startLine, startColumn);
	}

	function makeToken(kind:ScriptTokenKind, text:String, startIndex:Int, startLine:Int, startColumn:Int):ScriptToken {
		return new ScriptToken(
			kind,
			text,
			new ScriptSpan(sourceName, startIndex, index, startLine, startColumn, line, column)
		);
	}

	function error(message:String, startIndex:Int, startLine:Int, startColumn:Int):ScriptError {
		return new ScriptError(
			message,
			new ScriptSpan(sourceName, startIndex, index, startLine, startColumn, line, column)
		);
	}

	inline function isAtEnd():Bool {
		return index >= length;
	}

	inline function peek(offset:Int = 0):String {
		var target = index + offset;
		return target >= length ? "" : source.charAt(target);
	}

	function match(expected:String):Bool {
		if (peek() != expected) {
			return false;
		}

		advance();
		return true;
	}

	function advance():String {
		var ch = source.charAt(index++);

		if (ch == "\n") {
			line++;
			column = 1;
		} else {
			column++;
		}

		return ch;
	}

	static inline function isDigit(ch:String):Bool {
		return ch >= "0" && ch <= "9";
	}

	static inline function isIdentifierStart(ch:String):Bool {
		return (ch >= "a" && ch <= "z") || (ch >= "A" && ch <= "Z") || ch == "_";
	}

	static inline function isIdentifierPart(ch:String):Bool {
		return isIdentifierStart(ch) || isDigit(ch);
	}
}
