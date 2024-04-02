defmodule GettextRedact do
  @doc "Erase your gettext"

  def process_string(%Expo.Message.Singular{} = msg) do
    text = redact(msg.msgstr)
  end

  def process_string(%Expo.Message.Plural{} = msg) do
    msg
  end

  # Going to need to make string slices for interpolations
  # and re-join at the end. For now just wipe it all.

  def redact(text) do
    String.split(text, "", trim: true)
    |> Enum.reduce([], fn char, acc ->
      char = if skip_redacting?(char), do: char, else: erase()
      [char | acc]
    end)
    |> IO.inspect()
    |> Enum.reverse()
    |> Enum.join()
  end

  defp pot_path do
    Application.get_env(:gettext_redact, :path, ["priv/gettext"])
  end

  defp erase do
    options = Application.get_env(:gettext_redact, :eraser, "█") |> List.wrap()

    case length(options) do
      1 -> hd(options)
      _ -> Enum.random(options)
    end
  end

  defp skip_redacting?(char) do
    char in List.wrap(Application.get_env(:gettext_redact, :skip, [" ", ", ", "!"]))
  end
end
