package;

import http.XapiHelper;
import roles.Actor;
import xapi.Activity;
import xapi.Agent;
import xapi.Statement;
import xapi.Verb;
import xapi.activities.Definition;

/**
 * ...
 * @author bb
 */
class TLxapi extends XapiHelper 
{

	public function new(url:String) 
	{
		super(url);
	}
	public function sendSingleStatement(agent:Actor,list:String, scriptVersion:String)
	{
		var def:Definition = new Definition();
		def.extensions.set("http://salt.ch/partners/team_to_tl_list",list);
		def.extensions.set("http://qook.salt.ch/team_tl/version",scriptVersion);
		var activity = new Activity("http://qook.salt.ch/team_tl", def);
		var s:Statement = new Statement(new Agent(agent.mbox,agent.sAMAccountName), Verb.updated,activity , null, null);
		//trace(s);
		sendMany([s]);
	}
	
}