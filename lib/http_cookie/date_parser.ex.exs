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

  # parsec:HttpCookie.DateParser
  import NimbleParsec

  defmodule Helpers do
    def any_case_string(string) do
      string
      |> String.downcase()
      |> String.to_charlist()
      |> Enum.reverse()
      |> char_piper()
      |> reduce({List, :to_string, []})
    end

    defp char_piper([c]) when c in ?a..?z do
      ascii_char(both_cases(c))
    end

    defp char_piper([c | rest]) when c in ?a..?z do
      rest
      |> char_piper()
      |> ascii_char(both_cases(c))
    end

    defp char_piper([c]) do
      ascii_char([c])
    end

    defp char_piper([c | rest]) do
      rest
      |> char_piper()
      |> ascii_char([c])
    end

    defp both_cases(c) do
      [c, c - 32]
    end
  end

  octet = ascii_char([0x00..0xFF])

  # delimiter = %x09 / %x20-2F / %x3B-40 / %x5B-60 / %x7B-7E
  delimiter = ascii_char([0x09, 0x20..0x2F, 0x3B..0x40, 0x5B..0x60, 0x7B..0x7E])

  # non-delimiter = %x00-08 / %x0A-1F / DIGIT / ":" / ALPHA / %x7F-FF
  non_delimiter = ascii_char([0x00..0x08, 0x0A..0x1F, ?0..?9, ?:..?:, ?a..?z, ?A..?Z, 0x7F..0xFF])

  # non-digit = %x00-2F / %x3A-FF
  non_digit = ascii_char([0x00..0x2F, 0x3A..0xFF])

  # date-token = 1*non-delimiter
  date_token =
    times(non_delimiter, min: 1)
    |> reduce({List, :to_string, []})
    |> unwrap_and_tag(:date_token)

  delimiter_date_token = ignore(times(delimiter, min: 1)) |> concat(date_token)

  # date-token-list = date-token *( 1*delimiter date-token )
  date_token_list = date_token |> concat(repeat(delimiter_date_token))

  # cookie-date = *delimiter date-token-list *delimiter
  defparsecp :date_tokens,
             ignore(repeat(delimiter))
             |> concat(date_token_list)
             |> concat(ignore(repeat(delimiter)))

  # time-field = 1*2DIGIT
  time_field = integer(min: 1, max: 2)

  # https://www.rfc-editor.org/errata/eid4148
  end_time = optional(non_digit |> concat(repeat(octet)))

  # hms-time = time-field ":" time-field ":" time-field
  hms_time =
    time_field
    |> ignore(ascii_char([?:]))
    |> concat(time_field)
    |> ignore(ascii_char([?:]))
    |> concat(time_field)

  # time = hms-time ( non-digit *OCTET )
  defparsecp :time,
             hms_time
             |> label(~s([H]H:[M]M:[S]S))
             |> concat(ignore(end_time))

  # year = 2*4DIGIT ( non-digit *OCTET )
  defparsecp :year,
             integer(min: 2, max: 4)
             |> label(~s(yy/YYYY))
             |> concat(ignore(end_time))

  # day-of-month = 1*2DIGIT ( non-digit *OCTET )
  defparsecp :day_of_month,
             integer(min: 1, max: 2)
             |> label(~s([d]d))
             |> concat(ignore(end_time))

  # month = ( "jan" / "feb" / "mar" / "apr" /
  #           "may" / "jun" / "jul" / "aug" /
  #           "sep" / "oct" / "nov" / "dec" ) *OCTET
  defparsecp :month,
             choice([
               Helpers.any_case_string("jan") |> replace(1),
               Helpers.any_case_string("feb") |> replace(2),
               Helpers.any_case_string("mar") |> replace(3),
               Helpers.any_case_string("apr") |> replace(4),
               Helpers.any_case_string("may") |> replace(5),
               Helpers.any_case_string("jun") |> replace(6),
               Helpers.any_case_string("jul") |> replace(7),
               Helpers.any_case_string("aug") |> replace(8),
               Helpers.any_case_string("sep") |> replace(9),
               Helpers.any_case_string("oct") |> replace(10),
               Helpers.any_case_string("nov") |> replace(11),
               Helpers.any_case_string("dec") |> replace(12)
             ])
             |> label(~s(jan/feb/mar/apr/may/jun/jul/aug/sep/oct/nov/dec))
             |> concat(ignore(repeat(octet)))

  # parsec:HttpCookie.DateParser
end
