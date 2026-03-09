package novel.script.bench;

import haxe.Timer;
import novel.script.ScriptEngine;
import novel.script.ScriptError;
import novel.script.project.ScriptProject.ScriptSourceInput;
import novel.script.runtime.ScriptValue;

class ScriptBenchConfig {
	public var modules(default, null):Int;
	public var helpersPerModule(default, null):Int;
	public var phaseIterations(default, null):Int;
	public var runIterations(default, null):Int;
	public var warmupIterations(default, null):Int;
	public var seed(default, null):Int;

	public function new(
		?modules:Int = 8,
		?helpersPerModule:Int = 16,
		?phaseIterations:Int = 20,
		?runIterations:Int = 200,
		?warmupIterations:Int = 3,
		?seed:Int = 7
	) {
		this.modules = normalizeAtLeast(modules, 1);
		this.helpersPerModule = normalizeAtLeast(helpersPerModule, 1);
		this.phaseIterations = normalizeAtLeast(phaseIterations, 1);
		this.runIterations = normalizeAtLeast(runIterations, 1);
		this.warmupIterations = normalizeAtLeast(warmupIterations, 0);
		this.seed = seed;
	}

	static function normalizeAtLeast(value:Int, minimum:Int):Int {
		return value < minimum ? minimum : value;
	}
}

class ScriptBenchPhaseResult {
	public var name(default, null):String;
	public var iterations(default, null):Int;
	public var totalMs(default, null):Float;
	public var averageMs(default, null):Float;
	public var minMs(default, null):Float;
	public var maxMs(default, null):Float;

	public function new(name:String, iterations:Int, totalMs:Float, averageMs:Float, minMs:Float, maxMs:Float) {
		this.name = name;
		this.iterations = iterations;
		this.totalMs = totalMs;
		this.averageMs = averageMs;
		this.minMs = minMs;
		this.maxMs = maxMs;
	}
}

class ScriptBenchDataset {
	public var sources(default, null):Array<ScriptSourceInput>;
	public var sourceFiles(default, null):Int;
	public var sourceLines(default, null):Int;
	public var estimatedCallDepth(default, null):Int;

	public function new(sources:Array<ScriptSourceInput>, sourceFiles:Int, sourceLines:Int, estimatedCallDepth:Int) {
		this.sources = sources;
		this.sourceFiles = sourceFiles;
		this.sourceLines = sourceLines;
		this.estimatedCallDepth = estimatedCallDepth;
	}
}

class ScriptBenchReport {
	public var config(default, null):ScriptBenchConfig;
	public var dataset(default, null):ScriptBenchDataset;
	public var phases(default, null):Array<ScriptBenchPhaseResult>;
	public var astResult(default, null):Int;
	public var vmResult(default, null):Int;

	public function new(
		config:ScriptBenchConfig,
		dataset:ScriptBenchDataset,
		phases:Array<ScriptBenchPhaseResult>,
		astResult:Int,
		vmResult:Int
	) {
		this.config = config;
		this.dataset = dataset;
		this.phases = phases;
		this.astResult = astResult;
		this.vmResult = vmResult;
	}
}

class ScriptBench {
	static var sink:Dynamic;

	public static function run(?config:ScriptBenchConfig):ScriptBenchReport {
		var benchConfig = config == null ? new ScriptBenchConfig() : config;
		var dataset = generateDataset(benchConfig);
		var project = ScriptEngine.parseSources(dataset.sources);
		var info = ScriptEngine.checkProject(project);
		var linked = ScriptEngine.linkProject(project, "bench.app", "main");
		var program = ScriptEngine.compileProject(project, "bench.app", "main");
		var bytecodeJson = ScriptEngine.encodeBytecode(program);
		var astRuntime = ScriptEngine.loadProject(project);
		var vmRuntime = ScriptEngine.loadBytecode(program);

		var astResult = expectInt(astRuntime.call("bench.app", "main", [VInt(benchConfig.seed)]), "AST benchmark result");
		var vmResult = expectInt(vmRuntime.call("bench.app", "main", [VInt(benchConfig.seed)]), "VM benchmark result");

		if (astResult != vmResult) {
			throw new ScriptError("Benchmark validation mismatch: AST returned " + astResult + " but VM returned " + vmResult + ".");
		}

		var phases = [
			measure("parseSources", benchConfig.phaseIterations, benchConfig.warmupIterations, function() {
				return ScriptEngine.parseSources(dataset.sources);
			}),
			measure("checkProject", benchConfig.phaseIterations, benchConfig.warmupIterations, function() {
				return ScriptEngine.checkProject(project);
			}),
			measure("linkProject", benchConfig.phaseIterations, benchConfig.warmupIterations, function() {
				return ScriptEngine.linkProject(project, "bench.app", "main");
			}),
			measure("compileProject", benchConfig.phaseIterations, benchConfig.warmupIterations, function() {
				return ScriptEngine.compileProject(project, "bench.app", "main");
			}),
			measure("encodeBytecode", benchConfig.phaseIterations, benchConfig.warmupIterations, function() {
				return ScriptEngine.encodeBytecode(program);
			}),
			measure("decodeBytecode", benchConfig.phaseIterations, benchConfig.warmupIterations, function() {
				return ScriptEngine.decodeBytecode(bytecodeJson);
			}),
			measure("loadSourceRuntime", benchConfig.phaseIterations, benchConfig.warmupIterations, function() {
				return ScriptEngine.loadProject(project);
			}),
			measure("loadBytecodeRuntime", benchConfig.phaseIterations, benchConfig.warmupIterations, function() {
				return ScriptEngine.loadBytecode(program);
			}),
			measure("astCall", benchConfig.runIterations, benchConfig.warmupIterations, function() {
				return astRuntime.call("bench.app", "main", [VInt(benchConfig.seed)]);
			}),
			measure("astExecutionRun", benchConfig.runIterations, benchConfig.warmupIterations, function() {
				return astRuntime.beginExecution("bench.app", "main", [VInt(benchConfig.seed)]).run();
			}),
			measure("vmCall", benchConfig.runIterations, benchConfig.warmupIterations, function() {
				return vmRuntime.call("bench.app", "main", [VInt(benchConfig.seed)]);
			}),
			measure("vmExecutionRun", benchConfig.runIterations, benchConfig.warmupIterations, function() {
				return vmRuntime.beginExecution("bench.app", "main", [VInt(benchConfig.seed)]).run();
			})
		];

		sink = info;
		sink = linked;

		return new ScriptBenchReport(benchConfig, dataset, phases, astResult, vmResult);
	}

	public static function formatReport(report:ScriptBenchReport):String {
		var lines:Array<String> = [];
		lines.push("NVSL benchmark");
		lines.push("");
		lines.push("Config:");
		lines.push("  modules: " + report.config.modules);
		lines.push("  helpers/module: " + report.config.helpersPerModule);
		lines.push("  phase iterations: " + report.config.phaseIterations);
		lines.push("  runtime iterations: " + report.config.runIterations);
		lines.push("  warmup iterations: " + report.config.warmupIterations);
		lines.push("  seed: " + report.config.seed);
		lines.push("");
		lines.push("Dataset:");
		lines.push("  source files: " + report.dataset.sourceFiles);
		lines.push("  source lines: " + report.dataset.sourceLines);
		lines.push("  estimated call depth: " + report.dataset.estimatedCallDepth);
		lines.push("  validated result: " + report.astResult);
		lines.push("");
		lines.push(padRight("phase", 18) + padLeft("iter", 8) + padLeft("total ms", 14) + padLeft("avg ms", 12) + padLeft("min ms", 12) + padLeft("max ms", 12));
		lines.push(StringTools.rpad("", "=", 76));

		for (phase in report.phases) {
			lines.push(
				padRight(phase.name, 18)
				+ padLeft(Std.string(phase.iterations), 8)
				+ padLeft(formatMs(phase.totalMs), 14)
				+ padLeft(formatMs(phase.averageMs), 12)
				+ padLeft(formatMs(phase.minMs), 12)
				+ padLeft(formatMs(phase.maxMs), 12)
			);
		}

		return lines.join("\n");
	}

	static function measure(name:String, iterations:Int, warmupIterations:Int, fn:Void->Dynamic):ScriptBenchPhaseResult {
		for (_ in 0...warmupIterations) {
			sink = fn();
		}

		var total = 0.0;
		var minValue = 0.0;
		var maxValue = 0.0;

		for (index in 0...iterations) {
			var start = Timer.stamp();
			sink = fn();
			var elapsed = (Timer.stamp() - start) * 1000.0;
			total += elapsed;

			if (index == 0 || elapsed < minValue) {
				minValue = elapsed;
			}

			if (index == 0 || elapsed > maxValue) {
				maxValue = elapsed;
			}
		}

		return new ScriptBenchPhaseResult(name, iterations, total, total / iterations, minValue, maxValue);
	}

	static function generateDataset(config:ScriptBenchConfig):ScriptBenchDataset {
		var sources:Array<ScriptSourceInput> = [];
		var totalLines = 0;

		for (moduleIndex in 0...config.modules) {
			var moduleSource = buildModuleSource(moduleIndex, config.modules, config.helpersPerModule);
			totalLines += countLines(moduleSource);
			sources.push({
				sourceName: "bench/mod" + moduleIndex + ".nvsl",
				source: moduleSource,
			});
		}

		var appSource = buildAppSource(config.modules);
		totalLines += countLines(appSource);
		sources.push({
			sourceName: "bench/app.nvsl",
			source: appSource,
		});

		return new ScriptBenchDataset(
			sources,
			sources.length,
			totalLines,
			config.modules * (config.helpersPerModule + 1)
		);
	}

	static function buildModuleSource(moduleIndex:Int, moduleCount:Int, helpersPerModule:Int):String {
		var moduleName = "bench.mod" + moduleIndex;
		var buf = new StringBuf();
		buf.add("module " + moduleName + ";\n\n");

		if (moduleIndex > 0) {
			buf.add("import bench.mod" + (moduleIndex - 1) + " as prev;\n\n");
		}

		buf.add("let bias: Int = " + (moduleIndex + 1) + ";\n\n");

		for (helperIndex in 0...helpersPerModule) {
			buf.add("fn helper" + helperIndex + "(value: Int) -> Int {\n");
			buf.add("\t" + helperBody(moduleIndex, helperIndex) + "\n");
			buf.add("}\n\n");
		}

		buf.add("fn step(value: Int) -> Int {\n");
		buf.add("\thelper" + (helpersPerModule - 1) + "(value)\n");
		buf.add("}\n");
		return buf.toString();
	}

	static function helperBody(moduleIndex:Int, helperIndex:Int):String {
		if (helperIndex == 0) {
			if (moduleIndex == 0) {
				return "value + bias";
			}

			return "prev.step(value) + bias";
		}

		return "helper" + (helperIndex - 1) + "(value) + " + helperIndex;
	}

	static function buildAppSource(moduleCount:Int):String {
		var targetModule = "bench.mod" + (moduleCount - 1);
		return
'module bench.app;

import ' + targetModule + ' as target;

fn main(seed: Int) -> Int {
	target.step(seed)
}
';
	}

	static function countLines(source:String):Int {
		return source.split("\n").length;
	}

	static function expectInt(value:ScriptValue, label:String):Int {
		return switch value {
			case VInt(number):
				number;
			default:
				throw new ScriptError(label + " must be Int.");
		};
	}

	static function formatMs(value:Float):String {
		return value < 1000.0 ? formatFixed(value, 3) : formatFixed(value / 1000.0, 3) + "s";
	}

	static function formatFixed(value:Float, decimals:Int):String {
		var factor = Math.pow(10, decimals);
		var rounded = Math.round(value * factor) / factor;
		var text = Std.string(rounded);
		var dotIndex = text.indexOf(".");

		if (dotIndex == -1) {
			text += ".";
			dotIndex = text.length - 1;
		}

		var missing = decimals - (text.length - dotIndex - 1);

		for (_ in 0...missing) {
			text += "0";
		}

		return text;
	}

	static function padRight(text:String, width:Int):String {
		return StringTools.rpad(text, " ", width);
	}

	static function padLeft(text:String, width:Int):String {
		return StringTools.lpad(text, " ", width);
	}
}
