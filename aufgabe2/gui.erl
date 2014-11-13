-module(gui).
-export([start/0]).
-import(werkzeug, [to_String/1]).
-import(utility, [log/2]).

start() ->
  {ok, ConfigFile} = file:consult("koordinator.cfg"),
  utility:load_config(gui, ConfigFile),
  NNode = utility:from_config(gui, nameservicenode),
  NName = utility:from_config(gui, nameservicename),
  N = utility:find_nameservice(NNode, NName),
  Koordinator = utility:find_process(koordinator, N),
  
  Log = lists:concat(["gui.log"]),

  Koordinator ! {step},
  log(Log, "Sent {step} to koordinator."),
  timer:sleep(4000),
  Koordinator ! {calc, 19},
  log(Log, "Sent {calc, 3} to koordinator.").
  % timer:sleep(20000),
  % Koordinator ! {calc},
  % log(Log, "Sent {calc}."),
  % timer:sleep(20000),
  % Koordinator ! {kill},
  % log(Log, "Sent {kill} to koordinator.").