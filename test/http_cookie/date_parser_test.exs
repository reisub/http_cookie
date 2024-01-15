defmodule HttpCookie.DateParserTest do
  use ExUnit.Case, async: true

  alias HttpCookie.DateParser

  # taken from:
  # https://github.com/abarth/http-state/blob/master/tests/data/dates/examples.json
  #
  # generated like this:
  #
  # ```
  # "example.json"
  # |> File.read!()
  # |> Jason.decode!()
  # |> Enum.map(fn d ->
  #   {d["test"], d["expected"] && Timex.parse!(d["expected"], "{RFC1123}")}
  # end)
  # ```
  @ietf_test_cases [
    {"Mon, 10-Dec-2007 17:02:24 GMT", ~U[2007-12-10 17:02:24Z]},
    {"Wed, 09 Dec 2009 16:27:23 GMT", ~U[2009-12-09 16:27:23Z]},
    {"Thursday, 01-Jan-1970 00:00:00 GMT", ~U[1970-01-01 00:00:00Z]},
    {"Mon Dec 10 16:32:30 2007 GMT", ~U[2007-12-10 16:32:30Z]},
    {"Wednesday, 01-Jan-10 00:00:00 GMT", ~U[2010-01-01 00:00:00Z]},
    {"Mon, 10-Dec-07 20:35:03 GMT", ~U[2007-12-10 20:35:03Z]},
    {"Wed, 1 Jan 2020 00:00:00 GMT", ~U[2020-01-01 00:00:00Z]},
    {"Saturday, 8-Dec-2012 21:24:09 GMT", ~U[2012-12-08 21:24:09Z]},
    {"Thu, 31 Dec 23:55:55 2037 GMT", ~U[2037-12-31 23:55:55Z]},
    {"Sun,  9 Dec 2012 13:42:05 GMT", ~U[2012-12-09 13:42:05Z]},
    {"Wed Dec 12 2007 08:44:07 GMT-0500 (EST)", ~U[2007-12-12 08:44:07Z]},
    {"Mon, 01-Jan-2011 00: 00:00 GMT", nil},
    {"Sun, 1-Jan-1995 00:00:00 GMT", ~U[1995-01-01 00:00:00Z]},
    {"Wednesday, 01-Jan-10 0:0:00 GMT", ~U[2010-01-01 00:00:00Z]},
    {"Thu, 10 Dec 2009 13:57:2 GMT", ~U[2009-12-10 13:57:02Z]}
  ]

  # taken from:
  # https://github.com/dkarter/cookie_monster
  @cookie_monster_tests [
    {"Sun Nov 16 08:49:37 1994", ~U[1994-11-16 08:49:37Z]},
    {"Sun Nov  6 08:49:37 1994", ~U[1994-11-06 08:49:37Z]},
    {"Sunday, 06-Nov-32 08:49:37 GMT", ~U[2032-11-06 08:49:37Z]},
    {"Sun, 06-Nov-32 08:49:37 GMT", ~U[2032-11-06 08:49:37Z]},
    {"Sunday, 06-Nov-94 08:49:37 GMT", ~U[1994-11-06 08:49:37Z]},
    {"Sunday, 06-Nov-95 08:49:37 GMT", ~U[1995-11-06 08:49:37Z]},
    {"Sun, 06 Nov 1994 08:49:37 GMT", ~U[1994-11-06 08:49:37Z]},
    {"Sunday, 06-Nov-23 08:49:37 GMT", ~U[2023-11-06 08:49:37Z]},
    {"Fri, 20-Oct-23 07:22:39 GMT", ~U[2023-10-20 07:22:39Z]}
  ]

  for {input, output} <- @ietf_test_cases ++ @cookie_monster_tests do
    @input input
    @output output

    @moduletag :capture_log
    test "parses #{input} to #{inspect(output)}" do
      result = DateParser.parse(@input)

      if @output == nil do
        assert {:error, _} = result
      else
        assert {:ok, @output} = result
      end
    end
  end
end
