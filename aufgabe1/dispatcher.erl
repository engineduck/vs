- module(dispatcher).
- import(werkzeug, [get_config_value/2, timeMilliSecond/0, to_String/1, logging/2]).
- export([start/1]).

% TODO logging

start(Timer) ->
  load_config(),
  {_, ServerName} = application:get_env(server, servername),
	
  Logfile = lists:concat(["dispatcher_", to_String(node()), ".log"]),
  Startlog = lists:concat(["Server Startzeit: ", timeMilliSecond(),"mit PID ", to_String(node()), "\n"]),
  
  % Seite 8 6.1 -> Serverstart:
  % Server Startzeit: 30.04 17:37:12,375| mit PID <0.870.0>
  logging(Logfile, Startlog),
  ID = 0,
	PID = spawn_link(fun() -> loop(ID, dlq:createNew(), hbq:createNew(), clientlist:createNew(), Logfile, Timer) end),
	register(ServerName, PID),
	PID.



load_config() ->
  {ok, ConfigFile} = file:consult("server.cfg"),
  
  {ok, Latency} = get_config_value(latency, ConfigFile),
  application:set_env(server, latency, Latency),
  
  {ok, ClientLifeTime} = get_config_value(clientlifetime, ConfigFile),
  application:set_env(server, clientlifetime, ClientLifeTime),

  {ok, ServerName} = get_config_value(servername, ConfigFile),
  application:set_env(server, servername, ServerName),

  {ok, DLQLimit} = get_config_value(dlqlimit, ConfigFile),
  application:set_env(server, dlqlimit, DLQLimit).


loop(ID, DLQ, HBQ, Clientlist, Logfile, Timer) ->
  Timer ! {ping},
	receive 
    {getmessages, Client} ->
      % pruefen, welche nachricht der client bekommen soll, falls er schon bekannt ist
      ModifiedClientList = clientlist:add(Client,get_timestamp(),Clientlist),
      ClientListNumber = clientlist:lastMessageID(Client, Clientlist),
      if 
        % sonst hole kleinste nachricht
        % todo: wenn in der dlq nummer 1 nicht mehr da ist, hole die niedrigste
        ClientListNumber == 0 -> Number = dlq:getLowestMsgNr(DLQ);

        % wenn bekannt, hole nachricht > letzter erhaltener
        true -> Number = ClientListNumber + 1
      end,
      io:fwrite("ClientListNumber ~p~n", [Number]),

      DlqMessage = dlq:get(Number, DLQ),

      case DlqMessage of
        false -> 
          {Message, ActualNumber, Terminated} = {"empty list",-1,true},
          NewModifiedClientList = ModifiedClientList;
        _ -> 
          {Message, ActualNumber, Terminated} = DlqMessage,
          NewModifiedClientList = clientlist:setLastMessageID(Client, ActualNumber, ModifiedClientList)
      end,

      GetmessagesLog = lists:concat([Message, "-getmessages von ", to_String(Client), "-", to_String(Terminated),"\n"]),
      
      % Seite 8 6.1 -> Client fragt Nachricht an:
      % 2-client@Brummpa-<0.771.0>-KLC: 45te_Nachricht. C Out: 30.04 17:37:32,874|(45); HBQ In: 30.04 17:37:32,875| DLQ In:30.04 17:37:38,969|.(45)-getmessages von <9595.772.0>-false
      logging(Logfile, GetmessagesLog),

      Client ! {reply, ActualNumber, Message, Terminated},
      loop(ID, DLQ, HBQ, NewModifiedClientList, Logfile, Timer);

    {getmsgid,Client} ->
      New_ID = get_next_id(ID),
      Client ! {nid, New_ID},
      GetMsgIDLog = lists:concat(["Nachrichtennummer ", to_String(New_ID), " an ", to_String(Client), " gesendet\n\n"]), 
      
      % Seite 8 6.1 -> Nachrichtennummer an Clienten verschickt:
      % Server: Nachrichtennummer 5 an <9595.773.0> gesendet
      logging(Logfile, GetMsgIDLog),
      loop(New_ID, DLQ, HBQ, Clientlist, Logfile, Timer);

    {dropmessage, {Message, Number}} -> 
      {New_HBQ, New_DLQ, TransferedNumbers} = hbq:add(Message, Number, HBQ, DLQ),
      MessageLog = lists:concat(["Nachricht ", Message , " ", Number, " in HBQ gespeichert\n\n"]),
      logging(Logfile, MessageLog),

      case TransferedNumbers == [] of
        false ->
          IOList = io_lib:format("~w", [TransferedNumbers]),
          FlatList = lists:flatten(IOList),
          TransferLog = lists:concat(["QVerwaltung>>> Nachrichten ", FlatList, " von HBQ in DLQ transferiert.\n\n"]),
          logging(Logfile, TransferLog);
        _ -> nothing
      end,  
      loop(ID, New_DLQ, New_HBQ, Clientlist, Logfile, Timer);

    {shutdown} ->
      io:fwrite("#################SERVER WIRD HERUNTERGEFAHREN#################\n"),
      MessageLog = lists:concat(["Downtime ", timeMilliSecond(), " vom Nachrichtenserver ", to_String(self()), 
        "; Anzahl der Restnachrichten in der HBQ:",to_String(length(HBQ)), "\n"]),
      logging(Logfile, MessageLog)
  end,
  init:stop(1).

get_next_id(ID) ->
	ID + 1.

get_timestamp() ->
  {Mega, Sec, Micro} = os:timestamp(),
  (Mega*1000000 + Sec)*1000 + round(Micro/1000).


	
