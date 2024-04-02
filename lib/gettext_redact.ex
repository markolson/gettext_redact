defmodule GettextRedact do
  @moduledoc """
    All the marbles.
  """

  @eraser "█"
  # @redaction_skips [" ", "!", "-", ",", "."]
  @redaction_skips [" "]
  @interpolation_regex ~r/%\{[^}\s]+\}/

  # @type span() :: {stance :: :keep | :replace, open :: pos_integer(), close :: pos_integer()}
  @type span() :: {stance :: :keep | :replace, text :: String.t()}

  @spec redact(Expo.Messages.t()) :: Expo.Messages.t()
  @spec redact(Expo.Message.Singular.t()) :: Expo.Message.Singular.t()
  @spec redact(Expo.Message.Plural.t()) :: Expo.Message.Plural.t()
  @spec redact(list(String.t())) :: [String.t()]
  # TODO - tighten up
  @spec redact(map()) :: map()

  def redact(%Expo.Messages{messages: m} = po_contents) do
    Map.put(po_contents, :messages, Enum.map(m, &redact/1))
  end

  def redact(%Expo.Message.Singular{} = msg) do
    Map.put(msg, :msgstr, redact(msg.msgid))
  end

  def redact(%Expo.Message.Plural{} = msg) do
    msg
  end

  def redact([text]) when is_binary(text) do
    get_spans(text)
    |> Enum.reduce([], fn span, acc -> [redact_span(span) | acc] end)
    |> Enum.reverse()
    |> Enum.join()
    |> List.wrap()
  end

  def redact(plurals) when is_map(plurals) do
    plurals
  end

  def redact_span({:keep, text}), do: text

  def redact_span({:replace, text}) do
    String.split(text, "", trim: true)
    |> Enum.map_join("", fn char -> if skip_redacting?(char), do: char, else: erase() end)
  end

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
    [[{:replace, String.slice(text, cursor, String.length(text) - cursor)}] | spans]
  end

  def split_spans(text, [[{open, run}] | following_ranges], cursor, spans) do
    {cursor, open, run}
    replace = String.slice(text, cursor, open - cursor)
    keep = String.slice(text, open, run)

    split_spans(text, following_ranges, open + run, [[{:keep, keep}, {:replace, replace}] | spans])
  end

  @spec read_po(Path.t()) :: Expo.Messages.t()
  def read_po(path) do
    Expo.PO.parse_file!(path)
  end

  @spec write_po(Expo.PO.t(), Path.t()) :: boolean()
  def write_po(po_contents, path) do
    po_contents |> Expo.PO.compose() |> then(&File.write!(path, &1))
  end

  @spec pot_path() :: String.t()
  defp pot_path do
    Application.get_env(:gettext_redact, :path, "priv/gettext")
  end

  @spec lang() :: String.t()
  defp lang do
    Application.get_env(:gettext_redact, :lang, "redacted")
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
