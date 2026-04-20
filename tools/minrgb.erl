%% SPDX-FileCopyrightText: 2026 Davide Bettio <davide@uninstall.it>
%% SPDX-License-Identifier: Apache-2.0

-module(minrgb).

-export([main/1]).

main(Argv) ->
    erlang:halt(do_main(Argv)).

do_main(Argv) ->
    [Fmt, InName, OutName] = Argv,

    ok = application:load(wx),

    wx:new(),

    Image = wxImage:new(InName),
    true = wxImage:isOk(Image),
    {ok, File} = file:open(OutName, write),

    Width = wxImage:getWidth(Image),
    Height = wxImage:getHeight(Image),

    RGBData = wxImage:getData(Image),

    Header = make_header(Fmt, Width, Height),

    FileData =
        case Fmt of
            "rgba8888" ->
                case wxImage:hasAlpha(Image) of
                    true -> true;
                    false -> wxImage:initAlpha(Image)
                end,
                true = wxImage:hasAlpha(Image),
                AData = wxImage:getAlpha(Image),
                to_rgba(RGBData, AData, Header)
        end,

    file:write(File, FileData),
    file:close(File),

    0.

make_header(Fmt, Width, Height) ->
    make_header(Fmt, Width, Height, Width, Height).

make_header("rgba8888", Width, Height, TileWidth, TileHeight) ->
    <<"rgba8888", Width:16/integer-unsigned-little, TileWidth:16/integer-unsigned-little,
        Height:16/integer-unsigned-little, TileHeight:16/integer-unsigned-little>>.

to_rgba(<<>>, <<>>, Converted) ->
    Converted;
to_rgba(<<RGB:3/binary, RGBRest/binary>>, <<A:1/binary, ARest/binary>>, Converted) ->
    to_rgba(RGBRest, ARest, <<Converted/binary, RGB/binary, A/binary>>).
