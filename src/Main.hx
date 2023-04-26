package;

import haxe.ui.Toolkit;
import haxe.ui.components.Button;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.macros.ComponentMacros;
import js.Browser;
import js.html.URLSearchParams;

class Main {
	public static var _mainDebug:Bool = false;
	public static var PARAMS:URLSearchParams;
    public static function main() 
	{
		PARAMS = new URLSearchParams(Browser.location.search);
		var app = new App();
    }
}
