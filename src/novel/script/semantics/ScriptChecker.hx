package novel.script.semantics;

import haxe.ds.StringMap;
import haxe.ds.IntMap;
import novel.script.ScriptError;
import novel.script.syntax.ScriptAst.ScriptAssign;
import novel.script.syntax.ScriptAst.ScriptBinaryOp;
import novel.script.syntax.ScriptAst.ScriptDecl;
import novel.script.syntax.ScriptAst.ScriptEnumDecl;
import novel.script.syntax.ScriptAst.ScriptExpr;
import novel.script.syntax.ScriptAst.ScriptExprDef;
import novel.script.syntax.ScriptAst.ScriptFieldDecl;
import novel.script.syntax.ScriptAst.ScriptFunctionDecl;
import novel.script.syntax.ScriptAst.ScriptPath;
import novel.script.syntax.ScriptAst.ScriptProgram;
import novel.script.syntax.ScriptAst.ScriptRecordFieldInit;
import novel.script.syntax.ScriptAst.ScriptStmt;
import novel.script.syntax.ScriptAst.ScriptStructDecl;
import novel.script.syntax.ScriptAst.ScriptTypeRef;
import novel.script.syntax.ScriptAst.ScriptUnaryOp;
import novel.script.syntax.ScriptAst.ScriptValueDecl;
import novel.script.syntax.ScriptSpan;
import novel.script.project.ScriptProject.ScriptEnumInfo;
import novel.script.project.ScriptProject.ScriptModuleInfo;
import novel.script.project.ScriptProject.ScriptModuleIndexer;
import novel.script.project.ScriptProject.ScriptProject;
import novel.script.project.ScriptProject.ScriptProjectInfo;
import novel.script.project.ScriptProject.ScriptSourceMap;
import novel.script.project.ScriptProject.ScriptStructInfo;
import novel.script.runtime.ScriptBuiltins;
import novel.script.semantics.ScriptType;
import novel.script.semantics.ScriptType.ScriptTypeTools;

class ScriptProgramInfo {
	public var project(default, null):ScriptProjectInfo;
	public var module(default, null):ScriptModuleInfo;

	public function new(project:ScriptProjectInfo, module:ScriptModuleInfo) {
		this.project = project;
		this.module = module;
	}
}

class ScriptTypeScope {
	var parent:Null<ScriptTypeScope>;
	var bindings:StringMap<ScriptBindingInfo>;

	public function new(?parent:ScriptTypeScope) {
		this.parent = parent;
		this.bindings = new StringMap();
	}

	public function define(binding:ScriptBindingInfo):Void {
		if (bindings.exists(binding.name)) {
			throw new ScriptError("Duplicate binding '" + binding.name + "'.", binding.span);
		}

		bindings.set(binding.name, binding);
	}

	public function resolve(name:String):Null<ScriptBindingInfo> {
		var current:Null<ScriptTypeScope> = this;

		while (current != null) {
			var binding = current.bindings.get(name);

			if (binding != null) {
				return binding;
			}

			current = current.parent;
		}

		return null;
	}
}

class ScriptChecker {
	public static function check(program:ScriptProgram):ScriptProgramInfo {
		var sourceMap = new ScriptSourceMap();
		sourceMap.add(program.span.sourceName, program.sourceText);
		var moduleName = program.moduleName == null ? ["__main__"] : program.moduleName;
		var wrapped = new ScriptProgram(moduleName, program.imports, program.declarations, program.span, program.sourceText);
		var modules = new StringMap<ScriptProgram>();
		var name = moduleName.join(".");
		modules.set(name, wrapped);
		var project = new ScriptProject(modules, sourceMap);
		var info = checkProject(project);
		return new ScriptProgramInfo(info, info.modules.get(name));
	}

	public static function checkProject(project:ScriptProject):ScriptProjectInfo {
		return new ScriptProjectChecker(project).run();
	}
}

private class ScriptProjectChecker {
	var project:ScriptProject;
	var modules:StringMap<ScriptModuleInfo>;
	var structs:StringMap<ScriptStructInfo>;
	var enums:StringMap<ScriptEnumInfo>;

	public function new(project:ScriptProject) {
		this.project = project;
		this.modules = new StringMap();
		this.structs = new StringMap();
		this.enums = new StringMap();
	}

	public function run():ScriptProjectInfo {
		buildModules();
		registerTypeNames();
		resolveTypeDeclarations();
		predeclareExports();
		var moduleOrder = computeModuleOrder();
		checkBodies(moduleOrder);
		return new ScriptProjectInfo(project, modules, structs, enums, moduleOrder, project.sourceMap);
	}

	function buildModules():Void {
		for (moduleName => program in project.modules) {
			var importMap = new StringMap<String>();

			for (importDecl in program.imports) {
				var importedName = importDecl.path.join(".");

				if (!project.modules.exists(importedName)) {
					throw new ScriptError("Unknown imported module '" + importedName + "'.", importDecl.span);
				}

				var alias = importDecl.aliasOrDefault();

				if (importMap.exists(alias)) {
					throw new ScriptError("Duplicate import alias '" + alias + "'.", importDecl.span);
				}

				importMap.set(alias, importedName);
			}

			var index = ScriptModuleIndexer.build(program);
			modules.set(
				moduleName,
				new ScriptModuleInfo(
					moduleName,
					program,
					importMap,
					new StringMap(),
					index.functions,
					index.exprs,
					new IntMap(),
					index.values,
					index.assigns
				)
			);
		}
	}

	function registerTypeNames():Void {
		for (moduleName => moduleInfo in modules) {
			for (decl in moduleInfo.program.declarations) {
				switch decl {
					case DStruct(structDecl):
						var qualified = moduleName + "." + structDecl.name;

						if (structs.exists(qualified) || enums.exists(qualified)) {
							throw new ScriptError("Duplicate type '" + qualified + "'.", structDecl.span);
						}

						structs.set(qualified, new ScriptStructInfo(qualified, moduleName, structDecl.name, structDecl, new StringMap(), []));
					case DEnum(enumDecl):
						var qualified = moduleName + "." + enumDecl.name;

						if (structs.exists(qualified) || enums.exists(qualified)) {
							throw new ScriptError("Duplicate type '" + qualified + "'.", enumDecl.span);
						}

						enums.set(qualified, new ScriptEnumInfo(qualified, moduleName, enumDecl.name, enumDecl, new StringMap(), []));
					case DFunction(_) | DValue(_):
				}
			}
		}
	}

	function resolveTypeDeclarations():Void {
		for (_ => structInfo in structs) {
			for (field in structInfo.decl.fields) {
				if (structInfo.fields.exists(field.name)) {
					throw new ScriptError("Duplicate field '" + field.name + "' in struct '" + structInfo.name + "'.", field.span);
				}

				structInfo.fields.set(field.name, resolveTypeRef(modules.get(structInfo.moduleName), field.type));
				structInfo.fieldOrder.push(field.name);
			}
		}

		for (_ => enumInfo in enums) {
			for (caseDecl in enumInfo.decl.cases) {
				if (enumInfo.cases.exists(caseDecl.name)) {
					throw new ScriptError("Duplicate case '" + caseDecl.name + "' in enum '" + enumInfo.name + "'.", caseDecl.span);
				}

				enumInfo.cases.set(caseDecl.name, true);
				enumInfo.caseOrder.push(caseDecl.name);
			}
		}
	}

	function predeclareExports():Void {
		for (_ => moduleInfo in modules) {
			for (decl in moduleInfo.program.declarations) {
				switch decl {
					case DFunction(fnDecl):
						if (moduleInfo.exports.exists(fnDecl.name)) {
							throw new ScriptError("Duplicate export '" + fnDecl.name + "'.", fnDecl.span);
						}

						if (fnDecl.returnType == null) {
							throw new ScriptError("Top-level functions must declare a return type with '->'.", fnDecl.span);
						}

						var paramTypes = [for (param in fnDecl.params) resolveTypeRef(moduleInfo, param.type)];
						var returnType = resolveTypeRef(moduleInfo, fnDecl.returnType);
						moduleInfo.exports.set(fnDecl.name, new ScriptBindingInfo(fnDecl.name, TFunction(paramTypes, returnType), false, fnDecl.span));
					case DValue(valueDecl):
						if (moduleInfo.exports.exists(valueDecl.name)) {
							throw new ScriptError("Duplicate export '" + valueDecl.name + "'.", valueDecl.span);
						}

						if (valueDecl.type == null) {
							throw new ScriptError("Top-level bindings must declare a type.", valueDecl.span);
						}

						moduleInfo.exports.set(
							valueDecl.name,
							new ScriptBindingInfo(valueDecl.name, resolveTypeRef(moduleInfo, valueDecl.type), true, valueDecl.span)
						);
					case DStruct(_) | DEnum(_):
				}
			}
		}
	}

	function computeModuleOrder():Array<String> {
		var order:Array<String> = [];
		var temp = new StringMap<Bool>();
		var done = new StringMap<Bool>();

		for (moduleName => _ in modules) {
			visitModule(moduleName, temp, done, order);
		}

		return order;
	}

	function visitModule(name:String, temp:StringMap<Bool>, done:StringMap<Bool>, order:Array<String>):Void {
		if (done.exists(name)) {
			return;
		}

		if (temp.exists(name)) {
			throw new ScriptError("Import cycle detected at module '" + name + "'.");
		}

		temp.set(name, true);
		var moduleInfo = modules.get(name);

		for (_ => importedName in moduleInfo.imports) {
			visitModule(importedName, temp, done, order);
		}

		temp.remove(name);
		done.set(name, true);
		order.push(name);
	}

	function checkBodies(moduleOrder:Array<String>):Void {
		for (moduleName in moduleOrder) {
			var moduleInfo = modules.get(moduleName);

			for (decl in moduleInfo.program.declarations) {
				switch decl {
					case DFunction(fnDecl):
						checkFunction(moduleInfo, fnDecl);
					case DValue(valueDecl):
						checkTopLevelValue(moduleInfo, valueDecl);
					case DStruct(_) | DEnum(_):
				}
			}
		}
	}

	function checkTopLevelValue(moduleInfo:ScriptModuleInfo, valueDecl:ScriptValueDecl):Void {
		var expectedType = moduleInfo.exports.get(valueDecl.name).type;
		var actualType = inferExpr(valueDecl.value, moduleInfo, new ScriptTypeScope());

		if (!ScriptTypeTools.isAssignable(expectedType, actualType)) {
			throw new ScriptError(
				"Binding '" + valueDecl.name + "' expects " + ScriptTypeTools.format(expectedType)
					+ " but found " + ScriptTypeTools.format(actualType) + ".",
				valueDecl.span
			);
		}
	}

	function checkFunction(moduleInfo:ScriptModuleInfo, fnDecl:ScriptFunctionDecl):Void {
		var fnType = moduleInfo.exports.get(fnDecl.name).type;
		var scope = new ScriptTypeScope();
		var paramTypes = extractFunctionParams(fnType);

		for (index in 0...fnDecl.params.length) {
			scope.define(new ScriptBindingInfo(fnDecl.params[index].name, paramTypes[index], true, fnDecl.params[index].span));
		}

		var bodyType = inferExpr(fnDecl.body, moduleInfo, scope);
		var returnType = extractFunctionReturn(fnType);

		if (!ScriptTypeTools.isAssignable(returnType, bodyType)) {
			throw new ScriptError(
				"Function '" + fnDecl.name + "' returns " + ScriptTypeTools.format(bodyType)
					+ " but declared " + ScriptTypeTools.format(returnType) + ".",
				fnDecl.body.span
			);
		}
	}

	function inferExpr(expr:ScriptExpr, moduleInfo:ScriptModuleInfo, scope:ScriptTypeScope):ScriptType {
		var inferred = switch expr.def {
			case EInt(_):
				TInt;
			case EFloat(_):
				TFloat;
			case EString(_):
				TString;
			case EBool(_):
				TBool;
			case EPath(path):
				resolveValuePath(path, moduleInfo, scope, expr.span);
			case EList(elements):
				inferListExpr(elements, moduleInfo, scope, expr.span);
			case ERecord(typePath, fields):
				inferRecordExpr(typePath, fields, moduleInfo, scope, expr.span);
			case ELambda(params, returnTypeRef, body):
				var localScope = new ScriptTypeScope(scope);
				var paramTypes = [for (param in params) resolveTypeRef(moduleInfo, param.type)];

				for (index in 0...params.length) {
					localScope.define(new ScriptBindingInfo(params[index].name, paramTypes[index], true, params[index].span));
				}

				var bodyType = inferExpr(body, moduleInfo, localScope);
				var returnType = returnTypeRef == null ? bodyType : resolveTypeRef(moduleInfo, returnTypeRef);

				if (!ScriptTypeTools.isAssignable(returnType, bodyType)) {
					throw new ScriptError(
						"Lambda returns " + ScriptTypeTools.format(bodyType)
							+ " but declared " + ScriptTypeTools.format(returnType) + ".",
						body.span
					);
				}

				TFunction(paramTypes, returnType);
			case ECall(callee, args):
				var calleeType = inferExpr(callee, moduleInfo, scope);
				var argTypes = [for (arg in args) inferExpr(arg, moduleInfo, scope)];

				switch calleeType {
					case TFunction(paramTypes, returnType):
						checkCallArgs(paramTypes, argTypes, expr.span);
						returnType;
					case TBuiltin(name):
						ScriptBuiltins.typeCheckCall(name, argTypes, expr.span);
					default:
						throw new ScriptError(
							"Cannot call value of type " + ScriptTypeTools.format(calleeType) + ".",
							callee.span
						);
				}
			case EField(target, name):
				inferFieldAccess(inferExpr(target, moduleInfo, scope), name, expr.span);
			case EIndex(target, index):
				inferIndexAccess(inferExpr(target, moduleInfo, scope), inferExpr(index, moduleInfo, scope), expr.span);
			case EUnary(op, inner):
				inferUnary(op, inferExpr(inner, moduleInfo, scope), inner.span);
			case EBinary(op, left, right):
				inferBinary(op, inferExpr(left, moduleInfo, scope), inferExpr(right, moduleInfo, scope), expr.span);
			case EIf(condition, thenBranch, elseBranch):
				var conditionType = inferExpr(condition, moduleInfo, scope);

				if (!ScriptTypeTools.equals(conditionType, TBool)) {
					throw new ScriptError("If conditions must be Bool.", condition.span);
				}

				var thenType = inferExpr(thenBranch, moduleInfo, scope);
				var elseType = inferExpr(elseBranch, moduleInfo, scope);

				if (!ScriptTypeTools.equals(thenType, elseType)) {
					throw new ScriptError(
						"If branches must return the same type, found "
							+ ScriptTypeTools.format(thenType) + " and " + ScriptTypeTools.format(elseType) + ".",
						expr.span
					);
				}

				thenType;
			case EBlock(statements, tail):
				inferBlock(statements, tail, moduleInfo, scope);
		};

		moduleInfo.exprTypes.set(expr.id, inferred);
		return inferred;
	}

	function inferListExpr(elements:Array<ScriptExpr>, moduleInfo:ScriptModuleInfo, scope:ScriptTypeScope, span:ScriptSpan):ScriptType {
		if (elements.length == 0) {
			throw new ScriptError("Empty list literals are not supported without a typed constructor.", span);
		}

		var itemType = inferExpr(elements[0], moduleInfo, scope);

		if (ScriptTypeTools.equals(itemType, TVoid)) {
			throw new ScriptError("List elements cannot be Void.", elements[0].span);
		}

		for (index in 1...elements.length) {
			var nextType = inferExpr(elements[index], moduleInfo, scope);

			if (!ScriptTypeTools.equals(itemType, nextType)) {
				throw new ScriptError(
					"List elements must all have the same type, found "
						+ ScriptTypeTools.format(itemType) + " and " + ScriptTypeTools.format(nextType) + ".",
					elements[index].span
				);
			}
		}

		return TList(itemType);
	}

	function inferRecordExpr(
		typePath:ScriptPath,
		fields:Array<ScriptRecordFieldInit>,
		moduleInfo:ScriptModuleInfo,
		scope:ScriptTypeScope,
		span:ScriptSpan
	):ScriptType {
		var type = resolveNamedTypePath(moduleInfo, typePath, span);
		var recordName = switch type {
			case TRecord(name): name;
			default:
				throw new ScriptError("Record literals require a struct type.", span);
		};

		var structInfo = structs.get(recordName);
		var seen = new StringMap<Bool>();

		for (field in fields) {
			if (seen.exists(field.name)) {
				throw new ScriptError("Duplicate field '" + field.name + "' in record literal.", field.span);
			}

			seen.set(field.name, true);
			var expectedType = structInfo.fields.get(field.name);

			if (expectedType == null) {
				throw new ScriptError("Unknown field '" + field.name + "' for struct '" + structInfo.name + "'.", field.span);
			}

			var actualType = inferExpr(field.value, moduleInfo, scope);

			if (!ScriptTypeTools.isAssignable(expectedType, actualType)) {
				throw new ScriptError(
					"Field '" + field.name + "' expects " + ScriptTypeTools.format(expectedType)
						+ " but found " + ScriptTypeTools.format(actualType) + ".",
					field.span
				);
			}
		}

		for (fieldName in structInfo.fieldOrder) {
			if (!seen.exists(fieldName)) {
				throw new ScriptError("Missing field '" + fieldName + "' for struct '" + structInfo.name + "'.", span);
			}
		}

		return TRecord(recordName);
	}

	function inferBlock(
		statements:Array<ScriptStmt>,
		tail:Null<ScriptExpr>,
		moduleInfo:ScriptModuleInfo,
		scope:ScriptTypeScope
	):ScriptType {
		var blockScope = new ScriptTypeScope(scope);

		for (statement in statements) {
			switch statement {
				case SLet(binding):
					var bindingType = binding.type == null ? inferExpr(binding.value, moduleInfo, blockScope) : resolveTypeRef(moduleInfo, binding.type);
					var valueType = inferExpr(binding.value, moduleInfo, blockScope);

					if (!ScriptTypeTools.isAssignable(bindingType, valueType)) {
						throw new ScriptError(
							"Binding '" + binding.name + "' expects " + ScriptTypeTools.format(bindingType)
								+ " but found " + ScriptTypeTools.format(valueType) + ".",
							binding.span
						);
					}

					if (ScriptTypeTools.equals(bindingType, TVoid)) {
						throw new ScriptError("Bindings cannot store Void values.", binding.span);
					}

					blockScope.define(new ScriptBindingInfo(binding.name, bindingType, true, binding.span));
				case SSet(assign):
					checkAssignment(assign, moduleInfo, blockScope);
				case SExpr(expr):
					inferExpr(expr, moduleInfo, blockScope);
			}
		}

		return tail == null ? TVoid : inferExpr(tail, moduleInfo, blockScope);
	}

	function checkAssignment(assign:ScriptAssign, moduleInfo:ScriptModuleInfo, scope:ScriptTypeScope):Void {
		if (assign.target.length != 1) {
			throw new ScriptError("Assignments only support simple identifiers.", assign.span);
		}

		var name = assign.target[0];
		var local = scope.resolve(name);
		var binding = local != null ? local : moduleInfo.exports.get(name);

		if (binding == null) {
			throw new ScriptError("Unknown binding '" + name + "'.", assign.span);
		}

		if (!binding.mutable) {
			throw new ScriptError("Binding '" + name + "' is immutable.", assign.span);
		}

		var valueType = inferExpr(assign.value, moduleInfo, scope);

		if (!ScriptTypeTools.isAssignable(binding.type, valueType)) {
			throw new ScriptError(
				"Cannot assign " + ScriptTypeTools.format(valueType) + " to " + ScriptTypeTools.format(binding.type) + ".",
				assign.span
			);
		}
	}

	function resolveTypeRef(moduleInfo:ScriptModuleInfo, typeRef:ScriptTypeRef):ScriptType {
		if (typeRef.path.length == 1) {
			return switch typeRef.path[0] {
				case "Void":
					requireNoTypeArgs(typeRef, 0);
					TVoid;
				case "Int":
					requireNoTypeArgs(typeRef, 0);
					TInt;
				case "Float":
					requireNoTypeArgs(typeRef, 0);
					TFloat;
				case "String":
					requireNoTypeArgs(typeRef, 0);
					TString;
				case "Bool":
					requireNoTypeArgs(typeRef, 0);
					TBool;
				case "List":
					requireNoTypeArgs(typeRef, 1);
					TList(resolveTypeRef(moduleInfo, typeRef.args[0]));
				default:
					resolveNamedTypePath(moduleInfo, typeRef.path, typeRef.span);
			};
		}

		return resolveNamedTypePath(moduleInfo, typeRef.path, typeRef.span);
	}

	function requireNoTypeArgs(typeRef:ScriptTypeRef, expected:Int):Void {
		if (typeRef.args.length != expected) {
			throw new ScriptError(
				"Type '" + typeRef.path.join(".") + "' expects " + expected + " type arguments.",
				typeRef.span
			);
		}
	}

	function resolveNamedTypePath(moduleInfo:ScriptModuleInfo, path:ScriptPath, span:ScriptSpan):ScriptType {
		if (path.length == 0) {
			throw new ScriptError("Expected a type path.", span);
		}

		if (path.length == 1) {
			var localTypeName = moduleInfo.name + "." + path[0];

			if (structs.exists(localTypeName)) {
				return TRecord(localTypeName);
			}

			if (enums.exists(localTypeName)) {
				return TEnum(localTypeName);
			}
		}

		var viaImport = resolveImportTypePath(moduleInfo, path);

		if (viaImport != null) {
			return viaImport;
		}

		var qualified = path.join(".");

		if (structs.exists(qualified)) {
			return TRecord(qualified);
		}

		if (enums.exists(qualified)) {
			return TEnum(qualified);
		}

		throw new ScriptError("Unknown type '" + qualified + "'.", span);
	}

	function resolveImportTypePath(moduleInfo:ScriptModuleInfo, path:ScriptPath):Null<ScriptType> {
		var importedModule = moduleInfo.imports.get(path[0]);

		if (importedModule == null) {
			return null;
		}

		var qualified = importedModule + "." + path.slice(1).join(".");

		if (structs.exists(qualified)) {
			return TRecord(qualified);
		}

		if (enums.exists(qualified)) {
			return TEnum(qualified);
		}

		return null;
	}

	function resolveValuePath(path:ScriptPath, moduleInfo:ScriptModuleInfo, scope:ScriptTypeScope, span:ScriptSpan):ScriptType {
		if (path.length == 0) {
			throw new ScriptError("Expected a value path.", span);
		}

		var local = scope.resolve(path[0]);

		if (local != null) {
			return resolveFieldPath(local.type, path.slice(1), span);
		}

		var localExport = moduleInfo.exports.get(path[0]);

		if (localExport != null) {
			return resolveFieldPath(localExport.type, path.slice(1), span);
		}

		if (path.length == 2) {
			var localEnumName = moduleInfo.name + "." + path[0];
			var localEnum = enums.get(localEnumName);

			if (localEnum != null && localEnum.cases.exists(path[1])) {
				return TEnum(localEnumName);
			}
		}

		if (path[0] == "std") {
			var builtinName = path.join(".");

			if (!ScriptBuiltins.has(builtinName)) {
				throw new ScriptError("Unknown builtin '" + builtinName + "'.", span);
			}

			if (path.length != 2) {
				throw new ScriptError("Builtins do not expose nested fields.", span);
			}

			return TBuiltin(builtinName);
		}

		var moduleTarget = resolveModuleReference(moduleInfo, path);

		if (moduleTarget != null) {
			return resolveModuleValuePath(moduleTarget.moduleName, moduleTarget.remainder, span);
		}

		throw new ScriptError("Unknown value '" + path.join(".") + "'.", span);
	}

	function resolveModuleReference(moduleInfo:ScriptModuleInfo, path:ScriptPath):Null<{ moduleName:String, remainder:ScriptPath }> {
		if (path.length >= 2) {
			var imported = moduleInfo.imports.get(path[0]);

			if (imported != null) {
				return { moduleName: imported, remainder: path.slice(1) };
			}
		}

		for (prefixLength in 1...path.length) {
			var moduleName = path.slice(0, prefixLength).join(".");

			if (modules.exists(moduleName)) {
				return { moduleName: moduleName, remainder: path.slice(prefixLength) };
			}
		}

		return null;
	}

	function resolveModuleValuePath(moduleName:String, remainder:ScriptPath, span:ScriptSpan):ScriptType {
		if (remainder.length == 0) {
			throw new ScriptError("Module '" + moduleName + "' is not a value.", span);
		}

		var moduleInfo = modules.get(moduleName);
		var exportBinding = moduleInfo.exports.get(remainder[0]);

		if (exportBinding != null) {
			return resolveFieldPath(exportBinding.type, remainder.slice(1), span);
		}

		if (remainder.length == 2) {
			var enumName = moduleName + "." + remainder[0];
			var enumInfo = enums.get(enumName);

			if (enumInfo != null && enumInfo.cases.exists(remainder[1])) {
				return TEnum(enumName);
			}
		}

		throw new ScriptError("Unknown module value '" + moduleName + "." + remainder.join(".") + "'.", span);
	}

	function resolveFieldPath(baseType:ScriptType, fields:Array<String>, span:ScriptSpan):ScriptType {
		var currentType = baseType;

		for (fieldName in fields) {
			switch currentType {
				case TRecord(recordName):
					var structInfo = structs.get(recordName);
					var nextType = structInfo.fields.get(fieldName);

					if (nextType == null) {
						throw new ScriptError("Unknown field '" + fieldName + "' on struct '" + structInfo.name + "'.", span);
					}

					currentType = nextType;
				default:
					throw new ScriptError("Type " + ScriptTypeTools.format(currentType) + " does not expose field '" + fieldName + "'.", span);
			}
		}

		return currentType;
	}

	function inferFieldAccess(targetType:ScriptType, fieldName:String, span:ScriptSpan):ScriptType {
		return switch targetType {
			case TRecord(recordName):
				var structInfo = structs.get(recordName);
				var fieldType = structInfo.fields.get(fieldName);

				if (fieldType == null) {
					throw new ScriptError("Unknown field '" + fieldName + "' on struct '" + structInfo.name + "'.", span);
				}

				fieldType;
			default:
				throw new ScriptError("Type " + ScriptTypeTools.format(targetType) + " does not expose field '" + fieldName + "'.", span);
		};
	}

	function inferIndexAccess(targetType:ScriptType, indexType:ScriptType, span:ScriptSpan):ScriptType {
		if (!ScriptTypeTools.equals(indexType, TInt)) {
			throw new ScriptError("List indices must be Int.", span);
		}

		return switch targetType {
			case TList(itemType):
				itemType;
			default:
				throw new ScriptError("Type " + ScriptTypeTools.format(targetType) + " is not indexable.", span);
		};
	}

	function checkCallArgs(expected:Array<ScriptType>, actual:Array<ScriptType>, span:ScriptSpan):Void {
		if (expected.length != actual.length) {
			throw new ScriptError("Expected " + expected.length + " call arguments but found " + actual.length + ".", span);
		}

		for (index in 0...expected.length) {
			if (!ScriptTypeTools.isAssignable(expected[index], actual[index])) {
				throw new ScriptError(
					"Argument " + (index + 1) + " expects " + ScriptTypeTools.format(expected[index])
						+ " but found " + ScriptTypeTools.format(actual[index]) + ".",
					span
				);
			}
		}
	}

	function inferUnary(op:ScriptUnaryOp, operandType:ScriptType, span:ScriptSpan):ScriptType {
		return switch op {
			case Negate:
				if (!ScriptTypeTools.isNumeric(operandType)) {
					throw new ScriptError("Unary '-' expects an Int or Float.", span);
				}

				operandType;
			case Not:
				if (!ScriptTypeTools.equals(operandType, TBool)) {
					throw new ScriptError("Unary '!' expects a Bool.", span);
				}

				TBool;
		};
	}

	function inferBinary(op:ScriptBinaryOp, leftType:ScriptType, rightType:ScriptType, span:ScriptSpan):ScriptType {
		return switch op {
			case Add:
				if (ScriptTypeTools.equals(leftType, TString) && ScriptTypeTools.equals(rightType, TString)) {
					TString;
				} else if (ScriptTypeTools.isNumeric(leftType) && ScriptTypeTools.equals(leftType, rightType)) {
					leftType;
				} else {
					throw new ScriptError("Operator '+' requires matching numeric types or two Strings.", span);
				}
			case Subtract | Multiply | Divide | Modulo:
				if (!ScriptTypeTools.isNumeric(leftType) || !ScriptTypeTools.equals(leftType, rightType)) {
					throw new ScriptError("Arithmetic operators require matching numeric types.", span);
				}

				leftType;
			case Equal | NotEqual:
				if (!ScriptTypeTools.equals(leftType, rightType)) {
					throw new ScriptError("Equality operators require both sides to have the same type.", span);
				}

				switch leftType {
					case TInt | TFloat | TString | TBool | TEnum(_):
						TBool;
					default:
						throw new ScriptError("Equality is only supported on primitive values and enums.", span);
				}
			case Less | LessEqual | Greater | GreaterEqual:
				if (!ScriptTypeTools.isNumeric(leftType) || !ScriptTypeTools.equals(leftType, rightType)) {
					throw new ScriptError("Comparison operators require matching numeric types.", span);
				}

				TBool;
			case And | Or:
				if (!ScriptTypeTools.equals(leftType, TBool) || !ScriptTypeTools.equals(rightType, TBool)) {
					throw new ScriptError("Logical operators require Bool operands.", span);
				}

				TBool;
		};
	}

	function extractFunctionParams(type:ScriptType):Array<ScriptType> {
		return switch type {
			case TFunction(paramTypes, _):
				paramTypes;
			default:
				throw new ScriptError("Expected a function type.");
		};
	}

	function extractFunctionReturn(type:ScriptType):ScriptType {
		return switch type {
			case TFunction(_, returnType):
				returnType;
			default:
				throw new ScriptError("Expected a function type.");
		};
	}
}
