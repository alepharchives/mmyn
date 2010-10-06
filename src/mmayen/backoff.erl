-module(backoff).
-behaviour(gen_server).
-export([init/1,handle_call/3,handle_cast/2,
        handle_info/2,terminate/2,code_change/3]).

-export([start_link/0, status/0, stop/0]).

-export([register/4, deregister/0, regular/0, 
		regular/4, increment/0, increment/4]).

-record(st, {tbl}).
-record(spec, {pid, max, min, dlta, mfa, tref, cur, cur_dlta}).


start_link() ->
    timer:start(),
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

status() ->
    gen_server:call(?MODULE, status).

stop() ->
    gen_server:call(?MODULE, stop).

register(Min, Max, Delta, Mfa) ->
    gen_server:call(?MODULE, {register, #spec{pid=self(), max=Max, min=Min, dlta=Delta, mfa=Mfa}}).

regular(Min, Max, Delta, Mfa) ->
	case regular() of
		{error, not_registered} ->
			register(Min, Max, Delta, Mfa);
		Other ->
			Other
	end.

increment(Min, Max, Delta, Mfa) ->
	case increment() of
		{error, not_registered} ->
			register(Min, Max, Delta, Mfa);
		Other ->
			Other
	end.

deregister() ->
    try gen_server:call(?MODULE, {deregister, self()}) 
    catch 
        exit: {noproc, {gen_server, call, [?MODULE, {deregister, _Pid}]}} -> 
            ok;
        exit: {shutdown, {gen_server, call, [?MODULE, {deregister, _Pid}]}} -> 
            ok
    end.

regular() ->
    gen_server:call(?MODULE, {regular, self()}).

increment() ->
    gen_server:call(?MODULE, {increment, self()}).


init([]) ->
    Tbl = ets:new(?MODULE, [set, private, {keypos, 2}]), 
	error_logger:info_msg("~p started~n", [?MODULE]), 
	{ok, #st{tbl=Tbl}}.

handle_call({register, #spec{pid=Pid}=S}, _F, #st{tbl=Tbl}=St) ->
    error_logger:info_msg("Recieved registration request from ~p~n", [Pid]),
	case Res = backoff(Tbl, S, fun backoff/1) of
		ok ->
			erlang:monitor(process, Pid);
		{error, _} ->
			ok
	end,
    {reply, Res, St};


handle_call({deregister, Pid}, _F, #st{tbl=Tbl}=St) ->
    error_logger:info_msg("Recieved de-registration request from ~p~n", [Pid]),
    {reply, deregister(Tbl, Pid), St};

handle_call({regular, Pid}, _F, #st{tbl=Tbl}=St) ->
    {reply, backoff(Tbl, Pid, fun backoff_normal/1), St};


handle_call({increment, Pid}, _F, #st{tbl=Tbl}=St) ->
    {reply, backoff(Tbl, Pid, fun backoff_grow/1), St};

handle_call(status, _F, St) ->
    {reply, {ok, alive}, St};

handle_call(stop, _F, St) ->
    {stop, normal, ok, St};

handle_call(R, _F, St) ->
    {reply, {error, {illegal_request, R}}, St}.


handle_cast(_R, St) ->
    {noreply, St}.

handle_info({'DOWN', _, process, Pid, Reason}, #st{tbl=Tbl}=St) ->
	error_logger:info_msg("Received 'DOWN' message for process ~p. Reason: ~p~n", [Pid, Reason]),
	deregister(Tbl, Pid),
	{noreply, St};

handle_info(_R, St) ->
    {noreply, St}.


terminate(_R, _St) ->
    ok.


code_change(_OldVsn, St, _Extra) ->
    {ok, St}.


backoff(#spec{cur=undefined, dlta=D, min=N}=S) ->
    backoff(S#spec{cur=N, cur_dlta=D});


backoff(#spec{cur=N, tref=undefined, mfa={M, F, A}}=S) ->
    case timer:apply_after(N, M, F, A) of
        {ok, TRef} -> 
            {ok, S#spec{tref=TRef}};
        {error, Reason} ->
            {error, Reason}
    end;

backoff(#spec{tref=TRef}=S) ->
    timer:cancel(TRef),
    backoff(S#spec{tref=undefined}).



backoff_grow(#spec{cur=C, cur_dlta=D0, max=Max}=S) ->
    D = D0*2,
    case C + D of
        N when N < Max ->
            backoff(S#spec{cur=N, cur_dlta=D});
        _ ->
            backoff(S#spec{cur=Max})
    end.

backoff_normal(#spec{min=Min, dlta=Delta}=S) ->
    backoff(S#spec{cur=Min, cur_dlta=Delta}).


backoff(Tbl, #spec{}=S0, Fun) ->
    case Fun(S0) of
        {ok, S} -> 
            ets:insert(Tbl, S), 
            ok;
        {error, Reason} ->
            {error, Reason}
    end;

backoff(Tbl, Pid, Fun) ->
    case ets:lookup(Tbl, Pid) of
        [] ->
            {error, not_registered};
        [#spec{}=S] ->
            backoff(Tbl, S, Fun)
    end.

deregister(Tbl, Pid) ->
	ets:delete(Tbl, Pid).
