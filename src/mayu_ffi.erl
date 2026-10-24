-module(mayu_ffi).

-export([version/0]).

version() ->
  _ = application:load(mayu),
  {ok, Version} = application:get_key(mayu, vsn),
  list_to_binary(Version).
