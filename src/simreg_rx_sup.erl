%% @author author <author@example.com>
%% @copyright YYYY author.

%% @doc Supervisor for the simreg application.

-module(simreg_rx_sup).
-author('author <author@example.com>').
-include("simreg.hrl").

-behaviour(supervisor).

%% External exports
-export([start_link/0, upgrade/0, start_child/0, children/0]).

%% supervisor callbacks
-export([init/1]).

%% @spec start_link() -> ServerRet
%% @doc API for starting the supervisor.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% @spec upgrade() -> ok
%% @doc Add processes if necessary.
upgrade() ->
    {ok, {_, Specs}} = init([]),

    Old = sets:from_list(
            [Name || {Name, _, _, _} <- supervisor:which_children(?MODULE)]),
    New = sets:from_list([Name || {Name, _, _, _, _, _} <- Specs]),
    Kill = sets:subtract(Old, New),

    sets:fold(fun (Id, ok) ->
                      supervisor:terminate_child(?MODULE, Id),
                      supervisor:delete_child(?MODULE, Id),
                      ok
              end, ok, Kill),

    [supervisor:start_child(?MODULE, Spec) || Spec <- Specs],
    ok.

start_child() ->
    supervisor:start_child(?MODULE, []).

children() ->
    Children = supervisor:which_children(?MODULE),
    get_pids_from_spec(Children).

get_pids_from_spec(Children) ->
    get_pids_from_spec(Children, []).

get_pids_from_spec([], Accm) ->
    Accm;
get_pids_from_spec([{_, Pid, worker, [simreg_rx]}|Rest], Accm) ->
    get_pids_from_spec(Rest, [Pid|Accm]).

%% @spec init([]) -> SupervisorTree
%% @doc supervisor callback.
init([]) ->

    Rx = {simreg_rx, 
        {simreg_rx, start_link, []},
        permanent, 5000, worker, [simreg_rx]},

    Processes = [Rx],

    {ok, {{simple_one_for_one, 10, 10}, Processes}}.
