-module(rebarctl).
-export([txqping/1, txstat/1, rxstat/1]).

txqping([]) ->
    {reply, txq:ping()}.

txstat([]) ->
    {reply, tx_sup:ping()}.

rxstat([]) ->
    {reply, rx_sup:ping()}.
