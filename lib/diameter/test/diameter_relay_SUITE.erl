%%
%% %CopyrightBegin%
%%
%% SPDX-License-Identifier: Apache-2.0
%%
%% Copyright Ericsson AB 2010-2025. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%

%%
%% Tests of traffic between seven Diameter nodes connected as follows.
%%
%%                                     --- SERVER1.REALM2
%%                                   /
%%                  ---- RELAY.REALM2 ---- SERVER2.REALM2
%%                /        |
%%   CLIENT.REALM1         |
%%                \        |
%%                  ---- RELAY.REALM3 ---- SERVER1.REALM3
%%                                   \
%%                                     --- SERVER2.REALM3
%%

-module(diameter_relay_SUITE).

%% testcases, no common_test dependency
-export([run/0]).

%% common_test wrapping
-export([
         %% Framework functions
         suite/0,
         all/0,
         init_per_suite/1,
         end_per_suite/1,
         init_per_testcase/2,
         end_per_testcase/2,
        
         %% The test cases
         parallel/1
        ]).

%% diameter callbacks
-export([pick_peer/4,
         prepare_request/3,
         prepare_retransmit/3,
         handle_answer/4,
         handle_request/3]).

-include("diameter.hrl").
-include("diameter_gen_base_rfc3588.hrl").

-include("diameter_util.hrl").


%% ===========================================================================

-define(ADDR, {127,0,0,1}).

-define(CLIENT,  "CLIENT.REALM1").
-define(RELAY1,  "RELAY.REALM2").
-define(SERVER1, "SERVER1.REALM2").
-define(SERVER2, "SERVER2.REALM2").
-define(RELAY2,  "RELAY.REALM3").
-define(SERVER3, "SERVER1.REALM3").
-define(SERVER4, "SERVER2.REALM3").

-define(SERVICES, [?CLIENT,
                   ?RELAY1, ?RELAY2,
                   ?SERVER1, ?SERVER2, ?SERVER3, ?SERVER4]).

-define(DICT_COMMON,  ?DIAMETER_DICT_COMMON).
-define(DICT_RELAY,   ?DIAMETER_DICT_RELAY).

-define(APP_ALIAS, the_app).
-define(APP_ID, ?DICT_COMMON:id()).

%% Config for diameter:start_service/2.
-define(SERVICE(Host, Dict),
        [{'Origin-Host', Host},
         {'Origin-Realm', realm(Host)},
         {'Host-IP-Address', [?ADDR]},
         {'Vendor-Id', 12345},
         {'Product-Name', "OTP/diameter"},
         {'Acct-Application-Id', [Dict:id()]},
         {application, [{alias, ?APP_ALIAS},
                        {dictionary, Dict},
                        {module, #diameter_callback{peer_up = false,
                                                    peer_down = false,
                                                    handle_error = false,
                                                    default = ?MODULE}},
                        {answer_errors, callback}]}]).

-define(SUCCESS, 2001).
-define(LOOP_DETECTED, 3005).
-define(UNABLE_TO_DELIVER, 3002).

-define(LOGOUT, ?'DIAMETER_BASE_TERMINATION-CAUSE_LOGOUT').
-define(AUTHORIZE_ONLY, ?'DIAMETER_BASE_RE-AUTH-REQUEST-TYPE_AUTHORIZE_ONLY').

-define(RL(F),    ?RL(F, [])).
-define(RL(F, A), ?LOG("DRELAYS", F, A)).


%% ===========================================================================

suite() ->
    [{timetrap, {seconds, 30}}].

all() ->
    [parallel].


init_per_suite(Config) ->
    ?RL("init_per_suite -> entry with"
        "~n   Config: ~p", [Config]),
    ?DUTIL:init_per_suite(Config).

end_per_suite(Config) ->
    ?RL("end_per_suite -> entry with"
        "~n   Config: ~p", [Config]),
    ?DUTIL:end_per_suite(Config).


%% This test case can take a *long* time, so if the machine is too slow, skip
init_per_testcase(parallel = Case, Config) when is_list(Config) ->
    ?RL("init_per_testcase(~w) -> check factor", [Case]),
    Key = dia_factor,
    case lists:keysearch(Key, 1, Config) of
        {value, {Key, Factor}} when (Factor > 10) ->
            ?RL("init_per_testcase(~w) -> Too slow (~w) => SKIP",
                [Case, Factor]),
            {skip, {machine_too_slow, Factor}};
        _ ->
            ?RL("init_per_testcase(~w) -> run test", [Case]),
            Config
    end;
init_per_testcase(Case, Config) ->
    ?RL("init_per_testcase(~w) -> entry", [Case]),
    Config.


end_per_testcase(Case, Config) when is_list(Config) ->
    ?RL("end_per_testcase(~w) -> entry", [Case]),
    Config.


%% ===========================================================================

parallel(_Config) ->
    ?RL("parallel -> entry"),
    Res = run(),
    ?RL("parallel -> done when"
        "~n   Res: ~p", [Res]),
    Res.


%% ===========================================================================

%% run/0

run() ->
    ok = diameter:start(),
    try
        ?RUN([{fun traffic/0, 20000}])
    after
        ok = diameter:stop()
    end.

%% traffic/0

traffic() ->
    ?RL("traffic -> start services"),
    Servers = start_services(),
    ?RL("traffic -> connect"),
    Conns = connect(Servers),
    ?RL("traffic -> send"),
    [] = send(),
    ?RL("traffic -> check counters"),
    [] = counters(),
    ?RL("traffic -> disconnect"),
    [] = disconnect(Conns),
    ?RL("traffic -> stop services"),
    [] = stop_services(),
    ?RL("traffic -> done"),
    ok.

start_services() ->
    lists:foreach(fun(S) -> ?DEL_REG(S) end, ?SERVICES),
    [S1,S2,S3,S4] = [server(N, ?DICT_COMMON) || N <- [?SERVER1,
                                                      ?SERVER2,
                                                      ?SERVER3,
                                                      ?SERVER4]],
    [R1,R2] = [server(N, ?DICT_RELAY) || N <- [?RELAY1, ?RELAY2]],

    ?RL("server -> try start service ~s", [?CLIENT]),
    ok = diameter:start_service(?CLIENT, ?SERVICE(?CLIENT, ?DICT_COMMON)),

    [{?RELAY1, [S1,S2,R2]}, {?RELAY2, [S3,S4]}, {?CLIENT, [R1,R2]}].

connect(Servers) ->
    lists:flatmap(fun({CN,Ss}) -> connect(CN, Ss) end, Servers).

disconnect(Conns) ->
    [{T,C} || C <- Conns,
              T <- [break(C)],
              T /= ok].

stop_services() ->
    lists:foreach(fun(S) -> ?DEL_UNREG(S) end, lists:reverse(?SERVICES)),
    [{H,T} || H <- ?SERVICES,
              T <- [diameter:stop_service(H)],
              T /= ok].

%% Traffic cases run when services are started and connections
%% established.
send() ->
    ?RUN([[fun(X) ->
                   ?RL("send:fun -> entry with ~w", [X]),
                   traffic(X)
           end, T] || T <- [send1,
                            send2,
                            send3,
                            send4,
                            send_loop,
                            send_timeout_1,
                            send_timeout_2,
                            info]]).


%% ----------------------------------------

break({{CN,CR},{SN,SR}}) ->
    try
        ?DISCONNECT(CN,CR,SN,SR)
    after
        diameter:remove_transport(SN, SR)
    end.

server(Name, Dict) ->
    ?RL("server -> try start service ~s", [Name]),
    ok = diameter:start_service(Name, ?SERVICE(Name, Dict)),
    {Name, ?LISTEN(Name, tcp)}.

connect(Name, Refs) ->
    [{{Name, ?CONNECT(Name, tcp, LRef)}, T} || {_, LRef} = T <- Refs].

%% ===========================================================================
%% traffic testcases

%% Send an STR intended for a specific server and expect success.
traffic(send1) ->
    call(?SERVER1);
traffic(send2) ->
    call(?SERVER2);
traffic(send3) ->
    call(?SERVER3);
traffic(send4) ->
    call(?SERVER4);

%% Send an ASR that loops between the relays (RELAY1 -> RELAY2 ->
%% RELAY1) and expect the loop to be detected.
traffic(send_loop) ->
    Req = ['ASR', {'Destination-Realm', realm(?SERVER1)},
                  {'Destination-Host', ?SERVER1},
                  {'Auth-Application-Id', ?APP_ID}],
    #'diameter_base_answer-message'{'Result-Code' = ?LOOP_DETECTED}
        = call(Req, [{filter, realm}]);

%% Send a RAR that is incorrectly routed and then discarded and expect
%% different results depending on whether or not we or the relay
%% timeout first.
traffic(send_timeout_1) ->
    #'diameter_base_answer-message'{'Result-Code' = ?UNABLE_TO_DELIVER}
        = traffic({timeout, 7000});
traffic(send_timeout_2) ->
    {error, timeout} = traffic({timeout, 3000});

traffic({timeout, Tmo}) ->
    Req = ['RAR', {'Destination-Realm', realm(?SERVER1)},
                  {'Destination-Host', ?SERVER1},
                  {'Auth-Application-Id', ?APP_ID},
                  {'Re-Auth-Request-Type', ?AUTHORIZE_ONLY}],
    call(Req, [{filter, realm}, {timeout, Tmo}]);

traffic(info) ->
    %% Wait for RELAY1 to have answered all requests, so that the
    %% suite doesn't end before all answers are sent and counted.
    receive after 6000 -> ok end,
    [] = ?INFO().

counters() ->
    ?RUN([[fun(XK, XS) ->
                   ?RL("counters:fun -> entry with"
                       "~n   (X)Key: ~w"
                       "~n   (X)Svc: ~p", [XK, XS]),                   
                   counters(XK, XS)
           end,
           K, S]
          || K <- [statistics, transport, connections],
             S <- ?SERVICES]).

counters(Key, Svc) ->
    counters(Key, Svc, [_|_] = diameter:service_info(Svc, Key)).

counters(statistics, Svc, Stats) ->
    stats(Svc, lists:foldl(fun({K,N},D) -> orddict:update_counter(K, N, D) end,
                           orddict:new(),
                           lists:append([L || {P,L} <- Stats, is_pid(P)])));

counters(_, _, _) ->
    todo.

stats(?CLIENT, L) ->
    [{{{0,257,0},recv},2},   %% CEA
     {{{0,257,1},send},2},   %% CER
     {{{0,258,0},recv},1},   %% RAA (send_timeout_1)
     {{{0,258,1},send},2},   %% RAR (send_timeout_[12])
     {{{0,274,0},recv},1},   %% ASA (send_loop)
     {{{0,274,1},send},1},   %% ASR (send_loop)
     {{{0,275,0},recv},4},   %% STA (send[1-4])
     {{{0,275,1},send},4},   %% STR (send[1-4])
     {{{unknown,0},recv,discarded},1},  %% RAR (send_timeout_2)
     {{{0,257,0},recv,{'Result-Code',2001}},2},  %% CEA
     {{{0,258,0},recv,{'Result-Code',3002}},1},  %% RAA (send_timeout_1)
     {{{0,274,0},recv,{'Result-Code',3005}},1},  %% ASA (send_loop)
     {{{0,275,0},recv,{'Result-Code',2001}},4}]  %% STA (send[1-4])
        = L;

stats(S, L)
  when S == ?SERVER1;
       S == ?SERVER2;
       S == ?SERVER3;
       S == ?SERVER4 ->
    [{{{0,257,0},send},1},   %% CEA
     {{{0,257,1},recv},1},   %% CER
     {{{0,275,0},send},1},   %% STA (send[1-4])
     {{{0,275,1},recv},1},   %% STR (send[1-4])
     {{{0,257,0},send,{'Result-Code',2001}},1},  %% CEA
     {{{0,275,0},send,{'Result-Code',2001}},1}]  %% STA (send[1-4])
        = L;

stats(?RELAY1, L) ->
    [{{{relay,0},recv},3},   %% STA x 2 (send[12])
                             %% ASA     (send_loop)
     {{{relay,0},send},6},   %% STA x 2 (send[12])
                             %% ASA x 2 (send_loop)
                             %% RAA x 2 (send_timeout_[12])
     {{{relay,1},recv},6},   %% STR x 2 (send[12])
                             %% ASR x 2 (send_loop)
                             %% RAR x 2 (send_timeout_[12])
     {{{relay,1},send},5},   %% STR x 2 (send[12])
                             %% ASR     (send_loop)
                             %% RAR x 2 (send_timeout_[12])
     {{{0,257,0},recv},3},   %% CEA
     {{{0,257,0},send},1},   %%  "
     {{{0,257,1},recv},1},   %% CER
     {{{0,257,1},send},3},   %%  "
     {{{relay,0},recv,{'Result-Code',2001}},2},  %% STA x 2 (send[34])
     {{{relay,0},recv,{'Result-Code',3005}},1},  %% ASA     (send_loop)
     {{{relay,0},send,{'Result-Code',2001}},2},  %% STA x 2 (send[34])
     {{{relay,0},send,{'Result-Code',3002}},2},  %% RAA     (send_timeout_[12])
     {{{relay,0},send,{'Result-Code',3005}},2},  %% ASA     (send_loop)
     {{{0,257,0},recv,{'Result-Code',2001}},3},  %% CEA
     {{{0,257,0},send,{'Result-Code',2001}},1}]  %%  "
        = L;

stats(?RELAY2, L) ->
    [{{{relay,0},recv},3},   %% STA x 2 (send[34])
                             %% ASA     (send_loop)
     {{{relay,0},send},3},   %% STA x 2 (send[34])
                             %% ASA     (send_loop)
     {{{relay,1},recv},5},   %% STR x 2 (send[34])
                             %% RAR x 2 (send_timeout_[12])
                             %% ASR     (send_loop)
     {{{relay,1},send},3},   %% STR x 2 (send[34])
                             %% ASR     (send_loop)
     {{{0,257,0},recv},2},   %% CEA
     {{{0,257,0},send},2},   %%  "
     {{{0,257,1},recv},2},   %% CER
     {{{0,257,1},send},2},   %%  "
     {{{relay,0},recv,{'Result-Code',2001}},2},  %% STA x 2 (send[34])
     {{{relay,0},recv,{'Result-Code',3005}},1},  %% ASA     (send_loop)
     {{{relay,0},send,{'Result-Code',2001}},2},  %% STA x 2 (send[34])
     {{{relay,0},send,{'Result-Code',3005}},1},  %% ASA     (send_loop)
     {{{0,257,0},recv,{'Result-Code',2001}},2},  %% CEA
     {{{0,257,0},send,{'Result-Code',2001}},2}]  %%  "
        = L.

%% ===========================================================================

realm(Host) ->
    tl(lists:dropwhile(fun(C) -> C /= $. end, Host)).

call(Server) ->
    Realm = realm(Server),
    %% Include some arbitrary AVPs to exercise encode/decode, that
    %% are received back in the STA.
    Avps = [#diameter_avp{code = 111,
                          data = [#diameter_avp{code = 222,
                                                data = <<222:24>>},
                                  #diameter_avp{code = 333,
                                                data = <<333:16>>}]},
            #diameter_avp{code = 444,
                          data = <<444:24>>},
            #diameter_avp{code = 555,
                          data = [#diameter_avp{code = 666,
                                                data = [#diameter_avp
                                                        {code = 777,
                                                         data = <<7>>}]},
                                  #diameter_avp{code = 888,
                                                data = <<8>>},
                                  #diameter_avp{code = 999,
                                                data = <<9>>}]}],

    Req = ['STR', {'Destination-Realm', Realm},
                  {'Destination-Host', [Server]},
                  {'Termination-Cause', ?LOGOUT},
                  {'Auth-Application-Id', ?APP_ID},
                  {'AVP', Avps}],

    #diameter_base_STA{'Result-Code' = ?SUCCESS,
                       'Origin-Host' = Server,
                       'Origin-Realm' = Realm,
                       %% Unknown AVPs can't be decoded as Grouped since
                       %% types aren't known.
                       'AVP' = [#diameter_avp{code = 111},
                                #diameter_avp{code = 444},
                                #diameter_avp{code = 555}]}
        = call(Req, [{filter, realm}]).

call(Req, Opts) ->
    diameter:call(?CLIENT, ?APP_ALIAS, Req, Opts).

set([H|T], Vs) ->
    [H | Vs ++ T].

%% ===========================================================================
%% diameter callbacks

%% pick_peer/4

pick_peer([Peer | _], _, Svc, _State)
  when Svc == ?RELAY1;
       Svc == ?RELAY2;
       Svc == ?CLIENT ->
    {ok, Peer}.

%% prepare_request/3

prepare_request(Pkt, Svc, _Peer)
  when Svc == ?RELAY1;
       Svc == ?RELAY2 ->
    {send, Pkt};

prepare_request(Pkt, ?CLIENT, {_Ref, Caps}) ->
    {send, prepare(Pkt, Caps)}.

prepare(#diameter_packet{msg = Req}, Caps) ->
    #diameter_caps{origin_host  = {OH, _},
                   origin_realm = {OR, _}}
        = Caps,
    set(Req, [{'Session-Id', diameter:session_id(OH)},
              {'Origin-Host',  OH},
              {'Origin-Realm', OR}]).

%% prepare_retransmit/3

prepare_retransmit(_Pkt, false, _Peer) ->
    discard.

%% handle_answer/4

%% A relay must return Pkt.
handle_answer(Pkt, _Req, Svc, _Peer)
  when Svc == ?RELAY1;
       Svc == ?RELAY2 ->
    Pkt;

handle_answer(Pkt, _Req, ?CLIENT, _Peer) ->
    #diameter_packet{msg = Rec, errors = []} = Pkt,
    Rec.

%% handle_request/3

handle_request(Pkt, OH, {_Ref, #diameter_caps{origin_host = {OH,_}} = Caps})
  when OH /= ?CLIENT ->
    request(Pkt, Caps).

%% RELAY1 answers ACR after it's timed out at the client.
request(#diameter_packet{header = #diameter_header{cmd_code = 271}},
        #diameter_caps{origin_host = {?RELAY1, _}}) ->
    receive after 1000 -> {answer_message, 3004} end;  %% TOO_BUSY

%% RELAY1 routes any ASR or RAR to RELAY2.
request(#diameter_packet{header = #diameter_header{cmd_code = C}},
        #diameter_caps{origin_host = {?RELAY1, _}})
  when C == 274;   %% ASR
       C == 258 -> %% RAR
    {relay, [{filter, {realm, realm(?RELAY2)}}]};

%% RELAY2 routes ASR back to RELAY1 to induce DIAMETER_LOOP_DETECTED.
request(#diameter_packet{header = #diameter_header{cmd_code = 274}},
        #diameter_caps{origin_host = {?RELAY2, _}}) ->
    {relay, [{filter, {host, ?RELAY1}}]};

%% RELAY2 discards RAR to induce DIAMETER_UNABLE_TO_DELIVER.
request(#diameter_packet{header = #diameter_header{cmd_code = 258}},
        #diameter_caps{origin_host = {?RELAY2, _}}) ->
    discard;

%% Other request to a relay: send on to one of the servers in the
%% same realm.
request(_Pkt, #diameter_caps{origin_host = {OH, _}})
  when OH == ?RELAY1;
       OH == ?RELAY2 ->
    {relay, [{filter, {all, [host, realm]}}]};

%% Request received by a server: answer.
request(#diameter_packet{msg = #diameter_base_STR{'Session-Id' = SId,
                                                  'Origin-Host' = Host,
                                                  'Origin-Realm' = Realm,
                                                  'Route-Record' = Route,
                                                  'AVP' = Avps}},
        #diameter_caps{origin_host  = {OH, _},
                       origin_realm = {OR, _}}) ->

    %% Payloads of unknown AVPs aren't decoded, so we don't know that
    %% some types here are Grouped.
    [#diameter_avp{code = 111, vendor_id = undefined},
     #diameter_avp{code = 444, vendor_id = undefined, data = <<444:24>>},
     #diameter_avp{code = 555, vendor_id = undefined}]
        = Avps,

    %% The request should have the Origin-Host/Realm of the original
    %% sender.
    R = realm(?CLIENT),
    {?CLIENT, R} = {Host, Realm},
    %% A relay appends the identity of the peer that a request was
    %% received from to the Route-Record avp.
    [?CLIENT] = Route,
    {reply, #diameter_base_STA{'Result-Code' = ?SUCCESS,
                               'Session-Id' = SId,
                               'Origin-Host' = OH,
                               'Origin-Realm' = OR,
                               'AVP' = Avps}}.
