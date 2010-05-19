-module(simreg_services).
-include("simreg.hrl").
-behaviour(gen_sms_handler).

-define(SMS_SRC, "SimReg").
-define(SMS_ERR_SRC, "SErr").
-define(MSG_SVC_UNAVAIL, "This service is temporarily unavailable. Please try again later").

-export([init/0,handle_sms/5,terminate/2]).
-export([msisdn_strip/2]).

init() ->
    {ok, nil}.

handle_sms(_, _, ["-mmyn#err1" | _], _, St) ->
    {noreply,
        {error, {test, 500, "Test generated error"}},
        St};

handle_sms(_, _, ["-mmyn#err2" | _], _, St) ->
    {reply,
        {"mmynerr", "Test generated error"},
        {error, {test, 500, "Test generated error"}},
        St};

handle_sms(_, _, ["-mmyn#tst" | _], _, St) ->
    {reply,
        {"mmyn", "Tested and working"},
        {ok, {tst, 0}},
    St};

handle_sms(_, "789", ["-mmyn#vsn" | _], _, St) ->
    {reply, 
        {"mmyn", "eng: Mmayen\nvsn: 1.0\nos: Solaris 10"}, 
        {ok, {vsn, 0}}, 
    St};

handle_sms(_, "789", ["help" | _], _, St) ->
    {reply, 
        {?SMS_SRC, "help) Menu\npuk) Get puk\nreg)Get status"},
        {ok, {help, 0}},
    St};


handle_sms(_, "789", ["puk", _PUK | _], _, St) ->
    {ok, Msg} = application:get_env(msg_puk_put),
    {reply,
        {?SMS_SRC, Msg},
        {ok, {pukset, 0}},
    St};

handle_sms(Msisdn, "789", ["puk" | _], _, St) ->
    Res = puk:get(Msisdn),
    sms_response(St, Res);

handle_sms(_, "789", ["reg" , Msisdn0 | _], _, St) ->
    Msisdn1 = msisdn_strip(Msisdn0, 5),
    Msisdn = string:concat("234", Msisdn1),
    get_reg_status(St, Msisdn);

handle_sms(Msisdn, "789", ["reg" | _], _, St) ->
    get_reg_status(St, Msisdn);

handle_sms(Src, Dst, WordList, _, St) ->
    error_logger:info_msg("[~p] Got unhandled SMS. ~p => ~p : ~p~n", [?MODULE, Src, Dst, WordList]),
    {noreply, ok, St}.

terminate(_Reason, _St) ->
    ok.

% Privates

msisdn_strip(<<"+",Rest/binary>>, MinLen) ->
    msisdn_strip(Rest, MinLen);

msisdn_strip(<<"0",Rest/binary>>, MinLen) ->
    msisdn_strip(Rest, MinLen);

msisdn_strip(Msisdn, MinLen) when is_binary(Msisdn), size(Msisdn) < MinLen ->
    binary_to_list(Msisdn);

msisdn_strip(<<"234",Rest/binary>>, MinLen) ->
    msisdn_strip(Rest, MinLen);

msisdn_strip(Msisdn, MinLen) when is_list(Msisdn), is_integer(MinLen) ->
    msisdn_strip(list_to_binary(Msisdn), MinLen);

msisdn_strip(Msisdn, _) ->
    binary_to_list(Msisdn).

get_reg_status(To, Msisdn) ->
    case reg:get(Msisdn) of
        #soap_response{status=0}=R ->
            {ok, Fmt} = application:get_env(msg_reg_get_ok),
            Msg = lists:flatten(io_lib:format(Fmt, [Msisdn])),
            sms_response(To, R#soap_response{message=Msg});
        #soap_response{status=100}=R ->
            {ok, Fmt} = application:get_env(msg_reg_get_fail),
            Msg = lists:flatten(io_lib:format(Fmt, [Msisdn])),
            sms_response(To, R#soap_response{message=Msg});
        R ->
            sms_response(To, R)
    end.

sms_response(St, #soap_response{status=N, message=undefined, op=Op}) ->
    {reply,
        {?SMS_SRC, ?MSG_SVC_UNAVAIL},
        {error, {Op, N, "Unable to get response"}},
    St};

sms_response(St, #soap_response{status=0, message=Msg, op=Op}) ->
    {reply,
        {?SMS_SRC, Msg},
        {ok, {Op, 0}},
    St};

sms_response(St, #soap_response{status=100, op=reg=Op, message=Msg}) ->
    {reply,
        {?SMS_SRC, Msg},
        {ok, {Op, 0}},
    St};

sms_response(St, #soap_response{status=N, message=Msg, op=Op}) ->
    {reply,
        {?SMS_SRC, ?MSG_SVC_UNAVAIL},
        {error, {Op, N, Msg}},
    St}.
