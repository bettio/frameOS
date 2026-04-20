%% SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
%% SPDX-License-Identifier: Apache-2.0

-module(buttons).

-behavior(gen_server).

-export([
    start_link/0
]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2
]).

-record(state, {
    listener,
    button_gpios,
    %% per-pin timestamp (ms) of the last accepted edge — bounces inside
    %% the debounce window are dropped.
    last_seen = #{},
    debounce_ms = 200
}).

start_link() ->
    gen_server:start_link(?MODULE, [], []).

init([]) ->
    {ok, #state{}}.

handle_call({open, ButtonGPIOs}, _From, _State) ->
    GPIO = gpio:start(),
    maps:foreach(fun(GPIONum, _CodeOrSpecial) ->
            gpio:set_direction(GPIO, GPIONum, input),
            gpio:set_int(GPIO, GPIONum, falling)
        end, ButtonGPIOs),
    {reply, ok, #state{button_gpios = ButtonGPIOs}};

handle_call({subscribe_input, all}, {Pid, _Ref}, State) ->
    {reply, ok, State#state{listener = Pid}};

handle_call(_msg, _from, state) ->
    {reply, error, state}.

handle_cast(_Msg, State) ->
    {reply, error, State}.

handle_info({gpio_interrupt, GPIONum},
            #state{listener = Listener, button_gpios = ButtonGPIOs,
                   last_seen = LastSeen, debounce_ms = DebounceMs} = State) ->
    Now = erlang:system_time(millisecond),
    Last = maps:get(GPIONum, LastSeen, 0),
    case Now - Last < DebounceMs of
        true ->
            %% bounce inside the debounce window — silently drop
            {noreply, State};
        false ->
            #{GPIONum := CodeOrSpecial} = ButtonGPIOs,
            Listener ! {input_event, self(), Now, {keyboard, down, CodeOrSpecial}},
            Listener ! {input_event, self(), Now, {keyboard, up, CodeOrSpecial}},
            {noreply, State#state{last_seen = LastSeen#{GPIONum => Now}}}
    end;
handle_info(_Msg, State) ->
    {noreply, State}.
