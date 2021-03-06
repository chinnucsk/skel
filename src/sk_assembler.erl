%%%----------------------------------------------------------------------------
%%% @author Sam Elliott <ashe@st-andrews.ac.uk>
%%% @copyright 2012 University of St Andrews (See LICENCE)
%%% @doc This module takes a workflow specification, and converts it in into a
%%% set of (concurrent) running processes.
%%%
%%% @end
%%%----------------------------------------------------------------------------
-module(sk_assembler).

-export([
         make/2
        ,run/2
        ]).

-include("skel.hrl").

-ifdef(TEST).
-compile(export_all).
-endif.

-spec make(skel:workflow(), pid() | module()) -> pid().
make(WorkFlow, EndModule) when is_atom(EndModule) ->
  DrainPid = (sk_sink:make(EndModule))(self()),
  make(WorkFlow, DrainPid);
make(WorkFlow, EndPid) when is_pid(EndPid) ->
  MakeFns = [parse(Section) || Section <- WorkFlow],
  lists:foldr(fun(MakeFn, Pid) -> MakeFn(Pid) end, EndPid, MakeFns).

-spec run(pid() | skel:workflow(), skel:input()) -> pid().
run(WorkFlow, Input) when is_pid(WorkFlow) ->
  Feeder = sk_source:make(Input),
  Feeder(WorkFlow);
run(WorkFlow, Input) when is_list(WorkFlow) ->
  DrainPid = (sk_sink:make())(self()),
  AssembledWF = make(WorkFlow, DrainPid),
  run(AssembledWF, Input).

-spec parse(skel:wf_item()) -> skel:maker_fun().
parse(Fun) when is_function(Fun, 1) ->
  parse({seq, Fun});
parse({seq, Fun}) when is_function(Fun, 1) ->
  sk_seq:make(Fun);
parse({pipe, WorkFlow}) ->
  sk_pipe:make(WorkFlow);
parse({ord, WorkFlow}) ->
  sk_ord:make(WorkFlow);
parse({farm, WorkFlow, NWorkers}) ->
  sk_farm:make(NWorkers, WorkFlow);
parse({decomp, WorkFlow, Decomp, Recomp}) when is_function(Decomp, 1),
                                               is_function(Recomp, 1) ->
  sk_decomp:make(WorkFlow, Decomp, Recomp);
parse({map, WorkFlow, Decomp, Recomp}) when is_function(Decomp, 1),
                                            is_function(Recomp, 1) ->
  sk_map:make(WorkFlow, Decomp, Recomp);
parse({reduce, Reduce, Decomp}) when is_function(Reduce, 2),
                                     is_function(Decomp, 1) ->
  sk_reduce:make(Decomp, Reduce);
parse({feedback, WorkFlow, Filter}) when is_function(Filter, 1) ->
  sk_feedback:make(WorkFlow, Filter).


