- module(client).
- import(werkzeug, [to_String/1, timeMilliSecond/0, get_config_value/2, logging/2]).
- export([start/1]).
- compile(export_all).

start(Hostadress) ->
  load_config(),
  ServerName = config(servername),
  PID = get_PID(ServerName, Hostadress),
 
  Logfile = lists:concat(["client_", to_String(node()), ".log"]),
  Startlog = lists:concat([name(), " Start: ", timeMilliSecond(),".\n\n"]),
  logging(Logfile, Startlog),
  
  LifeTime = config(lifetime) * 1000,
  %Clients = config(clients),
  
  OwnMessages = [],
  timer:exit_after(LifeTime, normal),
  loop(PID, OwnMessages, 3000, Logfile).

load_config() ->
  {ok, ConfigFile} = file:consult("client.cfg"),
  
  {ok, Clients} = get_config_value(clients, ConfigFile),
  application:set_env(client, clients, Clients),
  
  {ok, LifeTime} = get_config_value(lifetime, ConfigFile),
  application:set_env(client, lifetime, LifeTime),

  {ok, ServerName} = get_config_value(servername, ConfigFile),
  application:set_env(client, servername, ServerName),

  {ok, Sendeintervall} = get_config_value(sendeintervall, ConfigFile),
  application:set_env(client, sendeintervall, Sendeintervall).

config(Key) ->
  {_, Value} = application:get_env(client, Key),
  Value.

name() -> lists:concat([to_String(node()), to_String(self())]).


loop(PID, OwnMessages, SleepTime, Logfile) ->
  
  OwnMsgs = redakteur(5, PID, OwnMessages, SleepTime, Logfile),

  NewSleeptime = randomSleepTime(SleepTime),
  
  % Seite 10 6.1 -> Nachrichtensende Intervall ändert sich: Neues Sendeintervall: 2 Sekunden (3).
  logging(Logfile, lists:concat(["Neuer Sendeintervall ", (NewSleeptime / 1000), " Sekunden\n"])),
  leser(false, OwnMsgs, PID, Logfile),
  receive _ -> exit
  after 0 -> loop(PID, OwnMsgs, NewSleeptime, Logfile)
  end.

redakteur(0, PID, OwnMessages, _, Logfile) ->
  % vergesse, nachricht zu senden 
  Number = get_unique_id(PID),
  
  % Seite 9 6.1 -> Nachricht vergessen zu senden
  % 28te_Nachricht um 30.04 17:37:28,577| vergessen zu senden ******
  logging(Logfile, lists:concat([Number, "te Nachricht um ", timeMilliSecond(), " vergessen zu senden ******\n\n"])),
  OwnMessages;
redakteur(HowOften, PID, OwnMessages, SleepTime, Logfile) when HowOften > 0 ->
  % hole nachrichtennummer
  Number = get_unique_id(PID),
  % warte n sekunden
  timer:sleep(SleepTime),

  % adde nummer zur liste selbstgeschickter nachrichten
  OwnMessagesNew = lists:append(OwnMessages, [Number]),
  % generiere nachricht
  Message = message_builder(Number),
  SendLog = lists:concat(["\n",name(), Number,"te_Nachricht. C Out: ", timeMilliSecond(), " gesendet\n"]),
  % sende nachricht
  dropmessage(PID, Message, Number),
  
  % Seite 9 6.1 -> Nachricht senden:
  % 2-client@Brummpa-<0.771.0>-KLC: 3te_Nachricht. C Out: 30.04 17:37:16,515| gesendet
  logging(Logfile, SendLog),
  
  redakteur(HowOften-1, PID, OwnMessagesNew, SleepTime, Logfile).

randomSleepTime(SleepTime) ->
  HalfSleepTime = SleepTime * 0.5,
  RandomBinary = trunc(random:uniform() * 2),
  case RandomBinary of
    0 -> RandomValue = -1;
    1 -> RandomValue = 1
  end,
  case HalfSleepTime >= 1000 of
    true -> Change = HalfSleepTime * RandomValue;
    false -> Change = 1000 * RandomValue
  end,
  IntermediateSleepTime = SleepTime + Change,
  case IntermediateSleepTime >= 2000 of
    true -> trunc(IntermediateSleepTime);
    false -> 2000
  end.

leser(true, _, _, Logfile) -> 
  
  %Seite 10 6.2.2 -> Nachrichten abfragen beenden:
  logging(Logfile, lists:concat(["..getmessages..Done...\n\n"])),
  nix;

leser(Terminated, OwnMessages, PID, Logfile) when Terminated == false -> 
  % hole nachricht
  {TerminatedFlag,Message} = receive_message(PID),
  
  %überprüft ob die Nachricht von sich selbst ist
  {Number, TextMessage} = Message,
  case Number == -1 of
    true -> leser(TerminatedFlag,OwnMessages,PID,Logfile);
    false -> 
      TestFunction = fun(X) -> X =:= Number end,
      IsOwn = lists:any(TestFunction,OwnMessages),
  
      case IsOwn of 
        true -> 
        MessageOwn = lists:concat([TextMessage, ",.own Message; C In: ", timeMilliSecond(),"\n"]),
        
        % Seite 10 6.2.2 -> Fremde Nachricht vom Server empfangen:
        logging(Logfile, MessageOwn);
        
        false -> 
          MessageForeign = lists:concat([TextMessage, "; C In: ", timeMilliSecond(),"\n"]),
          
          % Seite 10 6.2.2 -> Fremde Nachricht vom Server empfangen:
          % 2-client@Brummpa-<0.771.0>-KLC: 3te_Nachricht. C Out: 30.04 17:37:16,515|(3); HBQ In: 30.04 17:37:16,516| DLQ In:30.04 17:37:19,531|.own Message; C In: 30.04 17:37:28,608|
          logging(Logfile, MessageForeign)
        
      end,
      leser(TerminatedFlag,OwnMessages,PID,Logfile)
end.

receive_message(Server) ->
  % fragen Server nach Nachrichten
  Server ! {getmessages, self()},
  % hole Nachrichten vom Server ab
  receive
    {reply, Nachricht, Number, TerminatedFlag} ->
     % Speichere empfangene Nachrichten in Liste
     NewMessage = {Nachricht,Number}
   
  end,
  {TerminatedFlag, NewMessage}.
  

get_PID(Servername, Hostadress) ->
	{Servername, list_to_atom(Hostadress)}.

ping_server(Hostname, Adress) ->
	net_adm:ping(erlang:list_to_atom(lists:concat([Hostname,"@", Adress]))).


% Seite 4 3.3 -> String in dem die eigentliche Nachricht enthalten ist; 
message_builder(MessageNumber) ->
	lists:concat([to_String(node()), "-", to_String(self()), "-C-1-01:", MessageNumber,"te Nachricht. Sendezeit: ", timeMilliSecond(), "(", MessageNumber, ")\n"]).
	
dropmessage(Server, Message, Number) ->
	Server ! {dropmessage, {Message, Number}}.

get_unique_id(Server) ->
	Server ! {getmsgid, self()},
	receive{nid, Number} ->
		Number
	end.

