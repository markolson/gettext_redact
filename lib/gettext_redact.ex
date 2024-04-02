defmodule GettextRedact do
  @doc "Erase your gettext"
  @eraser "█"
  @redaction_skips [" ", "!", "-", ",", "."]
  @interpolation_regex ~r/%\{[^}\s]+\}/

  @spec redact(%Expo.Message.Singular{}) :: %Expo.Message.Singular{}
  @spec redact(%Expo.Message.Plural{}) :: %Expo.Message.Plural{}
  @spec redact(String.t()) :: String.t()

  def redact(%Expo.Message.Singular{} = msg) do
    redact(msg.msgstr)
  end

  def redact(%Expo.Message.Plural{} = msg) do
    redact(msg.msgstr)
    # and more!
  end

  def redact(text) when is_binary(text) do
    String.split(text, "", trim: true)
    |> Enum.reduce([], fn char, acc ->
      char = if skip_redacting?(char), do: char, else: erase()
      [char | acc]
    end)
    |> Enum.reverse()
    |> Enum.join()
  end

  @type span() :: {Range.t(), :keep | :replace}
  @spec get_spans(String.t()) :: [span()]

  def get_spans(text) do
    interpolated_ranges = Regex.scan(@interpolation_regex, text, return: :index)
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
