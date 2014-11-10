-module(koordinator).
-import(werkzeug, [get_config_value/2, logging/2, to_String/1, timeMilliSecond/0]).
-export([start/0]).

load_config() ->
  {ok, ConfigFile} = file:consult("koordinator.cfg"),
  
  {ok, Arbeitszeit} = get_config_value(arbeitszeit, ConfigFile),
  application:set_env(koordinator, arbeitszeit, Arbeitszeit),
  
  {ok, Termzeit} = get_config_value(termzeit, ConfigFile),
  application:set_env(koordinator, termzeit, Termzeit),

  {ok, Ggtprozessnummer} = get_config_value(ggtprozessnummer, ConfigFile),
  application:set_env(koordinator, ggtprozessnummer, Ggtprozessnummer),

  {ok, NameserviceNode} = get_config_value(nameservicenode, ConfigFile),
  application:set_env(koordinator, nameservicenode, NameserviceNode),

  {ok, NameserviceName} = get_config_value(nameservicename, ConfigFile),
  application:set_env(koordinator, nameservicename, NameserviceName).

 config(Key) ->
  {_, Value} = application:get_env(koordinator, Key),
  Value.

findNameService() ->
  NameserviceName = config(nameservicenode),
  Ping = net_adm:ping(NameserviceName),
  timer:sleep(1000),
  global:whereis_name(nameservice).

start() ->
  spawn_link(fun() -> run() end).

run() ->
  Logfile = lists:concat(["koordinator_", to_String(node()), ".log"]),
  Startlog = lists:concat([to_String(node()), " Startzeit: ", timeMilliSecond()," mit PID ", to_String(self()), "\n"]),
  logging(Logfile, Startlog),
  load_config(),
  logging(Logfile, "koordinator.cfg gelesen...\n"),
  Nameservice = findNameService(),

  case Nameservice of
    undefined -> logging(Logfile, "Nameservice nicht gefunden...\n");
    _ -> logging(Logfile, "Nameservice gebunden...\n"),
      global:register_name(koordinator,self()),
      logging(Logfile, "lokal registriert...\n"),
     
      Nameservice ! {self(),{bind,koordinator,node()}},
      receive ok -> logging(Logfile, "beim Namensdienst registriert.\n");
        in_use -> io:format("Fehler: Name schon gebunden.\n")
      end,
      logging(Logfile, "\n"),
      initialphase(Nameservice, [], Logfile)
  end.

initialphase(Nameservice, GgtList, Logfile) ->
% todo: step, reset
%step: Der Koordinator beendet die Initialphase und bildet den Ring. Er wartet nun auf den Start einer ggT-Berechnung.
%reset: Der Koordinator sendet allen ggT-Prozessen das kill-Kommando und bringt sich selbst in den initialen Zustand, indem sich Starter wieder melden können.
%toggle: Der Koordinator verändert den Flag zur Korrektur bei falschen Terminierungsmeldungen.

  receive 
    {getsteeringval,StarterName} -> 
      % todo: was ist die (0)?
      logging(Logfile, lists:concat(["getsteeringval: ", to_String(StarterName), " (0)."])),
    	StarterName ! {steeringval,config(arbeitszeit),config(termzeit),config(ggtprozessnummer)},
      initialphase(Nameservice, GgtList, Logfile);

    {hello, GgtName} ->
      % todo: was ist die (3)?
      logging(Logfile, lists:concat(["hello: ", to_String(GgtName), " (3).\n"])),
      % todo: kritisch, wenn name doppelt eingetragen wird?
      GgtListNew = lists:append(GgtList, [GgtName]),
      initialphase(Nameservice, GgtListNew, Logfile);
   
    {kill} -> beendigungsphase(Nameservice, Logfile);
    _ -> initialphase(Nameservice, GgtList, Logfile)
  end.

arbeitsphase() ->
  %todo: kill, toggle, reset, nudge
  %reset: Der Koordinator sendet allen ggT-Prozessen das kill-Kommando und bringt sich selbst in den initialen Zustand, indem sich Starter wieder melden können.
  %toggle: Der Koordinator verändert den Flag zur Korrektur bei falschen Terminierungsmeldungen.
  %nudge: Der Koordinator erfragt bei allen ggT-Prozessen per pingGGT deren Lebenszustand ab und zeigt dies im log an.
  %prompt: Der Koordinator erfragt bei allen ggT-Prozessen per tellmi deren aktuelles Mi ab und zeigt dies im log an.
  %{calc,WggT}: Der Koordinator startet eine neue ggT-Berechnung mit Wunsch-ggT WggT.
  %{briefmi,{Clientname,CMi,CZeit}}: Ein ggT-Prozess mit Namen Clientname informiert über sein neues Mi CMi um CZeit Uhr. 
  %{briefterm,{Clientname,CMi,CZeit},From}: Ein ggT-Prozess mit Namen Clientname und PID From informiert über über die Terminierung der Berechnung mit Ergebnis CMi um CZeit Uhr.
  todo.

beendigungsphase(Nameservice, Logfile) ->
  % todo: kill all ggts
  Nameservice ! {self(),{unbind,koordinator}},
  receive 
    ok -> logging(Logfile, "unbound koordinator at nameservice.\n")
  end,
  unregister(koordinator).