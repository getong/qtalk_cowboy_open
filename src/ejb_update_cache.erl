-module(ejb_update_cache).

-include("logger.hrl").
-include("ejb_http_server.hrl").

-export([create_ets_table/0,update_online/2,update_10min_pgsql/1,update_1hour_pgsql/1,update_2hour_pgsql/1,update_8hour_pgsql/1]).
-export([update_department_info/1,update_online_status_cache/1,update_vcard_version/1,update_muc_vcard_version/1]).
-export([update_robot_info/1,update_user_rbt/1,user_status/1,get_monitor_info/2,update_version_users/1]).
-export([update_domain_to_url/1,get_qchat_status/1,update_user_profile/1,update_virtual_users/1]).
-export([update_users_info_by_id/1]).

create_ets_table() ->
	iplimit_util:create_ets(),
	catch ets:new(online_status, 	[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(user_status, 		[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(user_info,		[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(rbt_info,			[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(cache_info,		[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(vcard_version,	[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(user_profile,		[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(muc_vcard,		[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(ejabberd_config,	[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(user_version,		[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(user_name,		[named_table, ordered_set, public,{keypos, 1},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(getmsg_limit,		[named_table, ordered_set, public,{keypos, 1},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(access_limit,		[named_table, ordered_set, public,{keypos, 1},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(domain_to_url,	[named_table, ordered_set, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(virtual_users,	[named_table, ordered_set, public,{keypos, 1},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(host_info, [set, named_table, public, {keypos, 1},{write_concurrency, true}, {read_concurrency, true}]),
	catch ets:new(user_rbts, 		[named_table, bag, public,{keypos, 2},{write_concurrency, true}, {read_concurrency, true}]).

%%--------------------------------------------------------------------
%% @date 2015-09
%% 更新用户状态
%%--------------------------------------------------------------------
update_online(Ejabberd_Server,Clear_Flag) ->
	Url = Ejabberd_Server ++ "get_user_status",
	Body = "require=all",
	case catch http_client:post(Url,Body) of
	{ok, _Headers, Res} ->
		case rfc4627:decode(Res) of
		{ok,{obj,Vals},[]} ->
			Users = proplists:get_value("data",Vals),
			case Clear_Flag of
			true ->
				catch ets:delete_all_objects(user_status),
				catch ets:delete_all_objects(online_status);
			false ->
				ok
			end,
			lists:foreach(fun({obj,[{"U",U},{"H",H},{"S",S}]}) ->
					catch ets:insert(user_status,#user_status{user = {U,H},status = S}),
					case S of
					0 ->
						catch ets:delete(online_status,{U,H});
					_ ->
						catch ets:insert(online_status,#online_status{user = {U,H},status = S})
					end	end,Users),
			update_online_status_cache(Clear_Flag);
		%	ets:insert(cache_info,#cache_info{name = <<"online1">>,cache = rfc4627:encode([{obj, [{<<"OnlineUsers">>,Online_users}]}])});
		_ ->
			ok
		end;
	Error ->
		?INFO_MSG("Error ~p ~n",[Error]),
		ok
	end.

update_cache_info_online1(User,Host,add) ->
	case catch ets:lookup(cache_info,str:concat(Host,<<"_online1">>)) of
	[OL1] ->
		case catch lists:member(User,OL1#cache_info.cache) of
		true ->
			ok;
		false ->
			ets:insert(cache_info,OL1#cache_info{cache = [User] ++ OL1#cache_info.cache})	
		end;
	_ ->
		ets:insert(cache_info,#cache_info{name = str:concat(Host,<<"_online1">>),cache = []})
	end;
update_cache_info_online1(User,Host,del) ->
	case catch ets:lookup(cache_info,str:concat(Host,<<"_online1">>)) of
	[OL1] ->
		case catch lists:member(User,OL1#cache_info.cache) of
		true ->
			ets:insert(cache_info,OL1#cache_info{cache =  OL1#cache_info.cache -- [User]});	
		false ->
			ok
		end;
	_ ->
		ok
	end.
			
update_cache_info_online2(User,Host,Status,add) ->
	case catch ets:lookup(cache_info,str:concat(Host,<<"_online2">>)) of
	[OL2] ->
		case catch lists:member({obj, [{"U", User},{"H",Host},{"S",Status}]},OL2#cache_info.cache) of
		true ->
			ok;
		false ->
			ets:insert(cache_info,OL2#cache_info{cache = [{obj, [{"U", User},{"H",Host},{"S",Status}]}] ++ OL2#cache_info.cache})	
		end;
	_ ->
		ets:insert(cache_info,#cache_info{name = str:concat(Host,<<"_online2">>),cache = []})
	end;
update_cache_info_online2(User,Host,Status,del) ->
	case catch ets:lookup(cache_info,str:concat(Host,<<"_online2">>)) of
	[OL2] ->
		case catch lists:member({obj, [{"U", User},{"H",Host},{"S",Status}]},OL2#cache_info.cache) of
		true ->
			ets:insert(cache_info,OL2#cache_info{cache =  OL2#cache_info.cache -- [{obj, [{"U", User},{"H",Host},{"S",Status}]}]});	
		false ->
			ok
		end;
	_ ->
		ok
	end.
		
update_10min_pgsql(Host) ->
	ok.

update_1hour_pgsql(Host) ->
	ok.

update_2hour_pgsql(Host) ->
	ok.

update_8hour_pgsql(Host) ->
	ok.

%%--------------------------------------------------------------------
%% @date 2015-08
%% 更新部门信息
%%--------------------------------------------------------------------
update_department_info(Flag) ->
	case catch    pg_odbc:sql_query(<<"ejb_http_server">>, [<<"select id,host from host_info;">>]) of
	{selected,_,Res1} when is_list(Res1) ->
        	catch ets:delete_all_objects(host_info),
	        lists:foreach(fun([HID,Host]) ->
        	        catch ets:insert(host_info,{HID,Host}) end,Res1);
	_ ->
                ok
        end,

    case ejb_cache:get_host() of
    <<"ejabhost1">> ->
    	case catch ejb_odbc_query:get_department_info() of
	    {selected,_,Res} when is_list(Res) ->
	    	Info =
	    		lists:map(fun([_,_,_D1,_D2,_D3,_D4,_D5,J,N,D,_Fp]) ->
	    			{obj, [{"U", J}, {"D", D},{"N",N},{"S",0}]}
	    		  	end,Res),
%		handle_abbreviate(Res,Flag),
	    	update_user_name(Res,Flag),
    		Department_Json = rfc4627:encode(Info),
		    handle_department:make_tree_dept(Res,Flag),
		    handle_department:get_dept_json(Flag),
    		case Flag of
	    	true ->
	    		catch ets:delete(cache_info,<<"list_depts">>);
    		_ ->
    			ok
    		end,
    		ets:insert(cache_info,#cache_info{name = <<"list_depts">>,cache = Department_Json}),
    		update_users_info(Flag);
    	_ ->
	    	ok
	    end;
    _ ->
    	case catch ejb_odbc_query:get_department_info1() of
	    {selected,_,Res} when is_list(Res) ->
	    	Info =
	    		lists:map(fun([_,_D1,_D2,_D3,_D4,_D5,J,N,D,_Fp]) ->
	    			{obj, [{"U", J}, {"D", D},{"N",N},{"S",0}]}
	    		  	end,Res),
	    	update_user_name(Res,Flag),
    		Department_Json = rfc4627:encode(Info),
		    handle_department:make_tree_dept(Res,Flag),
		    handle_department:get_dept_json(Flag),
    		case Flag of
	    	true ->
	    		catch ets:delete(cache_info,<<"list_depts">>);
    		_ ->
    			ok
    		end,
    		ets:insert(cache_info,#cache_info{name = <<"list_depts">>,cache = Department_Json}),
    		update_users_info(Flag);
    	_ ->
	    	ok
	    end
    end .
        

update_sub_department_info(HID) ->
    case ejb_cache:get_host() of
    <<"ejabhost1">> ->
	    ok;
    _ ->
    	case catch ejb_odbc_query:get_department_info1_by_id(HID) of
	    {selected,_,Res} when is_list(Res) ->
	    	Info =
	    		lists:map(fun([_,_D1,_D2,_D3,_D4,_D5,J,N,D,_Fp]) ->
	    			{obj, [{"U", J}, {"D", D},{"N",N},{"S",0}]}
	    		  	end,Res),
	    	update_user_name(Res,false),
    		Department_Json = rfc4627:encode(Info),
		    handle_department:make_tree_dept(Res,false),
		    handle_department:get_dept_json(false),
%    		ets:insert(cache_info,#cache_info{name = <<"list_depts">>,cache = Department_Json}),
    		update_users_info_by_id(false);
    	_ ->
	    	ok
	    end
    end.

update_users_info(Flag) ->
	case catch pg_odbc:sql_query(<<"ejb_http_server">>,
		[<<"select distinct(host_id) from host_users;">>]) of
	{selected,_,L} when is_list(L) ->
		lists:foreach(fun([I]) ->
			case catch pg_odbc:sql_query(<<"ejb_http_server">>,
				[<<"select host_id,dep1,dep2,dep3,dep4,dep5,user_id,user_name,department,pinyin from host_users 
					where  hire_flag = '1' and host_id = '">>,I,<<"' order by dep1,dep2,dep3,dep4,dep5;">>]) of
			{selected,_,Res} when is_list(Res) ->
				Info =
        		                lists:map(fun([_,_D1,_D2,_D3,_D4,_D5,J,N,D,_Fp]) ->
                                	{obj, [{"U", J}, {"D", D},{"N",N},{"S",0}]}
	                                end,Res),
				Department_Json = rfc4627:encode(Info),
				case Flag of
				true ->
					catch ets:delete(cache_info,str:concat(I,<<"_dep">>));
				_ ->
					ok
				end,
				ets:insert(cache_info,#cache_info{name = str:concat(I,<<"_dep">>),cache = Department_Json});
			_ ->
				ok
			end end,L);
	_ ->
		ok
	end.
		


update_users_info_by_id(HID) ->
    case catch pg_odbc:sql_query(<<"ejb_http_server">>,
        [<<"select host_id,dep1,dep2,dep3,dep4,dep5,user_id,user_name,department,pinyin from host_users 
                   where  hire_flag = '1' and host_id = '">>,HID,<<"' order by dep1,dep2,dep3,dep4,dep5;">>]) of
         {selected,_,Res} when is_list(Res) ->
               Info =
                                lists:map(fun([_,_D1,_D2,_D3,_D4,_D5,J,N,D,_Fp]) ->
                                    {obj, [{"U", J}, {"D", D},{"N",N},{"S",0}]}
                                    end,Res),
                Department_Json = rfc4627:encode(Info),
                catch ets:delete(cache_info,str:concat(HID,<<"_dep">>)),
                ets:insert(cache_info,#cache_info{name = str:concat(HID,<<"_dep">>),cache = Department_Json});
            _ ->
                ok
           end .
			
%%--------------------------------------------------------------------
%% @date 2015-08
%% 处理缩写
%%--------------------------------------------------------------------
handle_abbreviate(Res,Flag) ->
	Abbreviates = 
		lists:map(fun([_,_,_D1,_D2,_D3,_D4,_D5,J,N,D,Fp]) ->
			{SF1,SF2} = spilt_abbreviate(binary_to_list(Fp)),
            {obj, [{"U", J}, {"FPY", list_to_binary(SF1)},{"FSX",list_to_binary(SF2)},
				    {"SPY",list_to_binary(SF1)},{"SSX",list_to_binary(SF2)}]} end,Res),
	case Flag of 
	true ->
		ets:delete(cache_info,<<"abbreviates">>);
	false ->
		ok
	end,
	catch ets:insert(cache_info,#cache_info{name = <<"abbreviates">>,cache = rfc4627:encode(Abbreviates)}).


spilt_abbreviate(Pinyin) ->
	Abbreviates = string:tokens(Pinyin,"|"),
	case length(Abbreviates) of
	0 ->
		{[],[]};
	1 ->
		[P] = Abbreviates,
		{P,[]};
	N when N rem 2 == 0 ->
		Abbreviate1 = 
			lists:foldl(fun(Num,Acc) -> 
				case Num rem 2 of 
				1 ->
					case Acc of
					[] ->
						[lists:nth(Num,Abbreviates)];
					_ ->
						Acc ++ "|" ++  [lists:nth(Num,Abbreviates)]
					end;
				_ ->
					Acc
				end end,[],lists:seq(1,N)),
		Abbreviate2 = 
			lists:foldl(fun(Num,Acc) -> 
				case Num rem 2 of 
				0 ->
					case Acc of
					[] ->
						[lists:nth(Num,Abbreviates)];
					_ ->
						Acc ++ "|" ++  [lists:nth(Num,Abbreviates)]
					end;
				_ ->
					Acc
				end end,[],lists:seq(1,N)),
		{Abbreviate1,Abbreviate2};
	_ ->
		{[],[]}
	end.
%%--------------------------------------------------------------------
%% @date 2016-01
%% 更新用户昵称
%%--------------------------------------------------------------------

update_user_name(Res,Flag) ->
	case Flag of
	true ->
		catch ets:delete_all_objects(user_name);
	_ ->
		ok
	end,
    case ejb_cache:get_host() of
    <<"ejabhost1">> ->
    	lists:foreach(fun([Hid,_,_D1,_D2,_D3,_D4,_D5,J,N,D,_Fp]) ->
			case catch ets:lookup(host_info,Hid) of
			[{_,H}] ->
				catch ets:insert(user_name,{{J,H},N});
			_ ->
				catch ets:insert(user_name,{{J,ejb_cache:get_host()},N})
			end end,Res);
    _ ->
    	lists:foreach(fun([Hid,_D1,_D2,_D3,_D4,_D5,J,N,D,_Fp]) ->
			case catch ets:lookup(host_info,Hid) of
			[{_,H}] ->
				catch ets:insert(user_name,{{J,H},N});
			_ ->
				catch ets:insert(user_name,{{J,ejb_cache:get_host()},N})
			end end,Res)
    end.

				
%%--------------------------------------------------------------------
%% @date 2015-08
%% 更新用户状态内存
%%--------------------------------------------------------------------
update_online_status_cache(Flag) ->
	lists:foreach(fun(U) ->
		case U#user_status.status of
		0 ->
			{User,Host} = U#user_status.user,
			update_cache_info_online1(User,Host,del),
			update_cache_info_online2(User,Host,U#user_status.status,del);
		_ ->
			{User,Host} = U#user_status.user,
			update_cache_info_online1(User,Host,add),
			update_cache_info_online2(User,Host,U#user_status.status,add)
		end end,ets:tab2list(user_status)).
%	Res =
%		case Online2 of
%		[] ->
%			{obj,[{"data",[]}]};
%		_ ->
%			{obj,[{"data",Online2}]}
%		end,
%	case Flag of 
%	true ->
%		ets:delete(cache_info,<<"online2">>);
%	false ->
%		ok
%	end,
%	ets:insert(cache_info,#cache_info{name = <<"online2">>,cache = rfc4627:encode(Res)}).
%

%%--------------------------------------------------------------------
%% @date 2015-08
%% 更新个人版本号信息
%%--------------------------------------------------------------------
update_vcard_version(Flag) ->
	case catch ejb_odbc_query:get_vcard_version() of
	{selected,_,Res} when is_list(Res) ->
		case Flag of 
		true -> ets:delete_all_objects(vcard_version);
		false -> ok end,
		lists:foreach(fun([User,Host,Ver,Url,Gender]) ->
                        DefaultUrl = ejb_http_server_env:get_env(ejb_http_server,default_avatar, <<"">>), 
			case ets:lookup(user_name,{User,Host}) of
			[{_,N}] when N =/= undefined  ->
				catch ets:insert(vcard_version,#vcard_version{user = {User,Host},version = Ver, name = N,gender = Gender,
						url = ejb_public:get_default_vcard(Url,DefaultUrl)});
			_ ->
				catch ets:insert(vcard_version,#vcard_version{user = {User,Host},version = Ver, name = <<"">>, gender = Gender,
						url = ejb_public:get_default_vcard(Url,DefaultUrl)})
			end  end,Res);
    %    update_users_not_exist_vcard_version();
	_ ->
		ok
	end.
			
%%--------------------------------------------------------------------
%% @date 2015-08
%% 获取用户个人资料(除头像)
%%--------------------------------------------------------------------
update_user_profile(Flag) ->
	case catch ejb_odbc_query:get_user_profile() of
	{selected,_,Res} when is_list(Res) ->
		case Flag of 
		true -> ets:delete_all_objects(user_profile);
		false -> ok end,
		lists:foreach(fun([User,Host,Ver,Mood]) ->
			ets:insert(user_profile,#user_profile{user = {User,Host},version = Ver, mood = Mood}) end,Res);
	_ ->
		ok
	end.
%%--------------------------------------------------------------------
%% @date 2015-08
%% 更新聊天室版本号信息
%%--------------------------------------------------------------------
update_muc_vcard_version(Flag) ->
	case catch ejb_odbc_query:get_muc_vcard_version() of
	{selected,_,Res} when is_list(Res) ->
		case Flag of 
		true -> ets:delete_all_objects(muc_vcard);
		false -> ok end,
		lists:foreach(fun([M,N,D,T,P,V]) ->
			ets:insert(muc_vcard,#muc_vcard{muc_name = M,show_name = N,muc_desc = D,muc_title = T,
				muc_pic = ejb_public:get_default_vcard(P,<<"file/v2/download/perm/bc0fca9b398a0e4a1f981a21e7425c7a.png">>),version = V}) end,Res);
	_ ->
		ok
	end.

%%--------------------------------------------------------------------
%% @date 2015-08
%% 更新机器人信息
%%--------------------------------------------------------------------
update_robot_info(Flag) ->
	case catch ejb_odbc_query:get_rbt_info() of	
	{selected,_,Res} when is_list(Res) ->
		case Flag of 
		true -> ets:delete_all_objects(rbt_info);
		false -> ok end,
		lists:foreach(fun([N,U,B,V]) ->
			ets:insert(rbt_info,#rbt_info{name = N,url = U ,body = B,version = V}) end,Res);
		_ ->
			ok
	end.

%%--------------------------------------------------------------------
%% @date 2015-08
%% 更新用户机器人列表
%%--------------------------------------------------------------------
update_user_rbt(Flag) ->
	case catch ejb_odbc_query:get_user_rbt() of
	{selected,_,Res} when is_list(Res) ->
		case Flag of 
		true -> ets:delete_all_objects(user_rbts);
		false -> ok end,
		lists:foreach(fun([U,Uh,R,Rh]) ->
			catch ets:insert(user_rbts,#user_rbts{user = {U,Uh},rbt = {R,Rh}}) end,Res);
	_ ->
		ok
	end.

%%--------------------------------------------------------------------
%% @date 2015-08
%% 获取用户状态
%%--------------------------------------------------------------------
user_status(U) ->
	case ets:lookup(user_status,U) of
	[Us] when is_record(Us,user_status) ->
		Us#user_status.status;
	_ ->
		0
	end.

%%--------------------------------------------------------------------
%% @date 2016-01
%% 获取用户状态
%%--------------------------------------------------------------------
get_qchat_status(U) ->
	case ets:lookup(user_status,U) of
	[Us] when is_record(Us,user_status) ->
		case Us#user_status.status of
		1 ->
			<<"away">>;
		6 ->
			<<"online">>;
		_ ->
			<<"offline">>
		end;
	_ ->
		<<"offline">>
	end.

get_monitor_info(Ejabberd_Server,_Flag) ->
	Url = Ejabberd_Server ++ "qmonitor.jsp",
	ets:delete(cache_info,<<"monitor_info">>),
	case http_client:get(Url) of
	{ok,_,Ret } ->
		ejb_monitor:add_ejb_http_monitor(Ret);
	_ ->
		ejb_monitor:add_ejb_http_monitor(<<"">>)
	end.

update_version_users(Flag) ->
    case catch pg_odbc:sql_query(<<"ejb_http_server">>,
	[<<"select user_id,host_id,user_name,department,pinyin,version,hire_flag from host_users; ">>]) of
		{selected, _ , SRes} when is_list(SRes) ->
			case Flag of 
			true -> ets:delete_all_objects(user_version);
			false -> ok end,
			lists:foreach(fun([U,HI,N,D,Fp,V,H]) ->
				Host = 
					case catch ets:lookup(host_info,HI) of
					[{_,DH}] ->
						DH;
					_ ->
						ejb_cache:get_host()
					end,		
				
				ets:insert(user_version,#user_version{user = {U,Host},name = N,version = http_utils:to_integer(V),
				hire_flag = http_utils:to_integer(H),fp = get_pinyin(Fp),sp = get_pinyin(Fp),type = <<"u">>,dept = D}) end,SRes);
        _ ->
		        ok
	end.

update_domain_to_url(Flag) ->
	case catch pg_odbc:sql_query(<<"ejb_http_server">>,
		[<<"select domain,url from domain_mapped_url;">>]) of
	{selected, _ , SRes} when is_list(SRes) ->
		case Flag of 
		true ->
			ets:delete_all_objects(domain_to_url);
		false ->
			ok
		end,
		lists:foreach(fun([D,U]) ->
			ets:insert(domain_to_url,#domain_to_url{domain = D,url = binary_to_list(U)}) end,SRes);
	_ ->
		ok
	end.



update_users_not_exist_vcard_version() ->
    case catch pg_odbc:sql_query(<<"ejb_http_server">>,
        [<<"select username,name from users where username not in (select username from vcard_version)">>]) of
    {selected, _ , SRes} when is_list(SRes) ->
        lists:foreach(fun([User,N]) ->
             catch ets:insert(vcard_version,#vcard_version{user = User,version = <<"2">>, name = N,gender = <<"0">>,
                     url = <<"file/v2/download/perm/ff1a003aa731b0d4e2dd3d39687c8a54.png">>})
            end,SRes);
    _ ->
        ok
    end.

update_virtual_users(Flag) ->
    case catch pg_odbc:sql_query(<<"ejb_http_server">>,
        [<<"select virtual_user,real_user from virtual_user_list where on_duty_flag = '1';">>]) of
    {selected, _ , SRes} when is_list(SRes) ->
         case Flag of 
         true ->
            ets:delete_all_objects(virtual_users);
         _ ->
            ok
         end,
         lists:foreach(fun([V,R]) ->
            catch ets:insert(virtual_users,{<<V/binary,<<"_">>/binary,R/binary>>,1}) end,SRes);
    _ ->
        ok
    end.
            

rpc_send_update_presence(HID) ->
    case catch  ejb_cache:get_random_node() of
    N when is_atom(N) ->
        case ets:lookup(host_info,HID) of
        [{HID,Node}]  ->
            case catch pg_odbc:sql_query(<<"ejb_http_server">>, 
                [<<"select user_id from host_users  where host_id = '">>,HID,<<"'">>]) of
            {selected, _ , SRes} when is_list(SRes) ->
                lists:foreach(fun(U) -> 
                  case catch  spawn(rpc, call, [ejabberd_rpc_presence, send_notify_presence,[HID]]) of
                    {badrpc,Reason} ->
                        {error,Reason};
                    V ->
                         V
                end end,SRes);
            _ ->
                {error,<<"no found user">>}
            end;
        _ ->
            {error,<<"no found host">>}
        end;
    _ ->
       {error,<<"no found node">>}
    end.     


get_pinyin(null) ->
    <<"">>;
get_pinyin(Pinyin) when is_binary(Pinyin) ->
    Pinyin;
get_pinyin(_) ->
    <<"">>.
