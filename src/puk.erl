-module(puk).
-export([get/1]).

-include("simreg.hrl").

get(Msisdn) ->
    Auth = string:concat("Basic ", base64:encode_to_string("eaitest:1eaitest")),
    Req0 = "<soapenv:Envelope 
                xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" 
                xmlns:ws=\"http://mtnn/eai/sv/ws\" 
                xmlns:get=\"http://eai.mtn.ng/sv/getprodinstdetails\"> 
                    <soapenv:Header> 
                        <ws:Header><get:Header></get:Header> </ws:Header> 
                   </soapenv:Header> 
                   <soapenv:Body> 
                        <ws:clientRequest>
                            <get:GetProdInstDetailsRequest> 
                                <get:MSISDN>",
    Req1 = string:concat(Req0, Msisdn),
    
    Req2 = string:concat(Req1, "</get:MSISDN> 
                            </get:GetProdInstDetailsRequest> 
                        </ws:clientRequest> 
                    </soapenv:Body> 
                </soapenv:Envelope>"),

    {ok, "200", _Headers, Body} = ibrowse:send_req(
            "http://10.1.230.100:5003/IS/MTNN/OSB/SV/ProxyServices/GetProdInstDetailsPS", [
            {"Accept-Encoding", "identity"},
            {"Soapaction", ""},
            {"User-Agent", "Mmayen/1.0"},
            {"Authorization", Auth}, 
            {"Content-Type", "text/xml"}],
            post, 
            Req2),
    parse(Body).

parse(Xml) when is_list(Xml) ->
    {ok, Response, _Tail} = erlsom:parse_sax(list_to_binary(Xml), #soap_response{}, fun process/2),
    Response.



process(endDocument, Res) ->
    Res#soap_response{flag=undefined};
process({characters, X}, #soap_response{flag='STATUS'}=Res) ->
    Rc = list_to_integer(X),
    Res#soap_response{status=Rc, flag=undefined};
process({characters, X}, #soap_response{flag='ERRMSG'}=Res) ->
    Res#soap_response{message=X, flag=undefined};
process({characters, "SIM Card"}, #soap_response{flag='EQUIPMENT'}=Res) ->
    Res#soap_response{flag='READ_PUK'};
process({characters, X}, #soap_response{flag='PUK'}=Res) ->
    Res#soap_response{puk=X, flag=undefined};
process({startElement, _, "returnCode", "get", _}, Res) ->
    Res#soap_response{flag='STATUS'};
process({startElement, _, "codeDescription", "get", _}, Res) ->
    Res#soap_response{flag='ERRMSG'};
process({startElement, _, "EQUIPMENT_TYPE_NAME", "get", _}, Res) ->
    Res#soap_response{flag='EQUIPMENT'};
process({startElement, _, "PUK", "get", _}, #soap_response{flag='READ_PUK'}=Res) ->
    Res#soap_response{flag='PUK'};
process(_, Accm) ->
    Accm.
