%%% Copyright (c) 2009-2012, Dmitry Vasiliev <dima@hlabs.org>
%%% All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions are met:
%%%
%%%  * Redistributions of source code must retain the above copyright notice,
%%%    this list of conditions and the following disclaimer.
%%%  * Redistributions in binary form must reproduce the above copyright
%%%    notice, this list of conditions and the following disclaimer in the
%%%    documentation and/or other materials provided with the distribution.
%%%  * Neither the name of the copyright holders nor the names of its
%%%    contributors may be used to endorse or promote products derived from
%%%    this software without specific prior written permission.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
%%% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
%%% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
%%% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
%%% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
%%% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
%%% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
%%% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
%%% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
%%% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%%% POSSIBILITY OF SUCH DAMAGE.

%%%
%%% @doc ErlPort Ruby interface
%%% @author Dmitry Vasiliev <dima@hlabs.org>
%%% @copyright 2009-2012 Dmitry Vasiliev <dima@hlabs.org>
%%%

-module(ruby).

-author('Dmitry Vasiliev <dima@hlabs.org>').

-export([
    start/0,
    start/1,
    start/2,
    start_link/0,
    start_link/1,
    start_link/2,
    stop/1,
    call/4,
    call/5,
    switch/4,
    switch/5
    ]).

-include("ruby.hrl").


%%
%% @equiv start([])
%%

-spec start() ->
    {ok, pid()} | {error, Reason::term()}.

start() ->
    start([]).

%%
%% @doc Start Ruby instance
%%

-spec start(ruby_options:options() | erlport:server_name()) ->
    {ok, pid()} | {error, Reason::term()}.

start(Options) when is_list(Options) ->
    start(start, pid, Options);
start(Name) ->
    start(start, Name, []).

%%
%% @doc Start named Ruby instance
%%

-spec start(Name::erlport:server_name(), Options::ruby_options:options()) ->
    {ok, pid()} | {error, Reason::term()}.

start(Name, Options) when is_list(Options) ->
    start(start, Name, Options).

%%
%% @equiv start_link([])
%%

-spec start_link() ->
    {ok, pid()} | {error, Reason::term()}.

start_link() ->
    start_link([]).

%%
%% @doc Start linked Ruby instance
%%

-spec start_link(ruby_options:options() | erlport:server_name()) ->
    {ok, pid()} | {error, Reason::term()}.

start_link(Options) when is_list(Options) ->
    start(start_link, pid, Options);
start_link(Name) ->
    start(start_link, Name, []).

%%
%% @doc Start named and linked Ruby instance
%%

-spec start_link(Name::erlport:server_name(),
        Options::ruby_options:options()) ->
    {ok, pid()} | {error, Reason::term()}.

start_link(Name, Options) when is_list(Options) ->
    start(start_link, Name, Options).

%%
%% @doc Stop Ruby instance
%%

-spec stop(Instance::erlport:server_instance()) -> ok.

stop(Pid) ->
    erlport:stop(Pid).

%%
%% @equiv call(Instance, Module, Function, Args, [])
%%

-spec call(Instance::erlport:server_instance(), Module::atom(),
        Function::atom(), Args::list()) ->
    Result::term().

call(Instance, Module, Function, Args) ->
    call(Instance, Module, Function, Args, []).

%%
%% @doc Call Ruby function with arguments and return result
%%

-spec call(Instance::erlport:server_instance(), Module::atom(),
        Function::atom(), Args::list(),
        Options::[{timeout, Timeout::pos_integer() | infinity}]) ->
    Result::term().

call(Pid, Module, Function, Args, Options) ->
    erlport:call(Pid, Module, Function, Args, Options).

%%
%% @equiv switch(Instance, Module, Function, Args, [])
%%

-spec switch(Instance::erlport:server_instance(), Module::atom(),
        Function::atom(), Args::list()) ->
    Result::term().

switch(Instance, Module, Function, Args) ->
    switch(Instance, Module, Function, Args, []).

%%
%% @doc Pass control to Ruby by calling the function with arguments
%%

-spec switch(Instance::erlport:server_instance(), Module::atom(),
        Function::atom(), Args::list(),
        Options::[{timeout, Timeout::pos_integer() | infinity}
            | wait_for_result]) ->
    Result::ok | term() | {error, Reason::term()}.

switch(Pid, Module, Function, Args, Options) ->
    erlport:switch(Pid, Module, Function, Args, Options).

%%%============================================================================
%%% Utility functions
%%%============================================================================

start(Function, Name, OptionsList) when is_list(OptionsList) ->
    case ruby_options:parse(OptionsList) of
        {ok, Options=#ruby_options{start_timeout=Timeout}} ->
            Init = init_factory(Options),
            case Name of
                pid ->
                    gen_fsm:Function(erlport, Init, [{timeout, Timeout}]);
                Name ->
                    gen_fsm:Function(Name, erlport, Init, [{timeout, Timeout}])
            end;
        Error={error, _} ->
            Error
    end.

init_factory(#ruby_options{ruby=Ruby,use_stdio=UseStdio, packet=Packet,
        compressed=Compressed, port_options=PortOptions,
        call_timeout=Timeout}) ->
    fun () ->
        Path = lists:concat([Ruby,
            " -e 'require \"erlport/cli\"'"
            % Start of script options
            " --"
            " --packet=", Packet,
            " --", UseStdio,
            " --compressed=", Compressed]),
        try open_port({spawn, Path}, PortOptions) of
            Port ->
                {ok, client, #state{port=Port, timeout=Timeout,
                    compressed=Compressed}}
        catch
            error:Error ->
                {stop, {open_port_error, Error}}
        end
    end.