-module(cache_ffi).

-export([store/1, read/0]).

store(Cache) ->
  persistent_term:put({mayu, image_cache}, Cache),
  nil.

read() ->
  persistent_term:get({mayu, image_cache}).
