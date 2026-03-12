import novel.script.ScriptEngine;
import novel.script.runtime.ScriptHost;
import novel.script.runtime.ScriptValue;
import novel.script.semantics.ScriptType;

class Main {
    static function main() {
        // 1. Define your engine's logic
        var myRenderer = {
            displayBackground: function(id:String) {
                trace("ENGINE RENDERER: Displaying background '" + id + "'");
            }
        };

        // 2. Register the host library dynamically
        // This links the NVSL name "vn.showBg" to your Haxe engine logic
        ScriptHost.registerSimple(
            "vn.showBg",
            [TString], // The script must provide 1 String argument
            TVoid,     // The function returns nothing to the script
            function(args, span) {
                // 'args' contains the ScriptValue values from the script
                var bgId = switch args[0] {
                    case VString(id): id;
                    default: "";
                };
                
                // Call your engine's logic
                myRenderer.displayBackground(bgId);
                
                return VVoid;
            }
        );

        // 3. Load and run a script that uses 'vn.showBg'
        var source = "
module game.scene;

fn start() {
    vn.showBg(\"bg.forest\");
}
        ";

        trace("Starting NVSL runtime...");
        var runtime = ScriptEngine.loadSources([{ sourceName: "main.nvsl", source: source }]);
        runtime.call("game.scene", "start", []);
        trace("Done.");
    }
}
