-module(hbq_tests).
-include_lib("eunit/include/eunit.hrl").

pop_test_() ->
  [test_empty_list(), 
   test_one_element(), 
   test_hole(),
   test_multiple_elements_without_holes(),
   test_only_pops_if_LastIndex_fits_to_first_element()
  ].

test_empty_list() ->
  ?_assertEqual({{nothing, nil}, []}, hbq:pop(bla, [])).

test_one_element() ->
  [?_assertEqual({{{"bla", 1}, 1}, []}, 
      hbq:pop(0, [{{"bla", 1}, 1}])),
   ?_assertEqual({{nothing,nil},[{{"bla",1}, 1}]}, 
      hbq:pop(1, [{{"bla", 1}, 1}]))
  ].

test_hole() ->
  ?_assertEqual({{nothing, nil}, [{message3, 3}]},
      hbq:pop(1, [{message3, 3}])).
    
test_multiple_elements_without_holes() ->
  [
    ?_assertEqual({{message1, 1}, [{message2, 2}]}, 
      hbq:pop(0, [{message1, 1}, {message2, 2}]))
    
  ].

test_only_pops_if_LastIndex_fits_to_first_element() ->
  ?_assertEqual({{nothing, nil}, [{message1, 1}, {message2, 2}]},
      hbq:pop(1, [{message1, 1}, {message2, 2}])).
