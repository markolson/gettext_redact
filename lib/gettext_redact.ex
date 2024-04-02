defmodule GettextRedact do
  @moduledoc """
    All the marbles.
  """

  @eraser "█"
  @redaction_skips [" ", "!", "-", ",", ".", "<"]
  # @redaction_skips [" "]
  @interpolation_regex ~r/%\{[^}\s]+\}/
  @locale "rr"

  @spec redact(Expo.Messages.t()) :: Expo.Messages.t()
  @spec redact(Expo.Message.Singular.t()) :: Expo.Message.Singular.t()
  @spec redact(Expo.Message.Plural.t()) :: Expo.Message.Plural.t()
  @spec redact(list(String.t())) :: [String.t()]
  # TODO - tighten up
  @spec redact(map()) :: map()

  def run(_opts \\ []) do
    pots()
    |> Enum.map(&read_pot/1)
    |> Enum.map(fn {po_name, contents} ->
      redact(contents) |> write_po(po_name)
    end)

    :ok
  end

  def redact(%Expo.Messages{messages: m} = po_contents) do
    %Expo.Messages{po_contents | messages: Enum.map(m, &redact/1)}
  end

  def redact(%Expo.Message.Singular{} = msg) do
    Map.put(msg, :msgstr, redact(msg.msgid))
  end

  def redact(%Expo.Message.Plural{} = msg) do
    msg
  end

  def redact([text]) when is_binary(text), do: get_redacted_text(text)

  def redact(plurals) when is_map(plurals) do
    # call redact([text])
    plurals
  end

  @spec do_redact(String.t()) :: [String.t()]
  def do_redact(text) do
    String.split(text, "", trim: true)
    |> Enum.map_join("", fn char -> if skip_redacting?(char), do: char, else: erase(char) end)
  end

  @spec get_redacted_text(text :: String.t()) :: [String.t()]
  def get_redacted_text(text) do
    interpolated_ranges = Regex.scan(@interpolation_regex, text, return: :index)

    split_spans(text, interpolated_ranges)
    |> List.flatten()
    |> Enum.reverse()
    |> Enum.join()
    |> List.wrap()
  end

  @spec split_spans(
          text :: String.t(),
          interpolated_ranges :: list(),
          cursor :: pos_integer(),
          list[String.t()] | []
        ) :: list[String.t()]

  def split_spans(text, ranges, cursor \\ 0, acc \\ [])

  def split_spans(text, [], cursor, spans) do
    [do_redact(String.slice(text, cursor, String.length(text) - cursor)) | spans]
  end

  def split_spans(text, [[{open, run}] | following_ranges], cursor, spans) do
    replace = String.slice(text, cursor, open - cursor)
    keep = String.slice(text, open, run)

    split_spans(text, following_ranges, open + run, [[keep, do_redact(replace)] | spans])
  end

  @spec read_pot(Path.t()) :: {String.t(), Expo.Messages.t()}
  def read_pot(path), do: {Path.basename(path, ".pot"), Expo.PO.parse_file!(path)}

  @spec write_po(Expo.PO.t(), Path.t()) :: boolean()
  def write_po(po_contents, pot_name) do
    write_dir = Path.join(path(), lang())
    unless File.dir?(write_dir), do: File.mkdir(write_dir)

    Expo.PO.compose(po_contents)
    |> then(&File.write!(Path.join(write_dir, pot_name <> ".po"), &1))
  end

  @spec erase(any()) :: char()
  defp erase(_nothing_yet) do
    options = Application.get_env(:gettext_redact, :eraser, @eraser) |> List.wrap()

    case length(options) do
      1 -> hd(options)
      _ -> Enum.random(options)
    end
  end

  defp skip_redacting?(char) do
    char in List.wrap(Application.get_env(:gettext_redact, :skip, @redaction_skips))
  end

  def pots() do
    path()
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".pot"))
    |> Enum.map(&Path.join(path(), &1))
  end

  defp path, do: Application.get_env(:gettext_redact, :path, "test/fixtures/gettext")
  defp lang, do: Application.get_env(:gettext_redact, :lang, @locale)
end
