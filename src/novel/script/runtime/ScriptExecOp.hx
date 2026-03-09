package novel.script.runtime;

import novel.script.syntax.ScriptAst.ScriptBinaryOp;
import novel.script.syntax.ScriptAst.ScriptUnaryOp;

enum ScriptExecOp {
	OEval(exprId:Int);
	OPushVoid;
	OEnterScope;
	OExitScope;
	ODiscard;
	OBind(valueDeclId:Int);
	OAssign(assignId:Int);
	OBuildList(count:Int);
	OBuildRecord(typeName:String, fieldNames:Array<String>);
	OApplyUnary(op:ScriptUnaryOp);
	OApplyBinary(op:ScriptBinaryOp);
	OApplyField(name:String);
	OApplyIndex;
	OBranch(thenExprId:Int, elseExprId:Int);
	OCall(argCount:Int);
}
