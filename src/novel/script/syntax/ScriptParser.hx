package novel.script.syntax;

import novel.script.ScriptError;
import novel.script.syntax.ScriptAst.ScriptAssign;
import novel.script.syntax.ScriptAst.ScriptBinaryOp;
import novel.script.syntax.ScriptAst.ScriptDecl;
import novel.script.syntax.ScriptAst.ScriptEnumCaseDecl;
import novel.script.syntax.ScriptAst.ScriptEnumDecl;
import novel.script.syntax.ScriptAst.ScriptExpr;
import novel.script.syntax.ScriptAst.ScriptExprDef;
import novel.script.syntax.ScriptAst.ScriptFieldDecl;
import novel.script.syntax.ScriptAst.ScriptFunctionDecl;
import novel.script.syntax.ScriptAst.ScriptImportDecl;
import novel.script.syntax.ScriptAst.ScriptParam;
import novel.script.syntax.ScriptAst.ScriptPath;
import novel.script.syntax.ScriptAst.ScriptProgram;
import novel.script.syntax.ScriptAst.ScriptRecordFieldInit;
import novel.script.syntax.ScriptAst.ScriptStmt;
import novel.script.syntax.ScriptAst.ScriptStructDecl;
import novel.script.syntax.ScriptAst.ScriptTypeRef;
import novel.script.syntax.ScriptAst.ScriptUnaryOp;
import novel.script.syntax.ScriptAst.ScriptValueDecl;
import novel.script.syntax.ScriptToken.ScriptTokenKind;
import novel.script.syntax.ScriptToken.ScriptTokenKindTools;

class ScriptParser {
	var tokens:Array<ScriptToken>;
	var index:Int;
	var sourceText:String;
	var nextNodeId:Int;

	public function new(tokens:Array<ScriptToken>, sourceText:String) {
		this.tokens = tokens;
		this.index = 0;
		this.sourceText = sourceText;
		this.nextNodeId = 1;
	}

	public static function parseSource(sourceName:String, source:String):ScriptProgram {
		return new ScriptParser(ScriptLexer.tokenize(sourceName, source), source).parseProgram();
	}

	public function parseProgram():ScriptProgram {
		var start = current().span;
		var moduleName:Null<ScriptPath> = null;
		var imports:Array<ScriptImportDecl> = [];
		var declarations:Array<ScriptDecl> = [];

		if (match(TModule)) {
			moduleName = parsePath();
			expect(TSemicolon, "Expected ';' after module declaration.");
		}

		while (match(TImport)) {
			imports.push(parseImportDecl(previous()));
		}

		while (!check(TEndOfFile)) {
			declarations.push(parseDeclaration());
		}

		return new ScriptProgram(moduleName, imports, declarations, ScriptSpan.merge(start, current().span), sourceText);
	}

	function parseImportDecl(startToken:ScriptToken):ScriptImportDecl {
		var path = parsePath();
		var alias:Null<String> = null;

		if (match(TAs)) {
			alias = expect(TIdentifier, "Expected import alias after 'as'.").text;
		}

		expect(TSemicolon, "Expected ';' after import.");
		return new ScriptImportDecl(path, alias, ScriptSpan.merge(startToken.span, previous().span));
	}

	function parseDeclaration():ScriptDecl {
		return switch current().kind {
			case TStruct:
				advance();
				DStruct(parseStructDecl(previous()));
			case TEnum:
				advance();
				DEnum(parseEnumDecl(previous()));
			case TFn:
				advance();
				DFunction(parseFunctionDecl(previous()));
			case TLet:
				advance();
				DValue(parseValueDecl(previous(), true));
			default:
				throw errorHere("Expected a top-level declaration.");
		};
	}

	function parseStructDecl(startToken:ScriptToken):ScriptStructDecl {
		var nameToken = expect(TIdentifier, "Expected struct name.");
		expect(TLeftBrace, "Expected '{' after struct name.");
		var fields:Array<ScriptFieldDecl> = [];

		while (!check(TRightBrace)) {
			if (check(TEndOfFile)) {
				throw errorHere("Unterminated struct declaration.");
			}

			var fieldName = expect(TIdentifier, "Expected struct field name.");
			expect(TColon, "Expected ':' after field name.");
			var fieldType = parseTypeRef();
			expect(TSemicolon, "Expected ';' after struct field.");
			fields.push(new ScriptFieldDecl(fieldName.text, fieldType, ScriptSpan.merge(fieldName.span, fieldType.span)));
		}

		var close = expect(TRightBrace, "Expected '}' after struct declaration.");
		return new ScriptStructDecl(nameToken.text, fields, ScriptSpan.merge(startToken.span, close.span));
	}

	function parseEnumDecl(startToken:ScriptToken):ScriptEnumDecl {
		var nameToken = expect(TIdentifier, "Expected enum name.");
		expect(TLeftBrace, "Expected '{' after enum name.");
		var cases:Array<ScriptEnumCaseDecl> = [];

		while (!check(TRightBrace)) {
			if (check(TEndOfFile)) {
				throw errorHere("Unterminated enum declaration.");
			}

			var caseToken = expect(TIdentifier, "Expected enum case name.");
			expect(TSemicolon, "Expected ';' after enum case.");
			cases.push(new ScriptEnumCaseDecl(caseToken.text, caseToken.span));
		}

		var close = expect(TRightBrace, "Expected '}' after enum declaration.");
		return new ScriptEnumDecl(nameToken.text, cases, ScriptSpan.merge(startToken.span, close.span));
	}

	function parseFunctionDecl(startToken:ScriptToken):ScriptFunctionDecl {
		var nameToken = expect(TIdentifier, "Expected function name after 'fn'.");
		expect(TLeftParen, "Expected '(' after function name.");

		var params:Array<ScriptParam> = [];

		if (!check(TRightParen)) {
			do {
				params.push(parseParam());
			} while (match(TComma));
		}

		expect(TRightParen, "Expected ')' after function parameters.");

		var returnType:Null<ScriptTypeRef> = null;

		if (match(TArrow)) {
			returnType = parseTypeRef();
		}

		var body = if (match(TEqual)) {
			var expr = parseExpression();
			expect(TSemicolon, "Expected ';' after function body.");
			expr;
		} else if (check(TLeftBrace)) {
			parseBlockExpr();
		} else {
			throw errorHere("Expected '=' or a block after function signature.");
		};

		return new ScriptFunctionDecl(
			allocId(),
			nameToken.text,
			params,
			returnType,
			body,
			ScriptSpan.merge(startToken.span, body.span)
		);
	}

	function parseParam():ScriptParam {
		var nameToken = expect(TIdentifier, "Expected parameter name.");
		expect(TColon, "Expected ':' after parameter name.");
		var type = parseTypeRef();
		return new ScriptParam(nameToken.text, type, ScriptSpan.merge(nameToken.span, type.span));
	}

	function parseTypeRef():ScriptTypeRef {
		var pathRef = parsePathRef("Expected type name.");
		var args:Array<ScriptTypeRef> = [];
		var span = pathRef.span;

		if (match(TLess)) {
			do {
				args.push(parseTypeRef());
			} while (match(TComma));

			var close = expect(TGreater, "Expected '>' after type arguments.");
			span = ScriptSpan.merge(pathRef.span, close.span);
		}

		return new ScriptTypeRef(pathRef.path, args, span);
	}

	function parseValueDecl(startToken:ScriptToken, requireSemicolon:Bool):ScriptValueDecl {
		var nameToken = expect(TIdentifier, "Expected binding name after 'let'.");
		var type:Null<ScriptTypeRef> = null;

		if (match(TColon)) {
			type = parseTypeRef();
		}

		expect(TEqual, "Expected '=' after binding name.");
		var value = parseExpression();

		if (requireSemicolon) {
			expect(TSemicolon, "Expected ';' after binding.");
		}

		return new ScriptValueDecl(allocId(), nameToken.text, type, value, ScriptSpan.merge(startToken.span, value.span));
	}

	function parseAssignment(startToken:ScriptToken):ScriptAssign {
		var target = parsePathRef("Expected assignment target after 'set'.");
		expect(TEqual, "Expected '=' after assignment target.");
		var value = parseExpression();
		expect(TSemicolon, "Expected ';' after assignment.");
		return new ScriptAssign(allocId(), target.path, value, ScriptSpan.merge(startToken.span, value.span));
	}

	function parseExpression():ScriptExpr {
		return parseLogicalOr();
	}

	function parseLogicalOr():ScriptExpr {
		var expr = parseLogicalAnd();

		while (match(TOrOr)) {
			var right = parseLogicalAnd();
			expr = makeExpr(EBinary(ScriptBinaryOp.Or, expr, right), ScriptSpan.merge(expr.span, right.span));
		}

		return expr;
	}

	function parseLogicalAnd():ScriptExpr {
		var expr = parseEquality();

		while (match(TAndAnd)) {
			var right = parseEquality();
			expr = makeExpr(EBinary(ScriptBinaryOp.And, expr, right), ScriptSpan.merge(expr.span, right.span));
		}

		return expr;
	}

	function parseEquality():ScriptExpr {
		var expr = parseComparison();

		while (true) {
			var op = if (match(TEqualEqual)) {
				ScriptBinaryOp.Equal;
			} else if (match(TBangEqual)) {
				ScriptBinaryOp.NotEqual;
			} else {
				null;
			};

			if (op == null) {
				return expr;
			}

			var right = parseComparison();
			expr = makeExpr(EBinary(op, expr, right), ScriptSpan.merge(expr.span, right.span));
		}

		return expr;
	}

	function parseComparison():ScriptExpr {
		var expr = parseAdditive();

		while (true) {
			var op = if (match(TLess)) {
				ScriptBinaryOp.Less;
			} else if (match(TLessEqual)) {
				ScriptBinaryOp.LessEqual;
			} else if (match(TGreater)) {
				ScriptBinaryOp.Greater;
			} else if (match(TGreaterEqual)) {
				ScriptBinaryOp.GreaterEqual;
			} else {
				null;
			};

			if (op == null) {
				return expr;
			}

			var right = parseAdditive();
			expr = makeExpr(EBinary(op, expr, right), ScriptSpan.merge(expr.span, right.span));
		}

		return expr;
	}

	function parseAdditive():ScriptExpr {
		var expr = parseMultiplicative();

		while (true) {
			var op = if (match(TPlus)) {
				ScriptBinaryOp.Add;
			} else if (match(TMinus)) {
				ScriptBinaryOp.Subtract;
			} else {
				null;
			};

			if (op == null) {
				return expr;
			}

			var right = parseMultiplicative();
			expr = makeExpr(EBinary(op, expr, right), ScriptSpan.merge(expr.span, right.span));
		}

		return expr;
	}

	function parseMultiplicative():ScriptExpr {
		var expr = parseUnary();

		while (true) {
			var op = if (match(TStar)) {
				ScriptBinaryOp.Multiply;
			} else if (match(TSlash)) {
				ScriptBinaryOp.Divide;
			} else if (match(TPercent)) {
				ScriptBinaryOp.Modulo;
			} else {
				null;
			};

			if (op == null) {
				return expr;
			}

			var right = parseUnary();
			expr = makeExpr(EBinary(op, expr, right), ScriptSpan.merge(expr.span, right.span));
		}

		return expr;
	}

	function parseUnary():ScriptExpr {
		if (match(TBang)) {
			var token = previous();
			var right = parseUnary();
			return makeExpr(EUnary(ScriptUnaryOp.Not, right), ScriptSpan.merge(token.span, right.span));
		}

		if (match(TMinus)) {
			var token = previous();
			var right = parseUnary();
			return makeExpr(EUnary(ScriptUnaryOp.Negate, right), ScriptSpan.merge(token.span, right.span));
		}

		return parsePostfix();
	}

	function parsePostfix():ScriptExpr {
		var expr = parsePrimary();

		while (true) {
			if (match(TLeftParen)) {
				var args:Array<ScriptExpr> = [];

				if (!check(TRightParen)) {
					do {
						args.push(parseExpression());
					} while (match(TComma));
				}

				var close = expect(TRightParen, "Expected ')' after call arguments.");
				expr = makeExpr(ECall(expr, args), ScriptSpan.merge(expr.span, close.span));
				continue;
			}

			if (match(TDot)) {
				var fieldName = expect(TIdentifier, "Expected field name after '.'.");
				expr = makeExpr(EField(expr, fieldName.text), ScriptSpan.merge(expr.span, fieldName.span));
				continue;
			}

			if (match(TLeftBracket)) {
				var indexExpr = parseExpression();
				var close = expect(TRightBracket, "Expected ']' after index expression.");
				expr = makeExpr(EIndex(expr, indexExpr), ScriptSpan.merge(expr.span, close.span));
				continue;
			}

			break;
		}

		return expr;
	}

	function parsePrimary():ScriptExpr {
		if (match(TIntLiteral)) {
			var token = previous();
			return makeExpr(EInt(Std.parseInt(token.text)), token.span);
		}

		if (match(TFloatLiteral)) {
			var token = previous();
			return makeExpr(EFloat(Std.parseFloat(token.text)), token.span);
		}

		if (match(TStringLiteral)) {
			var token = previous();
			return makeExpr(EString(token.text), token.span);
		}

		if (match(TTrue)) {
			return makeExpr(EBool(true), previous().span);
		}

		if (match(TFalse)) {
			return makeExpr(EBool(false), previous().span);
		}

		if (match(TFn)) {
			return parseLambdaExpr(previous());
		}

		if (match(TIf)) {
			return parseIfExpr(previous());
		}

		if (check(TLeftBrace)) {
			return parseBlockExpr();
		}

		if (match(TLeftBracket)) {
			return parseListLiteral(previous());
		}

		if (match(TLeftParen)) {
			var expr = parseExpression();
			expect(TRightParen, "Expected ')' after grouped expression.");
			return expr;
		}

		if (check(TIdentifier)) {
			var pathRef = parsePathRef("Expected identifier.");

			if (check(TLeftBrace) && isRecordLiteralStart()) {
				return parseRecordLiteral(pathRef.path, pathRef.span);
			}

			return makeExpr(EPath(pathRef.path), pathRef.span);
		}

		throw errorHere("Expected an expression.");
	}

	function parseListLiteral(startToken:ScriptToken):ScriptExpr {
		var elements:Array<ScriptExpr> = [];

		if (!check(TRightBracket)) {
			do {
				elements.push(parseExpression());
			} while (match(TComma));
		}

		var close = expect(TRightBracket, "Expected ']' after list literal.");
		return makeExpr(EList(elements), ScriptSpan.merge(startToken.span, close.span));
	}

	function parseRecordLiteral(typePath:ScriptPath, typeSpan:ScriptSpan):ScriptExpr {
		expect(TLeftBrace, "Expected '{' to start record literal.");
		var fields:Array<ScriptRecordFieldInit> = [];

		if (!check(TRightBrace)) {
			do {
				var fieldName = expect(TIdentifier, "Expected record field name.");
				expect(TColon, "Expected ':' after record field name.");
				var value = parseExpression();
				fields.push(new ScriptRecordFieldInit(fieldName.text, value, ScriptSpan.merge(fieldName.span, value.span)));
			} while (match(TComma));
		}

		var close = expect(TRightBrace, "Expected '}' after record literal.");
		return makeExpr(ERecord(typePath, fields), ScriptSpan.merge(typeSpan, close.span));
	}

	function isRecordLiteralStart():Bool {
		if (!check(TLeftBrace)) {
			return false;
		}

		var next = peekToken(1);

		if (next.kind == TRightBrace) {
			return true;
		}

		return next.kind == TIdentifier && peekToken(2).kind == TColon;
	}

	function parseLambdaExpr(startToken:ScriptToken):ScriptExpr {
		expect(TLeftParen, "Expected '(' after lambda 'fn'.");
		var params:Array<ScriptParam> = [];

		if (!check(TRightParen)) {
			do {
				params.push(parseParam());
			} while (match(TComma));
		}

		expect(TRightParen, "Expected ')' after lambda parameters.");
		var returnType:Null<ScriptTypeRef> = null;

		if (match(TArrow)) {
			returnType = parseTypeRef();
		}

		expect(TFatArrow, "Expected '=>' after lambda signature.");
		var body = parseExpression();
		return makeExpr(ELambda(params, returnType, body), ScriptSpan.merge(startToken.span, body.span));
	}

	function parseIfExpr(startToken:ScriptToken):ScriptExpr {
		var condition = parseExpression();
		var thenBranch = parseIfBranch("Expected '{' after if condition.");
		expect(TElse, "Expected 'else' after if branch.");
		var elseBranch = if (match(TIf)) parseIfExpr(previous()) else parseIfBranch("Expected '{' after else.");
		return makeExpr(EIf(condition, thenBranch, elseBranch), ScriptSpan.merge(startToken.span, elseBranch.span));
	}

	function parseIfBranch(message:String):ScriptExpr {
		if (!check(TLeftBrace)) {
			throw errorHere(message);
		}

		return parseBlockExpr();
	}

	function parseBlockExpr():ScriptExpr {
		var start = expect(TLeftBrace, "Expected '{' to start block.");
		var statements:Array<ScriptStmt> = [];
		var tail:Null<ScriptExpr> = null;

		while (!check(TRightBrace)) {
			if (check(TEndOfFile)) {
				throw errorHere("Unterminated block expression.");
			}

			if (match(TLet)) {
				statements.push(SLet(parseValueDecl(previous(), true)));
				continue;
			}

			if (match(TSet)) {
				statements.push(SSet(parseAssignment(previous())));
				continue;
			}

			var expr = parseExpression();

			if (match(TSemicolon)) {
				statements.push(SExpr(expr));
			} else {
				tail = expr;
				break;
			}
		}

		var close = expect(TRightBrace, "Expected '}' after block.");
		return makeExpr(EBlock(statements, tail), ScriptSpan.merge(start.span, close.span));
	}

	function parsePath():ScriptPath {
		return parsePathRef("Expected identifier path.").path;
	}

	function parsePathRef(errorMessage:String):{ path:ScriptPath, span:ScriptSpan } {
		var first = expect(TIdentifier, errorMessage);
		var path:ScriptPath = [first.text];
		var span = first.span;

		while (match(TDot)) {
			var nextToken = expect(TIdentifier, "Expected identifier after '.'.");
			path.push(nextToken.text);
			span = ScriptSpan.merge(span, nextToken.span);
		}

		return { path: path, span: span };
	}

	inline function current():ScriptToken {
		return tokens[index];
	}

	inline function peekToken(offset:Int):ScriptToken {
		var target = index + offset;
		return target >= tokens.length ? tokens[tokens.length - 1] : tokens[target];
	}

	inline function previous():ScriptToken {
		return tokens[index - 1];
	}

	function advance():ScriptToken {
		if (!check(TEndOfFile)) {
			index++;
		}

		return previous();
	}

	function expect(kind:ScriptTokenKind, message:String):ScriptToken {
		if (check(kind)) {
			return advance();
		}

		throw errorHere(message + " Found " + ScriptTokenKindTools.label(current().kind) + ".");
	}

	inline function check(kind:ScriptTokenKind):Bool {
		return current().kind == kind;
	}

	function match(kind:ScriptTokenKind):Bool {
		if (!check(kind)) {
			return false;
		}

		advance();
		return true;
	}

	function errorHere(message:String):ScriptError {
		return new ScriptError(message, current().span);
	}

	inline function allocId():Int {
		return nextNodeId++;
	}

	inline function makeExpr(def:ScriptExprDef, span:ScriptSpan):ScriptExpr {
		return new ScriptExpr(allocId(), def, span);
	}
}
