%%% @author Konstantin Sorokin <kvs@sigterm.ru>
%%%
%%% @copyright 2011 Konstantin V. Sorokin, All rights reserved. Open source, BSD License
%%% @version 1.0
%%%
-module(esnappy).
-version(1.0).
-on_load(init/0).
-export([create_ctx/0, compress/2, decompress/2]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

%% @doc Initialize NIF.
init() ->
    SoName = filename:join(case code:priv_dir(?MODULE) of
                               {error, bad_name} ->
                                   %% this is here for testing purposes
                                   filename:join(
                                     [filename:dirname(
                                        code:which(?MODULE)),"..","priv"]);
                               Dir ->
                                   Dir
                           end, atom_to_list(?MODULE) ++ "_nif"),
    erlang:load_nif(SoName, 0).

compress_impl(_Ctx, _Ref, _Self, _IoList) ->
    erlang:nif_error(not_loaded).

decompress_impl(_Ctx, _Ref, _Self, _IoList) ->
    erlang:nif_error(not_loaded).

create_ctx() ->
    erlang:nif_error(not_loaded).

compress(Ctx, RawData) ->
    Ref = make_ref(),
    ok = compress_impl(Ctx, Ref, self(), RawData),
    receive
        {ok, Ref, CompressedData} ->
            {ok, CompressedData};
        {error, Reason} ->
            {error, Reason};
        Other ->
            throw(Other)
    end.

decompress(Ctx, CompressedData) ->
    Ref = make_ref(),
    ok = decompress_impl(Ctx, Ref, self(), CompressedData),
    receive
        {ok, Ref, UncompressedData} ->
            {ok, UncompressedData};
        {error, Reason} ->
            {error, Reason};
        Other ->
            throw(Other)
    end.

%% ===================================================================
%% EUnit tests
%% ===================================================================
-ifdef(TEST).

all_test_() ->
    {timeout, 120, [fun test_binary/0,
                    fun test_iolist/0,
                    fun test_zero_binary/0
                   ]
    }.

test_binary() ->
    {ok, Ctx} = create_ctx(),
    {ok, Data} = file:read_file("../test/text.txt"),
    CompressResult = compress(Ctx, Data),
    ?assertMatch({ok, _}, CompressResult),
    {ok, CompressedData} = CompressResult,
    DecompressResult = decompress(Ctx, CompressedData),
    ?assertMatch({ok, _}, DecompressResult),
    {ok, UncompressedData} = DecompressResult,
    ?assertEqual(true, Data =:= UncompressedData),
    CompressedDataSize = size(CompressedData),
    DataSize = size(Data),
    ?assertEqual(true, CompressedDataSize < DataSize),
    ok.

test_iolist() ->
    {ok, Ctx} = create_ctx(),
    RawData = ["fshgggggggggggggggggg", <<"weqeqweqw">>],
    CompressResult = compress(Ctx, RawData),
    ?assertMatch({ok, _}, CompressResult),
    {ok, CompressedData} = CompressResult,
    DecompressResult = decompress(Ctx, CompressedData),
    ?assertMatch({ok, _}, DecompressResult),
    {ok, UncompressedData} = DecompressResult,
    ?assertEqual(true, list_to_binary(RawData) =:= UncompressedData),
    ok.

test_zero_binary() ->
    {ok, Ctx} = create_ctx(),
    RawData = <<>>,
    CompressResult = compress(Ctx, RawData),
    ?assertMatch({ok, _}, CompressResult),
    {ok, CompressedData} = CompressResult,
    DecompressResult = decompress(Ctx, CompressedData),
    ?assertMatch({error, _}, DecompressResult),
    ok.

-endif.
