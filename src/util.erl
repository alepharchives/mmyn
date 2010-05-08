-module(util).
-export([soap_request/5, sms_response/2, smsc_params/0]).

-include("simreg.hrl").

-define(SMS_SRC, "SimReg").
-define(SMS_ERR_SRC, "SErr").
-define(NOTIFY_MSISDN, "2347062022125").
-define(MSG_SVC_UNAVAIL, "This service is temporarily unavailable. Please try again later").

soap_request(Url, RqHdrs, RqBody, RsFun, Op) ->
    try ibrowse:send_req(Url, RqHdrs, post, RqBody) of
        {ok, "200", _, RsBody} -> 
            S = RsFun(RsBody),
            S#soap_response{op=Op};
        {ok, Status, _, _} -> 
            Msg = "HTTP " ++ Status,
            #soap_response{status=Status, message=Msg, op=Op}
    catch 
        Type:Message ->
            Msg = lists:flatten(iolib:format("~p : ~p", [Type, Message])),
            #soap_response{status=1000, message=Msg, op=Op}
    end.

sms_response(Dest, #soap_response{message=undefined}) ->
    sms:send(?SMS_SRC, Dest, ?MSG_SVC_UNAVAIL),
    sms:send(?SMS_ERR_SRC, ?NOTIFY_MSISDN, "Unable to get response");

sms_response(Dest, #soap_response{status=0, message=Msg}) ->
    sms:send(?SMS_SRC, Dest, Msg);

sms_response(Dest, #soap_response{status=100, op=reg, message=Msg}) ->
    sms:send(?SMS_SRC, Dest, Msg);

sms_response(Dest, #soap_response{status=_N, message=Msg}) ->
    sms:send(?SMS_SRC, Dest, ?MSG_SVC_UNAVAIL),
    sms:send(?SMS_ERR_SRC, ?NOTIFY_MSISDN, Msg);

sms_response(Dest, Msg) ->
    sms:send(?SMS_SRC, Dest, Msg).
    
smsc_params() -> 
    {ok, Host} = application:get_env(smsc_host), 
    {ok, Port} = application:get_env(smsc_port), 
    {ok, SystemId} = application:get_env(smsc_username), 
    {ok, Password} = application:get_env(smsc_password), 
    {Host, Port, SystemId, Password}.

