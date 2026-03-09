package novel.script.tests;

import novel.script.ScriptEngine;
import novel.script.ScriptError;
import novel.script.project.ScriptLinker.ScriptLinkedProject;
import novel.script.project.ScriptProject.ScriptProjectInfo;
import novel.script.project.ScriptProject.ScriptSourceInput;
import novel.script.runtime.ScriptValue;
import novel.script.runtime.ScriptValue.ScriptValueTools;

class ScriptSmoke {
	static final SOURCES:Array<ScriptSourceInput> = [
		{
			sourceName: "common/types.nvsl",
			source: '
module common.types;

enum Mood {
	Warm;
	Cold;
}

struct Character {
	name: String;
	mood: common.types.Mood;
	tags: List<String>;
}

fn moodLabel(mood: common.types.Mood) -> String {
	if mood == common.types.Mood.Warm { "warm" } else { "cold" }
}
'
		},
		{
			sourceName: "game/state.nvsl",
			source: '
module game.state;

import common.types as types;

let hero: types.Character = types.Character {
	name: "Ava",
	mood: types.Mood.Warm,
	tags: ["pilot", "friend"]
};

let score: Int = 4;

fn nextScore(delta: Int) -> Int {
	set score = score + delta;
	score
}

fn heroMood() -> String {
	types.moodLabel(hero.mood)
}

fn heroTagCount() -> Int {
	std.len(hero.tags)
}

fn currentHero() -> types.Character {
	hero
}
'
		},
		{
			sourceName: "game/app.nvsl",
			source: '
module game.app;

import common.types as types;
import game.state as state;

fn heroMoodLabel() -> String {
	types.moodLabel(state.currentHero().mood)
}

fn firstTag() -> String {
	state.currentHero().tags[0]
}

fn orchestrate(delta: Int) -> Int {
	let next: Int = state.nextScore(delta);
	next + 1
}

fn repeatedTagline() -> String {
	std.repeat("ha", 3)
}

fn joinedTags() -> String {
	std.join(state.currentHero().tags, ", ")
}

fn pushedTagCount() -> Int {
	std.len(std.listPush(state.currentHero().tags, "ace"))
}

fn updatedSecondTag() -> String {
	std.listSet(state.currentHero().tags, 1, "ally")[1]
}

fn increment(value: Int) -> Int {
	value + 1
}

fn namedFunctionValue(value: Int) -> Int {
	let stepper = increment;
	stepper(value)
}

fn importedFunctionValue() -> String {
	let labeler = types.moodLabel;
	labeler(types.Mood.Warm)
}

fn builtinFunctionValue(value: Int) -> Int {
	let chooser = std.max;
	chooser(value, 3)
}

fn lambdaCapture(start: Int, bonus: Int) -> Int {
	let offset = bonus;
	let apply = fn(value: Int) => value + offset;
	apply(start)
}

fn nestedLambdaCapture(start: Int, bonus: Int) -> Int {
	let makeAdder = fn(delta: Int) => fn(value: Int) => value + delta + bonus;
	let add = makeAdder(2);
	add(start)
}
'
		}
	];

	public static function main():Void {
		var linked = ScriptEngine.linkSources(SOURCES, "game.app", "heroMoodLabel");
		var info = linked.info;
		var runtime = linked.load();

		assertModuleExists(info, "common.types");
		assertModuleExists(info, "game.state");
		assertModuleExists(info, "game.app");
		assertEntrypoint(linked, "game.app", "heroMoodLabel");

		assertString(runtime.call("game.state", "heroMood", []), "warm", "heroMood");
		assertInt(runtime.call("game.state", "heroTagCount", []), 2, "heroTagCount");
		assertInt(runtime.call("game.state", "nextScore", [VInt(3)]), 7, "nextScore");
		assertString(runtime.call("game.app", "heroMoodLabel", []), "warm", "heroMoodLabel");
		assertString(runtime.call("game.app", "firstTag", []), "pilot", "firstTag");
		assertString(runtime.call("game.app", "repeatedTagline", []), "hahaha", "repeatedTagline");
		assertString(runtime.call("game.app", "joinedTags", []), "pilot, friend", "joinedTags");
		assertInt(runtime.call("game.app", "pushedTagCount", []), 3, "pushedTagCount");
		assertString(runtime.call("game.app", "updatedSecondTag", []), "ally", "updatedSecondTag");
		assertInt(runtime.call("game.app", "namedFunctionValue", [VInt(6)]), 7, "namedFunctionValue");
		assertString(runtime.call("game.app", "importedFunctionValue", []), "warm", "importedFunctionValue");
		assertInt(runtime.call("game.app", "builtinFunctionValue", [VInt(2)]), 3, "builtinFunctionValue");
		assertInt(runtime.call("game.app", "lambdaCapture", [VInt(5), VInt(4)]), 9, "lambdaCapture");
		assertInt(runtime.call("game.app", "nestedLambdaCapture", [VInt(4), VInt(3)]), 9, "nestedLambdaCapture");
		assertInt(runtime.call("game.state", "heroTagCount", []), 2, "heroTagCount unchanged");
		assertBytecodePipeline();

		assertResumableExecution(linked);

		var snapshotData = runtime.createSnapshotData();
		var snapshot = runtime.createSnapshot();
		assertInt(runtime.call("game.state", "nextScore", [VInt(2)]), 9, "nextScore after mutate");
		runtime.restoreSnapshot(snapshot);
		assertInt(runtime.call("game.state", "nextScore", [VInt(0)]), 7, "nextScore after restore");
		expectFailure("snapshot schema mismatch", function() {
			runtime.restoreSnapshotData({
				format: snapshotData.format,
				version: snapshotData.version,
				schema: snapshotData.schema + "::changed",
				modules: snapshotData.modules,
			});
		});

		assertDiagnosticFormatting();

		Sys.println("Script smoke ok: link, parse, check, runtime, NVBC, VM, resume, diagnostics, and snapshot passed.");
	}

	static function assertModuleExists(info:ScriptProjectInfo, name:String):Void {
		if (!info.modules.exists(name)) {
			throw new ScriptError("Expected module '" + name + "' to exist.");
		}
	}

	static function assertEntrypoint(linked:ScriptLinkedProject, moduleName:String, exportName:String):Void {
		if (linked.entry == null) {
			throw new ScriptError("Expected a linked entrypoint.");
		}

		if (linked.entry.moduleName != moduleName || linked.entry.exportName != exportName) {
			throw new ScriptError(
				"Expected entrypoint " + moduleName + "." + exportName
					+ " but got " + linked.entry.moduleName + "." + linked.entry.exportName + "."
			);
		}
	}

	static function assertInt(value:ScriptValue, expected:Int, label:String):Void {
		switch value {
			case VInt(actual) if (actual == expected):
			case VInt(actual):
				throw new ScriptError(label + " expected " + expected + " but got " + actual + ".");
			default:
				throw new ScriptError(label + " expected Int but got " + ScriptValueTools.format(value) + ".");
		}
	}

	static function assertFloat(value:ScriptValue, expected:Float, label:String):Void {
		switch value {
			case VFloat(actual) if (Math.abs(actual - expected) < 0.0001):
			case VFloat(actual):
				throw new ScriptError(label + " expected " + expected + " but got " + actual + ".");
			default:
				throw new ScriptError(label + " expected Float but got " + ScriptValueTools.format(value) + ".");
		}
	}

	static function assertString(value:ScriptValue, expected:String, label:String):Void {
		switch value {
			case VString(actual) if (actual == expected):
			case VString(actual):
				throw new ScriptError(label + " expected " + expected + " but got " + actual + ".");
			default:
				throw new ScriptError(label + " expected String but got " + ScriptValueTools.format(value) + ".");
		}
	}

	static function assertDiagnosticFormatting():Void {
		var brokenSources:Array<ScriptSourceInput> = [
			{
				sourceName: "broken/sample.nvsl",
				source: '
module broken.sample;

fn bad(value: Int) -> Int {
	value + "oops"
}
'
			}
		];
		var project = ScriptEngine.parseSources(brokenSources);

		try {
			ScriptEngine.checkProject(project);
			throw new ScriptError("Expected broken sample to fail type checking.");
		} catch (error:ScriptError) {
			var formatted = ScriptEngine.formatError(error, project.sourceMap);

			if (formatted.indexOf("broken/sample.nvsl:") == -1) {
				throw new ScriptError("Formatted diagnostic is missing the source location.");
			}

			if (formatted.indexOf("^") == -1) {
				throw new ScriptError("Formatted diagnostic is missing the underline.");
			}
		}
	}

	static function assertResumableExecution(linked:ScriptLinkedProject):Void {
		var runtime = linked.load();
		var execution = runtime.beginExecution("game.app", "orchestrate", [VInt(3)]);
		var guard = 0;

		while (!execution.isComplete() && execution.frameDepth() < 2 && guard < 128) {
			execution.step(1);
			guard++;
		}

		if (execution.frameDepth() < 2) {
			throw new ScriptError("Expected resumable execution to reach a nested call frame.");
		}

		var snapshot = execution.createSnapshot();
		var restoredRuntime = linked.load();
		var restoredExecution = restoredRuntime.restoreExecutionSnapshot(snapshot);

		assertInt(restoredExecution.run(), 8, "orchestrate resumed result");
		assertInt(restoredRuntime.getModule("game.state").getGlobal("score"), 7, "orchestrate resumed score");
		assertAstLambdaExecutionResume(linked);
	}

	static function assertAstLambdaExecutionResume(linked:ScriptLinkedProject):Void {
		var runtime = linked.load();
		var execution = runtime.beginExecution("game.app", "nestedLambdaCapture", [VInt(4), VInt(3)]);
		var sawNested = false;
		var guard = 0;

		while (!execution.isComplete() && guard < 256) {
			if (execution.frameDepth() > 1) {
				sawNested = true;
			}

			execution.step(1);

			if (sawNested && execution.frameDepth() == 1 && !execution.isComplete()) {
				break;
			}

			guard++;
		}

		if (!sawNested || execution.isComplete()) {
			throw new ScriptError("Expected AST execution snapshot test to pause mid-flight after a nested lambda call.");
		}

		var snapshot = execution.createSnapshot();
		var restoredRuntime = linked.load();
		var restoredExecution = restoredRuntime.restoreExecutionSnapshot(snapshot);

		assertInt(restoredExecution.run(), 9, "ast nested lambda resumed result");
	}

	static function assertBytecodePipeline():Void {
		var program = ScriptEngine.compileSources(SOURCES, "game.app", "heroMoodLabel");
		var encoded = ScriptEngine.encodeBytecode(program);
		var decoded = ScriptEngine.decodeBytecode(encoded);

		if (decoded.defaultEntryModule != "game.app" || decoded.defaultEntryExport != "heroMoodLabel") {
			throw new ScriptError("Expected NVBC default entrypoint game.app.heroMoodLabel.");
		}

		var runtime = ScriptEngine.loadBytecode(decoded);

		assertString(runtime.callDefault([]), "warm", "vm default entry");
		assertString(runtime.call("game.app", "firstTag", []), "pilot", "vm firstTag");
		assertString(runtime.call("game.app", "repeatedTagline", []), "hahaha", "vm repeatedTagline");
		assertString(runtime.call("game.app", "joinedTags", []), "pilot, friend", "vm joinedTags");
		assertString(runtime.call("game.app", "updatedSecondTag", []), "ally", "vm updatedSecondTag");
		assertInt(runtime.call("game.app", "namedFunctionValue", [VInt(6)]), 7, "vm namedFunctionValue");
		assertString(runtime.call("game.app", "importedFunctionValue", []), "warm", "vm importedFunctionValue");
		assertInt(runtime.call("game.app", "builtinFunctionValue", [VInt(2)]), 3, "vm builtinFunctionValue");
		assertInt(runtime.call("game.app", "lambdaCapture", [VInt(5), VInt(4)]), 9, "vm lambdaCapture");
		assertInt(runtime.call("game.app", "nestedLambdaCapture", [VInt(4), VInt(3)]), 9, "vm nestedLambdaCapture");
		assertInt(runtime.call("game.state", "heroTagCount", []), 2, "vm heroTagCount");
		assertInt(runtime.call("game.state", "nextScore", [VInt(3)]), 7, "vm nextScore");
		assertVmExecutionResume(runtime);

		var snapshotData = runtime.createSnapshotData();
		var snapshot = runtime.createSnapshot();
		assertInt(runtime.call("game.state", "nextScore", [VInt(2)]), 9, "vm nextScore after mutate");
		runtime.restoreSnapshot(snapshot);
		assertInt(runtime.call("game.state", "nextScore", [VInt(0)]), 7, "vm nextScore after restore");
		expectFailure("vm snapshot schema mismatch", function() {
			runtime.restoreSnapshotData({
				format: snapshotData.format,
				version: snapshotData.version,
				schema: snapshotData.schema + "::changed",
				modules: snapshotData.modules,
			});
		});
	}

	static function assertVmExecutionResume(runtime:novel.script.vm.NvslVm.NvslVmProjectInstance):Void {
		var execution = runtime.beginExecution("game.app", "nestedLambdaCapture", [VInt(4), VInt(3)]);
		var sawNested = false;
		var guard = 0;

		while (!execution.isComplete() && guard < 256) {
			if (execution.frameDepth() > 1) {
				sawNested = true;
			}

			execution.step(1);

			if (sawNested && execution.frameDepth() == 1 && !execution.isComplete()) {
				break;
			}

			guard++;
		}

		if (!sawNested || execution.isComplete()) {
			throw new ScriptError("Expected VM execution snapshot test to pause mid-flight after a nested lambda call.");
		}

		var snapshot = execution.createSnapshot();
		var restoredRuntime = ScriptEngine.loadBytecode(runtime.program);
		var restoredExecution = restoredRuntime.restoreExecutionSnapshot(snapshot);

		assertInt(restoredExecution.run(), 9, "vm nested lambda resumed result");
	}

	static function expectFailure(label:String, run:Void->Void):Void {
		try {
			run();
		} catch (_:ScriptError) {
			return;
		}

		throw new ScriptError("Expected failure for " + label + ".");
	}
}
