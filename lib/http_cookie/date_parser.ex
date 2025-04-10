# Generated from lib/http_cookie/date_parser.ex.exs, do not edit.
# Generated at 2025-04-10 20:55:30Z.

defmodule HttpCookie.DateParser do
  @moduledoc false

  require Logger

  defmodule State do
    @moduledoc false
    defstruct ~w[time day_of_month month year]a
  end

  @doc """
  Parses a cookie date.

  Parses the provided string as specified in [RFC 6265](https://datatracker.ietf.org/doc/html/rfc6265#section-5.1.1).
  """
  @spec parse(date_string :: String.t()) :: {:ok, DateTime.t()} | {:error, atom()}
  def parse(date_string) do
    case date_tokens(date_string) do
      {:ok, date_tokens, _rest, _ctx, _line, _col} ->
        date_tokens
        |> Keyword.values()
        |> parse_date_tokens()
        |> apply_semantics()

      {:error, _, _rest, _ctx, _line, _col} ->
        {:error, :failed_to_parse_date_tokens}
    end
  end

  defp parse_date_tokens(date_tokens) do
    Enum.reduce(date_tokens, %State{}, fn token, state ->
      with :error <- try_parsing_time(token, state),
           :error <- try_parsing_day_of_month(token, state),
           :error <- try_parsing_month(token, state),
           :error <- try_parsing_year(token, state) do
        state
      else
        state -> state
      end
    end)
  end

  defp try_parsing_time(string, %{time: nil} = state) do
    case time(string) do
      {:ok, [hour, minute, second], _rest, _ctx, _line, _col} ->
        %{state | time: {hour, minute, second}}

      {:error, _, _rest, _ctx, _line, _col} ->
        :error
    end
  end

  defp try_parsing_time(_str, _already_parsed_state), do: :error

  defp try_parsing_day_of_month(str, %{day_of_month: nil} = state) do
    case day_of_month(str) do
      {:ok, [day_of_month], _rest, _ctx, _line, _col} ->
        %{state | day_of_month: day_of_month}

      {:error, _, _rest, _ctx, _line, _col} ->
        :error
    end
  end

  defp try_parsing_day_of_month(_str, _already_parsed_state), do: :error

  defp try_parsing_month(str, %{month: nil} = state) do
    case month(str) do
      {:ok, [month], _rest, _ctx, _line, _col} ->
        %{state | month: month}

      {:error, _, _rest, _ctx, _line, _col} ->
        :error
    end
  end

  defp try_parsing_month(_str, _already_parsed_state), do: :error

  defp try_parsing_year(str, %{year: nil} = state) do
    case year(str) do
      {:ok, [year], _rest, _ctx, _line, _col} ->
        # 3.  If the year-value is greater than or equal to 70 and less than or
        #     equal to 99, increment the year-value by 1900.
        #
        # 4.  If the year-value is greater than or equal to 0 and less than or
        #     equal to 69, increment the year-value by 2000.
        year =
          case year do
            y when y in 70..99 -> 1900 + y
            y when y in 0..69 -> 2000 + y
            y -> y
          end

        %{state | year: year}

      {:error, _, _rest, _ctx, _line, _col} ->
        :error
    end
  end

  defp try_parsing_year(_str, _already_parsed_state), do: :error

  defp apply_semantics(state) do
    with :ok <- check_year(state),
         :ok <- check_month(state),
         :ok <- check_day_of_month(state),
         :ok <- check_time(state),
         {:ok, date} <- Date.new(state.year, state.month, state.day_of_month),
         {:ok, time} <- Time.from_erl(state.time) do
      DateTime.new(date, time)
    end
  end

  defp check_year(%{year: y}) when y >= 1601, do: :ok
  defp check_year(_state), do: {:error, :invalid_year_value}

  defp check_month(%{month: m}) when m in 1..12, do: :ok
  defp check_month(_state), do: {:error, :invalid_month_value}

  defp check_day_of_month(%{day_of_month: d}) when d in 1..31, do: :ok
  defp check_day_of_month(_state), do: {:error, :invalid_day_of_month_value}

  defp check_time(%{time: {h, m, s}}) when h in 0..23 and m in 0..59 and s in 0..59, do: :ok
  defp check_time(_state), do: {:error, :invalid_time_value}

  @spec month(binary, keyword) ::
          {:ok, [term], rest, context, line, byte_offset}
          | {:error, reason, rest, context, line, byte_offset}
        when line: {pos_integer, byte_offset},
             byte_offset: non_neg_integer,
             rest: binary,
             reason: String.t(),
             context: map
  defp month(binary, opts \\ []) when is_binary(binary) do
    context = Map.new(Keyword.get(opts, :context, []))
    byte_offset = Keyword.get(opts, :byte_offset, 0)

    line =
      case Keyword.get(opts, :line, 1) do
        {_, _} = line -> line
        line -> {line, byte_offset}
      end

    case month__0(binary, [], [], context, line, byte_offset) do
      {:ok, acc, rest, context, line, offset} ->
        {:ok, :lists.reverse(acc), rest, context, line, offset}

      {:error, _, _, _, _, _} = error ->
        error
    end
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 106 or x0 === 74) and (x1 === 97 or x1 === 65) and (x2 === 110 or x2 === 78) do
    month__1(rest, [1] ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 102 or x0 === 70) and (x1 === 101 or x1 === 69) and (x2 === 98 or x2 === 66) do
    month__1(rest, [2] ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 109 or x0 === 77) and (x1 === 97 or x1 === 65) and (x2 === 114 or x2 === 82) do
    month__1(rest, [3] ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 97 or x0 === 65) and (x1 === 112 or x1 === 80) and (x2 === 114 or x2 === 82) do
    month__1(rest, [4] ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 109 or x0 === 77) and (x1 === 97 or x1 === 65) and (x2 === 121 or x2 === 89) do
    month__1(rest, [5] ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 106 or x0 === 74) and (x1 === 117 or x1 === 85) and (x2 === 110 or x2 === 78) do
    month__1(rest, [6] ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 106 or x0 === 74) and (x1 === 117 or x1 === 85) and (x2 === 108 or x2 === 76) do
    month__1(rest, ~c"\a" ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 97 or x0 === 65) and (x1 === 117 or x1 === 85) and (x2 === 103 or x2 === 71) do
    month__1(rest, ~c"\b" ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 115 or x0 === 83) and (x1 === 101 or x1 === 69) and (x2 === 112 or x2 === 80) do
    month__1(rest, ~c"\t" ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 111 or x0 === 79) and (x1 === 99 or x1 === 67) and (x2 === 116 or x2 === 84) do
    month__1(rest, ~c"\n" ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 110 or x0 === 78) and (x1 === 111 or x1 === 79) and (x2 === 118 or x2 === 86) do
    month__1(rest, ~c"\v" ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(<<x0, x1, x2, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 === 100 or x0 === 68) and (x1 === 101 or x1 === 69) and (x2 === 99 or x2 === 67) do
    month__1(rest, ~c"\f" ++ acc, stack, context, comb__line, comb__offset + 3)
  end

  defp month__0(rest, _acc, _stack, context, line, offset) do
    {:error, "expected jan/feb/mar/apr/may/jun/jul/aug/sep/oct/nov/dec", rest, context, line,
     offset}
  end

  defp month__1(rest, acc, stack, context, line, offset) do
    month__2(rest, [], [acc | stack], context, line, offset)
  end

  defp month__2(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 0 and x0 <= 255 do
    month__4(
      rest,
      acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp month__2(rest, acc, stack, context, line, offset) do
    month__3(rest, acc, stack, context, line, offset)
  end

  defp month__4(rest, acc, stack, context, line, offset) do
    month__2(rest, acc, stack, context, line, offset)
  end

  defp month__3(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc
    month__5(rest, [] ++ acc, stack, context, line, offset)
  end

  defp month__5(rest, acc, _stack, context, line, offset) do
    {:ok, acc, rest, context, line, offset}
  end

  @spec day_of_month(binary, keyword) ::
          {:ok, [term], rest, context, line, byte_offset}
          | {:error, reason, rest, context, line, byte_offset}
        when line: {pos_integer, byte_offset},
             byte_offset: non_neg_integer,
             rest: binary,
             reason: String.t(),
             context: map
  defp day_of_month(binary, opts \\ []) when is_binary(binary) do
    context = Map.new(Keyword.get(opts, :context, []))
    byte_offset = Keyword.get(opts, :byte_offset, 0)

    line =
      case Keyword.get(opts, :line, 1) do
        {_, _} = line -> line
        line -> {line, byte_offset}
      end

    case day_of_month__0(binary, [], [], context, line, byte_offset) do
      {:ok, acc, rest, context, line, offset} ->
        {:ok, :lists.reverse(acc), rest, context, line, offset}

      {:error, _, _, _, _, _} = error ->
        error
    end
  end

  defp day_of_month__0(rest, acc, stack, context, line, offset) do
    day_of_month__1(rest, [], [acc | stack], context, line, offset)
  end

  defp day_of_month__1(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 48 and x0 <= 57 do
    day_of_month__2(rest, [x0 - 48] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp day_of_month__1(rest, _acc, _stack, context, line, offset) do
    {:error, "expected [d]d", rest, context, line, offset}
  end

  defp day_of_month__2(rest, acc, stack, context, line, offset) do
    day_of_month__4(rest, acc, [1 | stack], context, line, offset)
  end

  defp day_of_month__4(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 48 and x0 <= 57 do
    day_of_month__5(rest, [x0] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp day_of_month__4(rest, acc, stack, context, line, offset) do
    day_of_month__3(rest, acc, stack, context, line, offset)
  end

  defp day_of_month__3(rest, acc, [_ | stack], context, line, offset) do
    day_of_month__6(rest, acc, stack, context, line, offset)
  end

  defp day_of_month__5(rest, acc, [1 | stack], context, line, offset) do
    day_of_month__6(rest, acc, stack, context, line, offset)
  end

  defp day_of_month__5(rest, acc, [count | stack], context, line, offset) do
    day_of_month__4(rest, acc, [count - 1 | stack], context, line, offset)
  end

  defp day_of_month__6(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc

    day_of_month__7(
      rest,
      (
        [head | tail] = :lists.reverse(user_acc)
        [:lists.foldl(fn x, acc -> x - 48 + acc * 10 end, head, tail)]
      ) ++ acc,
      stack,
      context,
      line,
      offset
    )
  end

  defp day_of_month__7(rest, acc, stack, context, line, offset) do
    day_of_month__8(rest, [], [acc | stack], context, line, offset)
  end

  defp day_of_month__8(rest, acc, stack, context, line, offset) do
    day_of_month__12(
      rest,
      [],
      [{rest, context, line, offset}, acc | stack],
      context,
      line,
      offset
    )
  end

  defp day_of_month__10(rest, acc, [_, previous_acc | stack], context, line, offset) do
    day_of_month__9(rest, acc ++ previous_acc, stack, context, line, offset)
  end

  defp day_of_month__11(_, _, [{rest, context, line, offset} | _] = stack, _, _, _) do
    day_of_month__10(rest, [], stack, context, line, offset)
  end

  defp day_of_month__12(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 >= 0 and x0 <= 47) or (x0 >= 58 and x0 <= 255) do
    day_of_month__13(
      rest,
      acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp day_of_month__12(rest, acc, stack, context, line, offset) do
    day_of_month__11(rest, acc, stack, context, line, offset)
  end

  defp day_of_month__13(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 0 and x0 <= 255 do
    day_of_month__15(
      rest,
      acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp day_of_month__13(rest, acc, stack, context, line, offset) do
    day_of_month__14(rest, acc, stack, context, line, offset)
  end

  defp day_of_month__15(rest, acc, stack, context, line, offset) do
    day_of_month__13(rest, acc, stack, context, line, offset)
  end

  defp day_of_month__14(rest, acc, [_, previous_acc | stack], context, line, offset) do
    day_of_month__9(rest, acc ++ previous_acc, stack, context, line, offset)
  end

  defp day_of_month__9(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc
    day_of_month__16(rest, [] ++ acc, stack, context, line, offset)
  end

  defp day_of_month__16(rest, acc, _stack, context, line, offset) do
    {:ok, acc, rest, context, line, offset}
  end

  @spec year(binary, keyword) ::
          {:ok, [term], rest, context, line, byte_offset}
          | {:error, reason, rest, context, line, byte_offset}
        when line: {pos_integer, byte_offset},
             byte_offset: non_neg_integer,
             rest: binary,
             reason: String.t(),
             context: map
  defp year(binary, opts \\ []) when is_binary(binary) do
    context = Map.new(Keyword.get(opts, :context, []))
    byte_offset = Keyword.get(opts, :byte_offset, 0)

    line =
      case Keyword.get(opts, :line, 1) do
        {_, _} = line -> line
        line -> {line, byte_offset}
      end

    case year__0(binary, [], [], context, line, byte_offset) do
      {:ok, acc, rest, context, line, offset} ->
        {:ok, :lists.reverse(acc), rest, context, line, offset}

      {:error, _, _, _, _, _} = error ->
        error
    end
  end

  defp year__0(rest, acc, stack, context, line, offset) do
    year__1(rest, [], [acc | stack], context, line, offset)
  end

  defp year__1(<<x0, x1, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 48 and x0 <= 57 and (x1 >= 48 and x1 <= 57) do
    year__2(rest, [x1 - 48 + (x0 - 48) * 10] ++ acc, stack, context, comb__line, comb__offset + 2)
  end

  defp year__1(rest, _acc, _stack, context, line, offset) do
    {:error, "expected yy/YYYY", rest, context, line, offset}
  end

  defp year__2(rest, acc, stack, context, line, offset) do
    year__4(rest, acc, [2 | stack], context, line, offset)
  end

  defp year__4(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 48 and x0 <= 57 do
    year__5(rest, [x0] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp year__4(rest, acc, stack, context, line, offset) do
    year__3(rest, acc, stack, context, line, offset)
  end

  defp year__3(rest, acc, [_ | stack], context, line, offset) do
    year__6(rest, acc, stack, context, line, offset)
  end

  defp year__5(rest, acc, [1 | stack], context, line, offset) do
    year__6(rest, acc, stack, context, line, offset)
  end

  defp year__5(rest, acc, [count | stack], context, line, offset) do
    year__4(rest, acc, [count - 1 | stack], context, line, offset)
  end

  defp year__6(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc

    year__7(
      rest,
      (
        [head | tail] = :lists.reverse(user_acc)
        [:lists.foldl(fn x, acc -> x - 48 + acc * 10 end, head, tail)]
      ) ++ acc,
      stack,
      context,
      line,
      offset
    )
  end

  defp year__7(rest, acc, stack, context, line, offset) do
    year__8(rest, [], [acc | stack], context, line, offset)
  end

  defp year__8(rest, acc, stack, context, line, offset) do
    year__12(rest, [], [{rest, context, line, offset}, acc | stack], context, line, offset)
  end

  defp year__10(rest, acc, [_, previous_acc | stack], context, line, offset) do
    year__9(rest, acc ++ previous_acc, stack, context, line, offset)
  end

  defp year__11(_, _, [{rest, context, line, offset} | _] = stack, _, _, _) do
    year__10(rest, [], stack, context, line, offset)
  end

  defp year__12(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 >= 0 and x0 <= 47) or (x0 >= 58 and x0 <= 255) do
    year__13(
      rest,
      acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp year__12(rest, acc, stack, context, line, offset) do
    year__11(rest, acc, stack, context, line, offset)
  end

  defp year__13(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 0 and x0 <= 255 do
    year__15(
      rest,
      acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp year__13(rest, acc, stack, context, line, offset) do
    year__14(rest, acc, stack, context, line, offset)
  end

  defp year__15(rest, acc, stack, context, line, offset) do
    year__13(rest, acc, stack, context, line, offset)
  end

  defp year__14(rest, acc, [_, previous_acc | stack], context, line, offset) do
    year__9(rest, acc ++ previous_acc, stack, context, line, offset)
  end

  defp year__9(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc
    year__16(rest, [] ++ acc, stack, context, line, offset)
  end

  defp year__16(rest, acc, _stack, context, line, offset) do
    {:ok, acc, rest, context, line, offset}
  end

  @spec time(binary, keyword) ::
          {:ok, [term], rest, context, line, byte_offset}
          | {:error, reason, rest, context, line, byte_offset}
        when line: {pos_integer, byte_offset},
             byte_offset: non_neg_integer,
             rest: binary,
             reason: String.t(),
             context: map
  defp time(binary, opts \\ []) when is_binary(binary) do
    context = Map.new(Keyword.get(opts, :context, []))
    byte_offset = Keyword.get(opts, :byte_offset, 0)

    line =
      case Keyword.get(opts, :line, 1) do
        {_, _} = line -> line
        line -> {line, byte_offset}
      end

    case time__0(binary, [], [], context, line, byte_offset) do
      {:ok, acc, rest, context, line, offset} ->
        {:ok, :lists.reverse(acc), rest, context, line, offset}

      {:error, _, _, _, _, _} = error ->
        error
    end
  end

  defp time__0(rest, acc, stack, context, line, offset) do
    time__1(rest, [], [acc | stack], context, line, offset)
  end

  defp time__1(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 48 and x0 <= 57 do
    time__2(rest, [x0 - 48] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp time__1(rest, _acc, _stack, context, line, offset) do
    {:error, "expected [H]H:[M]M:[S]S", rest, context, line, offset}
  end

  defp time__2(rest, acc, stack, context, line, offset) do
    time__4(rest, acc, [1 | stack], context, line, offset)
  end

  defp time__4(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 48 and x0 <= 57 do
    time__5(rest, [x0] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp time__4(rest, acc, stack, context, line, offset) do
    time__3(rest, acc, stack, context, line, offset)
  end

  defp time__3(rest, acc, [_ | stack], context, line, offset) do
    time__6(rest, acc, stack, context, line, offset)
  end

  defp time__5(rest, acc, [1 | stack], context, line, offset) do
    time__6(rest, acc, stack, context, line, offset)
  end

  defp time__5(rest, acc, [count | stack], context, line, offset) do
    time__4(rest, acc, [count - 1 | stack], context, line, offset)
  end

  defp time__6(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc

    time__7(
      rest,
      (
        [head | tail] = :lists.reverse(user_acc)
        [:lists.foldl(fn x, acc -> x - 48 + acc * 10 end, head, tail)]
      ) ++ acc,
      stack,
      context,
      line,
      offset
    )
  end

  defp time__7(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 === 58 do
    time__8(rest, [] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp time__7(rest, _acc, _stack, context, line, offset) do
    {:error, "expected [H]H:[M]M:[S]S", rest, context, line, offset}
  end

  defp time__8(rest, acc, stack, context, line, offset) do
    time__9(rest, [], [acc | stack], context, line, offset)
  end

  defp time__9(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 48 and x0 <= 57 do
    time__10(rest, [x0 - 48] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp time__9(rest, _acc, _stack, context, line, offset) do
    {:error, "expected [H]H:[M]M:[S]S", rest, context, line, offset}
  end

  defp time__10(rest, acc, stack, context, line, offset) do
    time__12(rest, acc, [1 | stack], context, line, offset)
  end

  defp time__12(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 48 and x0 <= 57 do
    time__13(rest, [x0] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp time__12(rest, acc, stack, context, line, offset) do
    time__11(rest, acc, stack, context, line, offset)
  end

  defp time__11(rest, acc, [_ | stack], context, line, offset) do
    time__14(rest, acc, stack, context, line, offset)
  end

  defp time__13(rest, acc, [1 | stack], context, line, offset) do
    time__14(rest, acc, stack, context, line, offset)
  end

  defp time__13(rest, acc, [count | stack], context, line, offset) do
    time__12(rest, acc, [count - 1 | stack], context, line, offset)
  end

  defp time__14(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc

    time__15(
      rest,
      (
        [head | tail] = :lists.reverse(user_acc)
        [:lists.foldl(fn x, acc -> x - 48 + acc * 10 end, head, tail)]
      ) ++ acc,
      stack,
      context,
      line,
      offset
    )
  end

  defp time__15(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 === 58 do
    time__16(rest, [] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp time__15(rest, _acc, _stack, context, line, offset) do
    {:error, "expected [H]H:[M]M:[S]S", rest, context, line, offset}
  end

  defp time__16(rest, acc, stack, context, line, offset) do
    time__17(rest, [], [acc | stack], context, line, offset)
  end

  defp time__17(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 48 and x0 <= 57 do
    time__18(rest, [x0 - 48] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp time__17(rest, _acc, _stack, context, line, offset) do
    {:error, "expected [H]H:[M]M:[S]S", rest, context, line, offset}
  end

  defp time__18(rest, acc, stack, context, line, offset) do
    time__20(rest, acc, [1 | stack], context, line, offset)
  end

  defp time__20(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 48 and x0 <= 57 do
    time__21(rest, [x0] ++ acc, stack, context, comb__line, comb__offset + 1)
  end

  defp time__20(rest, acc, stack, context, line, offset) do
    time__19(rest, acc, stack, context, line, offset)
  end

  defp time__19(rest, acc, [_ | stack], context, line, offset) do
    time__22(rest, acc, stack, context, line, offset)
  end

  defp time__21(rest, acc, [1 | stack], context, line, offset) do
    time__22(rest, acc, stack, context, line, offset)
  end

  defp time__21(rest, acc, [count | stack], context, line, offset) do
    time__20(rest, acc, [count - 1 | stack], context, line, offset)
  end

  defp time__22(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc

    time__23(
      rest,
      (
        [head | tail] = :lists.reverse(user_acc)
        [:lists.foldl(fn x, acc -> x - 48 + acc * 10 end, head, tail)]
      ) ++ acc,
      stack,
      context,
      line,
      offset
    )
  end

  defp time__23(rest, acc, stack, context, line, offset) do
    time__24(rest, [], [acc | stack], context, line, offset)
  end

  defp time__24(rest, acc, stack, context, line, offset) do
    time__28(rest, [], [{rest, context, line, offset}, acc | stack], context, line, offset)
  end

  defp time__26(rest, acc, [_, previous_acc | stack], context, line, offset) do
    time__25(rest, acc ++ previous_acc, stack, context, line, offset)
  end

  defp time__27(_, _, [{rest, context, line, offset} | _] = stack, _, _, _) do
    time__26(rest, [], stack, context, line, offset)
  end

  defp time__28(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 >= 0 and x0 <= 47) or (x0 >= 58 and x0 <= 255) do
    time__29(
      rest,
      acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp time__28(rest, acc, stack, context, line, offset) do
    time__27(rest, acc, stack, context, line, offset)
  end

  defp time__29(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 >= 0 and x0 <= 255 do
    time__31(
      rest,
      acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp time__29(rest, acc, stack, context, line, offset) do
    time__30(rest, acc, stack, context, line, offset)
  end

  defp time__31(rest, acc, stack, context, line, offset) do
    time__29(rest, acc, stack, context, line, offset)
  end

  defp time__30(rest, acc, [_, previous_acc | stack], context, line, offset) do
    time__25(rest, acc ++ previous_acc, stack, context, line, offset)
  end

  defp time__25(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc
    time__32(rest, [] ++ acc, stack, context, line, offset)
  end

  defp time__32(rest, acc, _stack, context, line, offset) do
    {:ok, acc, rest, context, line, offset}
  end

  @spec date_tokens(binary, keyword) ::
          {:ok, [term], rest, context, line, byte_offset}
          | {:error, reason, rest, context, line, byte_offset}
        when line: {pos_integer, byte_offset},
             byte_offset: non_neg_integer,
             rest: binary,
             reason: String.t(),
             context: map
  defp date_tokens(binary, opts \\ []) when is_binary(binary) do
    context = Map.new(Keyword.get(opts, :context, []))
    byte_offset = Keyword.get(opts, :byte_offset, 0)

    line =
      case Keyword.get(opts, :line, 1) do
        {_, _} = line -> line
        line -> {line, byte_offset}
      end

    case date_tokens__0(binary, [], [], context, line, byte_offset) do
      {:ok, acc, rest, context, line, offset} ->
        {:ok, :lists.reverse(acc), rest, context, line, offset}

      {:error, _, _, _, _, _} = error ->
        error
    end
  end

  defp date_tokens__0(rest, acc, stack, context, line, offset) do
    date_tokens__1(rest, [], [acc | stack], context, line, offset)
  end

  defp date_tokens__1(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 === 9 or (x0 >= 32 and x0 <= 47) or (x0 >= 59 and x0 <= 64) or
              (x0 >= 91 and x0 <= 96) or
              (x0 >= 123 and x0 <= 126) do
    date_tokens__3(rest, acc, stack, context, comb__line, comb__offset + 1)
  end

  defp date_tokens__1(rest, acc, stack, context, line, offset) do
    date_tokens__2(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__3(rest, acc, stack, context, line, offset) do
    date_tokens__1(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__2(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc
    date_tokens__4(rest, [] ++ acc, stack, context, line, offset)
  end

  defp date_tokens__4(rest, acc, stack, context, line, offset) do
    date_tokens__5(rest, [], [acc | stack], context, line, offset)
  end

  defp date_tokens__5(rest, acc, stack, context, line, offset) do
    date_tokens__6(rest, [], [acc | stack], context, line, offset)
  end

  defp date_tokens__6(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 >= 0 and x0 <= 8) or (x0 >= 10 and x0 <= 31) or (x0 >= 48 and x0 <= 57) or
              x0 === 58 or
              (x0 >= 97 and x0 <= 122) or (x0 >= 65 and x0 <= 90) or (x0 >= 127 and x0 <= 255) do
    date_tokens__7(
      rest,
      [x0] ++ acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp date_tokens__6(rest, _acc, _stack, context, line, offset) do
    {:error,
     "expected byte in the range <<0>> to \"\\b\" or in the range \"\\n\" to <<31>> or in the range \"0\" to \"9\" or in the range \":\" to \":\" or in the range \"a\" to \"z\" or in the range \"A\" to \"Z\" or in the range \"\\d\" to \"ÿ\"",
     rest, context, line, offset}
  end

  defp date_tokens__7(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 >= 0 and x0 <= 8) or (x0 >= 10 and x0 <= 31) or (x0 >= 48 and x0 <= 57) or
              x0 === 58 or
              (x0 >= 97 and x0 <= 122) or (x0 >= 65 and x0 <= 90) or (x0 >= 127 and x0 <= 255) do
    date_tokens__9(
      rest,
      [x0] ++ acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp date_tokens__7(rest, acc, stack, context, line, offset) do
    date_tokens__8(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__9(rest, acc, stack, context, line, offset) do
    date_tokens__7(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__8(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc

    date_tokens__10(
      rest,
      [List.to_string(:lists.reverse(user_acc))] ++ acc,
      stack,
      context,
      line,
      offset
    )
  end

  defp date_tokens__10(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc

    date_tokens__11(
      rest,
      [
        date_token:
          case :lists.reverse(user_acc) do
            [one] -> one
            many -> raise "unwrap_and_tag/3 expected a single token, got: #{inspect(many)}"
          end
      ] ++ acc,
      stack,
      context,
      line,
      offset
    )
  end

  defp date_tokens__11(rest, acc, stack, context, line, offset) do
    date_tokens__13(rest, [], [{rest, acc, context, line, offset} | stack], context, line, offset)
  end

  defp date_tokens__13(rest, acc, stack, context, line, offset) do
    date_tokens__14(rest, [], [acc | stack], context, line, offset)
  end

  defp date_tokens__14(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 === 9 or (x0 >= 32 and x0 <= 47) or (x0 >= 59 and x0 <= 64) or
              (x0 >= 91 and x0 <= 96) or
              (x0 >= 123 and x0 <= 126) do
    date_tokens__15(rest, acc, stack, context, comb__line, comb__offset + 1)
  end

  defp date_tokens__14(rest, _acc, stack, context, line, offset) do
    [acc | stack] = stack
    date_tokens__12(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__15(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 === 9 or (x0 >= 32 and x0 <= 47) or (x0 >= 59 and x0 <= 64) or
              (x0 >= 91 and x0 <= 96) or
              (x0 >= 123 and x0 <= 126) do
    date_tokens__17(rest, acc, stack, context, comb__line, comb__offset + 1)
  end

  defp date_tokens__15(rest, acc, stack, context, line, offset) do
    date_tokens__16(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__17(rest, acc, stack, context, line, offset) do
    date_tokens__15(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__16(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc
    date_tokens__18(rest, [] ++ acc, stack, context, line, offset)
  end

  defp date_tokens__18(rest, acc, stack, context, line, offset) do
    date_tokens__19(rest, [], [acc | stack], context, line, offset)
  end

  defp date_tokens__19(rest, acc, stack, context, line, offset) do
    date_tokens__20(rest, [], [acc | stack], context, line, offset)
  end

  defp date_tokens__20(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 >= 0 and x0 <= 8) or (x0 >= 10 and x0 <= 31) or (x0 >= 48 and x0 <= 57) or
              x0 === 58 or
              (x0 >= 97 and x0 <= 122) or (x0 >= 65 and x0 <= 90) or (x0 >= 127 and x0 <= 255) do
    date_tokens__21(
      rest,
      [x0] ++ acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp date_tokens__20(rest, _acc, stack, context, line, offset) do
    [_, acc | stack] = stack
    date_tokens__12(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__21(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when (x0 >= 0 and x0 <= 8) or (x0 >= 10 and x0 <= 31) or (x0 >= 48 and x0 <= 57) or
              x0 === 58 or
              (x0 >= 97 and x0 <= 122) or (x0 >= 65 and x0 <= 90) or (x0 >= 127 and x0 <= 255) do
    date_tokens__23(
      rest,
      [x0] ++ acc,
      stack,
      context,
      (
        line = comb__line

        case x0 do
          10 -> {elem(line, 0) + 1, comb__offset + 1}
          _ -> line
        end
      ),
      comb__offset + 1
    )
  end

  defp date_tokens__21(rest, acc, stack, context, line, offset) do
    date_tokens__22(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__23(rest, acc, stack, context, line, offset) do
    date_tokens__21(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__22(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc

    date_tokens__24(
      rest,
      [List.to_string(:lists.reverse(user_acc))] ++ acc,
      stack,
      context,
      line,
      offset
    )
  end

  defp date_tokens__24(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc

    date_tokens__25(
      rest,
      [
        date_token:
          case :lists.reverse(user_acc) do
            [one] -> one
            many -> raise "unwrap_and_tag/3 expected a single token, got: #{inspect(many)}"
          end
      ] ++ acc,
      stack,
      context,
      line,
      offset
    )
  end

  defp date_tokens__12(_, _, [{rest, acc, context, line, offset} | stack], _, _, _) do
    date_tokens__26(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__25(
         inner_rest,
         inner_acc,
         [{rest, acc, context, line, offset} | stack],
         inner_context,
         inner_line,
         inner_offset
       ) do
    _ = {rest, acc, context, line, offset}

    date_tokens__13(
      inner_rest,
      [],
      [{inner_rest, inner_acc ++ acc, inner_context, inner_line, inner_offset} | stack],
      inner_context,
      inner_line,
      inner_offset
    )
  end

  defp date_tokens__26(rest, acc, stack, context, line, offset) do
    date_tokens__27(rest, [], [acc | stack], context, line, offset)
  end

  defp date_tokens__27(<<x0, rest::binary>>, acc, stack, context, comb__line, comb__offset)
       when x0 === 9 or (x0 >= 32 and x0 <= 47) or (x0 >= 59 and x0 <= 64) or
              (x0 >= 91 and x0 <= 96) or
              (x0 >= 123 and x0 <= 126) do
    date_tokens__29(rest, acc, stack, context, comb__line, comb__offset + 1)
  end

  defp date_tokens__27(rest, acc, stack, context, line, offset) do
    date_tokens__28(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__29(rest, acc, stack, context, line, offset) do
    date_tokens__27(rest, acc, stack, context, line, offset)
  end

  defp date_tokens__28(rest, user_acc, [acc | stack], context, line, offset) do
    _ = user_acc
    date_tokens__30(rest, [] ++ acc, stack, context, line, offset)
  end

  defp date_tokens__30(rest, acc, _stack, context, line, offset) do
    {:ok, acc, rest, context, line, offset}
  end
end
