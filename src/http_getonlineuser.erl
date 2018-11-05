%% Feel free to use, reuse and abuse the code in this file.

-module(http_getonlineuser).

-export([init/3]).
-export([handle/2]).
-export([terminate/3]).

-include("logger.hrl").
-include("http_req.hrl").
-include("ejb_http_server.hrl").

init(_Transport, Req, []) ->
	{ok, Req, undefined}.

handle(Req, State) ->
	{Method, Req} = cowboy_req:method(Req),
    catch ejb_monitor:monitor_count(<<"http_get_online_user">>,1),
	case Method of 
	<<"GET">> ->
		{Host,_} =  cowboy_req:host(Req),
		{ok, Req2} = get_echo(Method,Host,Req),
		{ok, Req2, State};
	_ ->
		{ok,Req2} = echo(undefined, Req),
		{ok, Req2, State}
	end.
    	
get_echo(<<"GET">>,Host,Req) ->
	Req_compress = Req#http_req{resp_compress = true},
        {User,_} = cowboy_req:qs_val(<<"u">>, Req),
        {Domain,_} = cowboy_req:qs_val(<<"d">>, Req),
	Rslt =	case http_utils:verify_user_key(Req)  of
		true ->
			get_online_user(ejb_public:remvote_domain_user(User),Domain);
		_ ->
			[]
		end,
	cowboy_req:reply(200, [{<<"content-type">>, <<"text/json; charset=utf-8">>}], Rslt, Req_compress);
get_echo(<<"Get">>,_,Req) ->
	cowboy_req:reply(405, Req).

echo(undefined, Req) ->
    cowboy_req:reply(400, [], <<"Missing parameter.">>, Req);
echo(Echo, Req) ->
    cowboy_req:reply(200, [
			        {<<"content-type">>, <<"text/json; charset=utf-8">>}
	    			    ], Echo, Req).

terminate(_Reason, _Req, _State) ->
	ok.


get_online_user(User,undefined) ->
	Host = ejb_cache:get_host(),
	case catch ets:lookup(cache_info,str:concat(Host,<<"_online1">>)) of
	[OL1] ->
		 rfc4627:encode([{obj, [{<<"OnlineUsers">>,OL1#cache_info.cache}]}]);
	_ ->
		[]
	end;
get_online_user(User,Host) ->
	case catch ets:lookup(cache_info,str:concat(Host,<<"_online1">>)) of
	[OL1] ->
		 rfc4627:encode([{obj, [{<<"OnlineUsers">>,OL1#cache_info.cache}]}]);
	_ ->
		[]
	end.
	
