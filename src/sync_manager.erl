-module(sync_manager).
-export([start/1]).

start(TimeOffset) -> 
  spawn(fun() -> loop(TimeOffset, []) end).

loop(TimeOffset, Deviations) ->
  receive 
    {add_deviation, StationType, SendTime, ReceiveTime} ->
      NewDeviations = addDeviation(StationType, SendTime, ReceiveTime, Deviations),
      loop(TimeOffset, NewDeviations);
    {reset_deviations} ->
      NewDeviations = resetDeviations(),
      loop(TimeOffset, NewDeviations);
    {From, get_current_time} ->
      getCurrentTime(From, TimeOffset),
      loop(TimeOffset, Deviations);
    {sync} ->
      NewTimeOffset = sync(TimeOffset, Deviations),
      loop(NewTimeOffset, Deviations);
    Any ->
      io:format("SyncManager: Received unknown message type: ~p~n", [Any]),
      loop(TimeOffset, Deviations)
  end.

addDeviation(StationType, SendTime, ReceiveTime, Deviations) 
  when StationType == "A" ->
  Deviation = SendTime - ReceiveTime,
  [Deviation | Deviations];
addDeviation(_, _, _, Deviations) ->
  Deviations.

resetDeviations() ->
  [].

getCurrentTime(From, TimeOffset) ->
  CurrentTime = currentTime(TimeOffset),
  From ! {current_time, CurrentTime}.

currentTime(TimeOffset) ->
  {MegaSecs, Secs, MicroSecs} = erlang:now(),
  (MegaSecs * 1000000000 + Secs * 1000 + MicroSecs div 1000) + TimeOffset.

sync(TimeOffset, Deviations) when length(Deviations) == 0 ->
  TimeOffset;
sync(TimeOffset, Deviations) ->
  TimeOffset + calculateNewOffset(Deviations).

calculateNewOffset(Deviations) ->
  Sum = lists:sum(Deviations),
  Sum div length(Deviations). %Special case if own station is class A?