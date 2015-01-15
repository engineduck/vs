-module(slot_manager).
-export([start/1]).

-define(NUMBER_SLOTS, 25).
-define(U, util).
-define(L, free_slot_list).

-record(s, {
  timer=nil, 
  sender=nil, 
  receiver=nil, 
  sync_manager=nil,
  reserved_slot=nil,
  free_slots=nil
}).

start(SyncManager) -> 
  spawn(fun() -> init(#s{sync_manager=SyncManager}) end).

init(State) when State#s.sender /= nil, State#s.receiver /= nil ->
  random:seed(now()),
  io:format("~ninit done~n", []),
  loop(resetSlots(startSlotTimer(State, ?U:currentTime(State#s.sync_manager))));
init(State) ->
  receive
    {set_sender, SenderPID}     -> init(State#s{sender=SenderPID});
    {set_receiver, ReceiverPID} -> init(State#s{receiver=ReceiverPID})
  end.

loop(State) ->
  io:format("~nloop~n", []),
  receive 
    {reserve_slot, Slot} -> loop(reserveSlot(Slot, State));
    {From, reserve_slot} -> loop(reserveRandomSlot(From, State));
    {slot_end}           -> loop(slotEnd(State))
  end.

reserveSlot(Slot, State) ->
  io:format("reserveSlot~n", []),
  State#s{
    reserved_slot = Slot,
    free_slots = ?L:reserveSlot(Slot, State#s.free_slots)
  }.

reserveRandomSlot(From, State) -> 
  io:format("reserveRandomSlot~n", []),
  {Slot, List} = ?L:reserveRandomSlot(State#s.free_slots),
  From ! {reserved_slot, Slot},
  State#s{free_slots=List}.

slotEnd(State) -> 
  io:format("slotEnd: ~p~n", [?U:currentSlot(?U:currentTime(State#s.sync_manager))]),
  NewState = checkSlotInbox(State),
  CurrentTime = ?U:currentTime(State#s.sync_manager),

  case ?U:currentSlot(CurrentTime) of
    1 -> NewNewState = handleFrameEnd(NewState);
    _ -> NewNewState = NewState
  end,
  startSlotTimer(NewNewState, CurrentTime).

checkSlotInbox(State) ->
  io:format("checkSlotInbox~n", []),
  State#s.receiver ! {slot_end},
  receive
    {collision} ->
      io:format("collision~n", []),
      handleCollision(State);
    {no_message} ->
      io:format("no message~n", []),
      State;
    {reserve_slot, SlotNumber} ->
      io:format("reserveSlot: ~p~n", [SlotNumber]),
      State#s{
        free_slots=?L:reserveSlot(SlotNumber, State#s.free_slots)
      }
  end.

handleCollision(State) ->
  todo, % todo might have to do sth here
  State.

% returns erlang timer
startSlotTimer(State, CurrentTime) ->
  io:format("startSlotTimer~n", []),
  case State#s.timer of
    nil -> ok;
    _ -> erlang:cancel_timer(State#s.timer)
  end,
  WaitTime = ?U:timeTillNextSlot(CurrentTime),
  State#s{timer=erlang:send_after(WaitTime, self(), {slot_end})}.

% Changes ReservedSlot, FreeSlotList
handleFrameEnd(State) ->
  io:format("handleFrameEnd~n", []),
  SyncManager = State#s.sync_manager,

  FrameBeforeSync = ?U:currentFrame(?U:currentTime(SyncManager)),
  SyncManager ! {sync},
  SyncManager ! {reset_deviations},
  FrameAfterSync = ?U:currentFrame(?U:currentTime(SyncManager)),

  % todo: maybe this block is fucked, because my brain is right now:
  case FrameBeforeSync > FrameAfterSync of 
    true -> 
    io:format("sync time: old frame~n", []),
      % because of sync we are still in the old frame
      State;
    false -> 
    io:format("sync time: ok~n", []),
      {TransmissionSlot, NewState} = transmissionSlot(State), 
      TransmissionTimeOffset = 10,
      TimeTillTransmission = TransmissionTimeOffset 
        + ?U:timeTillTransmission(TransmissionSlot, ?U:currentTime(SyncManager)),
      io:format("TimeTillTransmission: ~p~n", [TimeTillTransmission]),
      NewState#s.sender ! {new_timer, TimeTillTransmission},
      resetSlots(NewState)
  end.

resetSlots(State) ->
  io:format("resetSlots~n", []),
  State#s{
    free_slots = ?L:new(?NUMBER_SLOTS),
    reserved_slot = nil % todo: richtig?
  }.

transmissionSlot(State) when State#s.reserved_slot == nil ->
  {Slot, List} = ?L:reserveLastFreeSlot(State#s.free_slots),
  io:format("transmissionSlot1: currentSlot: ~p~n", 
    [?U:currentSlot(?U:currentTime(State#s.sync_manager))]),
  io:format("transmissionSlot1: ~p~n", [Slot]),
  io:format("transmissionSlot1: ~p~n", [List]),
  {Slot, State#s{free_slots=List}};
transmissionSlot(State) ->
  io:format("transmissionSlot2 ~n", []),
  {nil, State}.