-module(server).
-export([start/0]).

start() ->
  Timer = spawn_link(fun() -> server_timer:prepare(120000) end),
  Server = dispatcher:start(Timer),
  Timer ! {Server}.
  
