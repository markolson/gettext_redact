defmodule GettextRedact do
  @moduledoc """
    All the marbles.
  """

  @eraser "█"
  # @redaction_skips [" ", "!", "-", ",", "."]
  @redaction_skips [" "]
  @interpolation_regex ~r/%\{[^}\s]+\}/

  @spec redact(Expo.Message.Singular.t()) :: Expo.Message.Singular.t()
  @spec redact(Expo.Message.Plural.t()) :: Expo.Message.Plural.t()
  @spec redact(String.t()) :: String.t()

  def redact(%Expo.Message.Singular{} = msg) do
    redact(msg.msgstr)
  end

  def redact(%Expo.Message.Plural{} = msg) do
    redact(msg.msgstr)
    # and more!
  end

  def redact(text) when is_binary(text) do
    get_spans(text)
    |> Enum.reduce([], fn span, acc -> [redact_span(span) | acc] end)
    |> Enum.reverse()
    |> Enum.join()
  end

  def redact_span({text, :keep}), do: text

  def redact_span({text, :replace}) do
    String.split(text, "", trim: true)
    |> Enum.map(fn char -> if skip_redacting?(char), do: char, else: erase() end)
    |> Enum.join("")
  end

  @type span() :: {open :: pos_integer(), close :: pos_integer(), stance :: :keep | :replace}
  @spec get_spans(text :: String.t()) :: [span()]

  def get_spans(text) do
    interpolated_ranges = Regex.scan(@interpolation_regex, text, return: :index)
    split_spans(text, interpolated_ranges) |> List.flatten() |> Enum.reverse()
  end

  @spec split_spans(
          text :: String.t(),
          interpolated_ranges :: list(),
          cursor :: pos_integer(),
          list[span()] | []
        ) :: list[span()]

  def split_spans(text, ranges, cursor \\ 0, acc \\ [])

  def split_spans(text, [], cursor, spans) do
    [end: cursor, l: String.length(text)]
    [[{String.slice(text, cursor, String.length(text) - cursor), :replace}] | spans]
  end

  def split_spans(text, [[{open, run}] | following_ranges], cursor, spans) do
    {cursor, open, run}
    replace = String.slice(text, cursor, open - cursor)
    keep = String.slice(text, open, run)

    split_spans(text, following_ranges, open + run, [[{keep, :keep}, {replace, :replace}] | spans])
  end

  @spec pot_path() :: String.t()
  defp pot_path do
    Application.get_env(:gettext_redact, :path, "priv/gettext")
  end

  @spec erase() :: char()
  defp erase do
    options = Application.get_env(:gettext_redact, :eraser, @eraser) |> List.wrap()

    case length(options) do
      1 -> hd(options)
      _ -> Enum.random(options)
    end
  end

  @spec skip_redacting?(char()) :: boolean()
  defp skip_redacting?(char) do
    char in List.wrap(Application.get_env(:gettext_redact, :skip, @redaction_skips))
  end
end
