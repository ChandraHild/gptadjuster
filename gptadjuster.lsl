// User variables, change these as you wish!
// Your OpenAI key, obtained via https://platform.openai.com/account/api-keys
string apikey = "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";

// URL for accessing the API. I highly recommend using a proxy configured to forcibly
// set the return Content-Type to "application/json; charset=utf-8" to work around SL bugs
string api_url = "https://api.openai.com/v1/chat/completions";

// How much message history to keep. Shorter history is less expensive, more
// history lets the AI keep more context!
integer maxhistory = 10;

// Do you want use input to just be the profile's subconscious or
// would you prefer to fully rewrite everything the user enters?
integer subconscious = TRUE;

// Define the AI's profile here! Here's some samples to get you started.
string myname = "Amilia";
string prompt = "Amilia is a flirty maid who speaks with an absurd French accent.";
//string myname = "Alice";
//string prompt = "Alice is from Wonderland.";
//string myname = "Cher";
//string prompt = "Cher is from Clueless.";
//string myname = "Gollum";
//string prompt = "";
//string myname = "Scout";
//string prompt = "Scout is from To Kill a Mockingbird.";
//string myname = "Yoda";
//string prompt = "";
//string prompt = "Elle is Elle Woods.";
//string myname = "Elle";
//string prompt = "Julie is from Valley Girl.";
//string myname = "Julie";
//string prompt = "Juliet is from the novel Romeo and Juliet.";
//string myname = "Juliet";


// System variables
integer processing;
integer ownerchan;
integer last_talker_ai;
key http_request_id;
string idhash;
list history;

ai_say(string message)
{
    string sys = "In under 50 words, behave as " + myname + ".";
    string preprompt = "";
    if (message == "!reset")
    {
        llOwnerSay("Resetting!");
        llResetScript();
    }
    else if (last_talker_ai && llGetTime() < 30)
    {
        llOwnerSay("You may speak again in " + (string)(30-(integer)llGetTime()) + " seconds.");
        return;
    }
    else if (message == "...")
    {
        // Let the AI come up with something entirely on its own
    }
    else if (subconscious)
    {
        preprompt = myname + " just had the following subconscious thought:\\n===" + message + "\\n===\\n\\n";
    }
    else
    {
        sys = "In under 50 words, behave as" + myname + " including a rewrite of:\\n===" + message + "\\n===";
    }
    string strhistory;
    if (llGetListLength(history))
    {
        strhistory = llDumpList2String(history, ",") + ",";
    }
    string premsg = "";
    if (prompt)
    {
        premsg = "{\"role\": \"system\", \"content\": \""+prompt+"\"},";
    }
    processing = TRUE;
    llSetTimerEvent(0);
    string body = llList2Json(JSON_OBJECT, ["model", "gpt-3.5-turbo", "temperature", 0.7, "presence_penalty", 0.1, "frequency_penalty", 0.1, "user", idhash, "messages", "["+premsg+strhistory+"{\"role\": \"system\", \"content\": \""+preprompt+sys+"\"}]"]);

    http_request_id = llHTTPRequest(api_url, [HTTP_METHOD, "POST", HTTP_MIMETYPE, "application/json", HTTP_ACCEPT,"application/json",  HTTP_CUSTOM_HEADER, "Authorization", "Bearer "+apikey], body);
}

default
{
    state_entry()
    {
        ownerchan = (integer)llFrand(500) + 1000;
        idhash = llSHA256String(llGetOwner());
        llListen(0,"",NULL_KEY,"");
        llListen(ownerchan,"",llGetOwner(),"");
        llOwnerSay("@clear,redirchat:"+(string)ownerchan+"=add,rediremote:"+(string)ownerchan+"=add");
        llSetObjectName(myname + "(AI)");

    }

    on_rez(integer start_param)
    {
        llOwnerSay("@clear,redirchat:"+(string)ownerchan+"=add,rediremote:"+(string)ownerchan+"=add");
        llSetObjectName(myname + "(AI)");
    }

    timer()
    {
        if (processing && llGetTime() < 60)
        {
            llSetTimerEvent(15);
            return;
        }
        ai_say("...");
    }

    listen(integer c, string n, key id, string t)
    {
        //if(id != llGetOwnerKey(id)) return;
        if (id == llGetOwnerKey(id))
        {
            n = llGetDisplayName(id);
        }
        t = llReplaceSubString(t, "\\", "\\\\", 0);
        t = llReplaceSubString(t, "\"", "\\\"", 0);
        t = llReplaceSubString(t, "\n", "\\n", 0);
        if (c == 0)
        {
            last_talker_ai = FALSE;
            //llSetTimerEvent(llFrand(15)+15);
            history = history + ["{\"role\": \"user\", \"content\": \""+ n + ": " + t + "\"}"];
            if (llGetListLength(history) > maxhistory)
            {
                history = llListReplaceList(history, [], 0, 1);
            }
        }

        if (c == ownerchan)
        {
            ai_say(t);
            return;
        }
    }

    changed(integer change)
    {
        if (change & CHANGED_OWNER) 
        {
            llResetScript();
        }
    }

    http_response(key request_id, integer status, list metadata, string body)
    {
        if (request_id != http_request_id) return;// exit if unknown
        if (status != 200) 
        {
            llOwnerSay("HTTP error!");
            return;
        }

        string result = llJsonGetValue(body, ["choices", 0, "message", "content"]);
        if (result == JSON_INVALID || result == JSON_NULL)
        {
            llOwnerSay("API error!");
            return;
        }
        last_talker_ai = TRUE;

        processing = FALSE;
        llResetTime();
        llSay(0, result);
        result = llReplaceSubString(result, "\\", "\\\\", 0);
        result = llReplaceSubString(result, "\"", "\\\"", 0);
        result = llReplaceSubString(result, "\n", "\\n", 0);
        history = history + ["{\"role\": \"assistant\", \"content\": \""+ result + "\"}"];
        if (llGetListLength(history) > maxhistory)
        {
            history = llListReplaceList(history, [], 0, 1);
        }
    }
}
