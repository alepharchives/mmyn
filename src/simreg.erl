%% @author author <author@example.com>
%% @copyright YYYY author.

%% @doc TEMPLATE.

-module(simreg).
-include("simreg.hrl").

-author('author <author@example.com>').

-behaviour(application).
-behaviour(supervisor).


-export([start/0, start/2, start_link/0, 
        status/0, stop/0, stop/1]).

-export([init/1]).

%% @spec start() -> ok
%% @doc Start the simreg server.
start() ->
    application:start(simreg, temporary).

start(_Type, _StartArgs) ->
   start_link(). 

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

status() ->
    simreg_manager:status().

%% @spec stop() -> ok
%% @doc Stop the simreg server.
stop() ->
    case whereis(simreg) of
        undefined -> ok;
        Pid -> exit(Pid, shutdown)
    end,
    application:stop(simreg).

stop(_State) ->
    ok.


init([]) ->

    RxSup = {simreg_rx_sup,
        {simreg_rx_sup, start_link, []},
        permanent, infinity, supervisor, [simreg_rx_sup]},

    Tx = {simreg_tx, 
        {simreg_tx, start_link, []},
        permanent, 5000, worker, [simreg_tx]},

    Nanny = {nanny,
        {nanny, start_link, []},
        permanent, 5000, worker, [nanny]},

    Webservice = {simreg_misultin,
        {simreg_misultin, start_link, ["0.0.0.0", 11581, 30]},
        permanent, 5000, worker, [simreg_misultin]},

    Processes = [RxSup, Tx, Nanny, Webservice],

    {ok, {{one_for_one, 10, 10}, Processes}}.
