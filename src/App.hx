package;
import format.csv.Data.Record;
import format.csv.Reader;
import haxe.Json;
import haxe.ui.Toolkit;
import haxe.ui.components.Button;
import haxe.ui.components.Label;
import haxe.ui.components.TextField;
import haxe.ui.containers.TableView;
import haxe.ui.containers.dialogs.MessageBox;
import haxe.ui.events.MouseEvent;
import haxe.ui.events.UIEvent;
import haxe.ui.macros.ComponentMacros;
import js.Browser;
import ldap.Attributes;
//import ldap.Params;
import roles.Actor;
using StringTools;
using array.ArrayUtils;
using Lambda;

/**
 * ...
 * @author bb
 */
class App extends AppBase
{
	static public inline var NEW_LINE:String = "\r\n";
	static inline var TEAM_HEADER:String = "TEAM";
	static inline var TL_HEADER:String = "Team Leader NT";
	var mainTable:TableView;
	var sep:String;
	static inline var NEW_TEAM_LABEL:String = "** NEW team **";
	static inline var NEW_TL_LABEL:String = "** NEW tl **";

	static var AUTHORIZED_GROUPS:Array<String> = ["Customer Operations - Knowledge - Management","CO Customer Operations Management"];
	static var AUTHORIZED_person:Array<String> = ["dgonzale","dgrzeski", "nmayombo"];
	//static var AUTHORIZED_GROUPS:Array<String> = ["beuha"];
	var team_tl_server_string:String;
	var teamTLURLEncoded:String;
	var data:Array<Dynamic>;
	var DATA_HEADER:String;
	var countOfTeams:Float;
	var teamCount:Label;

	public function new()
	{
		Toolkit.theme = "dark";
		super(TLMail, TLxapi, "team_tl");
		sep = ";";
		DATA_HEADER = '${TEAM_HEADER}${sep}${TL_HEADER}';
		team_tl_server_string = "";
		teamTLURLEncoded = "";
		this.logger.teamTlSignal.add(parseTlList);
		this.logger.manySignal.add(onTLSChecked);
		this.attributes = [
							  Attributes.memberOf,
							  Attributes.sAMAccountName,
							  Attributes.mail
						  ];
		this.whenAppReady = checkIfAllowed;

		init();
		//this.logger.readTeamTl();
		//this.logger.onData = ondata;
		//this.logger.setParameter(TEAM_TL_PARAM, "");

	}

	function checkIfAllowed()
	{
		#if debug
		if (!Main._mainDebug)
		{
			loadContent();
			return;
		}
		#end
		//trace(monitoringData.coach.memberOf);
		for (i in AUTHORIZED_GROUPS)
		{
			//trace(i);
			if (monitoringData.coach.isMember(i))
			{
				loadContent();
				return;
			}
		}

		if (AUTHORIZED_person.indexOf(monitoringData.coach.sAMAccountName)> -1)
		{
			loadContent();
			return;
		}

		var msg:MessageBox = new MessageBox();
		msg.type = MessageBoxType.TYPE_WARNING;
		msg.title = "Access refused";
		msg.message = "You are not authorised to come here.\nIf you think you should, give a shout to qook@salt.ch";
		msg.showDialog();
		return;
	}
	override function loadContent()
	{
		#if debug
		trace("App::loadContent");
		#end

		if (loginApp != null)
		{
			app.removeComponent(loginApp);
		}
		try
		{
			this.mainApp = ComponentMacros.buildComponent("assets/ui/main.xml");
			mainTable =  mainApp.findComponent("teams_tableview", TableView);
			var submitBtn:Button = mainApp.findComponent("submit", Button);
			var doanloadBtn:Button = mainApp.findComponent("download", Button);
			teamCount = mainApp.findComponent("count", Label);
			submitBtn.onClick = updateList;
			doanloadBtn.onClick = downloadList;

			app.addComponent( mainApp );
			this.logger.readTeamTl();

		}
		catch (e)
		{
			trace(e);
		}
	}

	function downloadList(e)
	{
		//trace(mainTable.dataSource.data);
		//trace("data:text/csv;charset=utf-8," + team_tl_server_string);
		Browser.window.open("data:text/csv;charset=utf-8," + team_tl_server_string,"MyName");
	}

	function updateList(e:MouseEvent)
	{

		data = cast(mainTable.dataSource.data, Array<Dynamic>);
		#if debug
		//trace(mainTable.dataSource.data);
		trace("App::updateList::data ", data  );
		#end
		var dataNts:Array<String> = data
									.filter((e)->(return (e.action == "false" && e.tl != NEW_TL_LABEL)))
									.map((e)->(return e.tl))
									.getUnique();

		this.logger.searchMany(dataNts);
	}
	function onTLSChecked(actors:Array<Actor>, errors:Array<String>, leavers:Array<Actor>)
	{
		var errorCount = errors.length + leavers.length;
		teamTLURLEncoded = dataToString(data);
		if (errorCount >0)
		{
			var msg:MessageBox = new MessageBox();
			msg.type = MessageBoxType.TYPE_ERROR;
			msg.title = "Error Rejected TLS";
			msg.message = 'At least $errorCount NT are not found in the Active Directory :$NEW_LINE';
			if(errors.length >0)
				msg.message += errors.join(NEW_LINE);
			if(leavers.length >0)
				msg.message += leavers.map((e)->(e.sAMAccountName)).join(NEW_LINE);

			//teamTLURLEncoded = dataToString(data.filter((e)->(return errors.indexOf(e.tl) == -1)));
			msg.showDialog();

		}
		else
		{
			//this.logger.writeTeamTl(teamTLURLEncoded);

		}
		#if debug
		trace("App::onTLSChecked::this.logger.data", data );
		trace("App::onTLSChecked::this.logger.teamTLURLEncoded", teamTLURLEncoded );
		#end
		if (teamTLURLEncoded == team_tl_server_string)
		{
			var msg:MessageBox = new MessageBox();
			msg.type = MessageBoxType.TYPE_WARNING;
			msg.title = "No change";
			msg.message = 'You did not make any changes.';
			//msg.message += errors.join(NEW_LINE);
			msg.showDialog();
		}
		else
		{
			this.logger.writeTeamTl(teamTLURLEncoded);
			trackChanges(teamTLURLEncoded);
		}
	}

	function trackChanges(str:String)
	{
		cast(this.xapitracker, TLxapi).sendSingleStatement(monitoringData.coach, str, this.versionHelper.getFullVersion());
	}
	function dataToString(table:Array<Dynamic>):String
	{
		var s = DATA_HEADER;
		var action = "";
		var delete = false;
		//table.sort(sortAsc);
		for (i in table)
		{
			action = i.action;

			#if debug
			try
			{
				trace(i);
				trace(Std.string(i.action) == "false", Type.typeof(i.action));
				trace(i.team != NEW_TEAM_LABEL, NEW_TEAM_LABEL);
				trace(i.tl != NEW_TL_LABEL, NEW_TL_LABEL);
			}
			catch (e)
			{
				trace(e);
			}

			#end
			if ((i.action=="false" || i.action==false) && (i.team != NEW_TEAM_LABEL || i.tl != NEW_TL_LABEL))
				s += '${NEW_LINE}${i.team.trim()}${sep}${i.tl.trim()}';
			else
				trace("skiped", i);
		}
		return s.urlEncode();
	}
	/*function ondata(d:String)
	{
		var j:Dynamic = Json.parse(d);
		if (j.teamTl != null)
		{
			team_tl_server_string = cast(j.teamTl, String);
			trace(team_tl_server_string);
			//team_tl_server_string += (NEW_LINE+'${NEW_TEAM_LABEL}${sep}${NEW_TL_LABEL}').urlEncode();
			parseTlList(team_tl_server_string);
		}
		else
		{
			trace(j);
		}

	}*/
	function parseTlList(s:String)
	{
		team_tl_server_string = s;
		var t:Array<Record> = Reader.parseCsv( s.urlDecode(), ";");
		#if debug
		trace("App::parseTlList::t", t );
		#end
		var teamIndex = t[0].indexOf(TEAM_HEADER);
		var tlIndex = t[0].indexOf(TL_HEADER);
		mainTable.dataSource.clear();
		//t.shift();
		//t.sort(sortAsc);
		//for ( i in 1...t.length)
		countOfTeams = t.length -1;
		teamCount.text = Std.string(countOfTeams) + " teams";
		for ( i in 1...t.length)
		{
			//trace(t[i]);
			mainTable.dataSource.add({team:t[i][teamIndex], tl:t[i][tlIndex], action:"false"});
		}
		mainTable.dataSource.add({team:NEW_TEAM_LABEL, tl:NEW_TL_LABEL, action:"false"});
		//trace(t);
		//trace(tlIndex);
		//trace(teamIndex);
		var msg:MessageBox = new MessageBox();
			msg.type = MessageBoxType.TYPE_WARNING;
			msg.title = "Team TL list reloaded";
			msg.message = 'Now there are ${countOfTeams} teams with TLs mapped';
			//msg.message += errors.join(NEW_LINE);
			msg.showDialog();
	}
	function sortAsc(a:Dynamic, b:Dynamic):Int
	{
		return if (a > b)
		{
			1 ;
		}
		else if (a < b)
		{
			-1;
		}
		else 0;
		//function sendReportFunc(e)
	}
	//{
	////#if debug
	////trace("ui.AgentListing::sendReportFunc");
	////#end
	//var encodedUri = "data:text/csv;charset=utf-8,"+ StringTools.urlEncode(Utils.arrayToCsv(Utils.arrayDynamicToArrayArrayString(currentList),";"));
	////#if debug
	////trace('ui.AgentListing::sendReportFunc::encodedUri ${encodedUri}');
	////#end
//
	//Browser.window.open(encodedUri,"MyName");
	//}
}