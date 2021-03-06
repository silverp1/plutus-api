defmodule PlutusWeb.Params.IncomeId do
  use Ecto.Type
  
  alias Plutus.Model.Income

  def type, do: :integer

  def cast(id) when is_integer(id) do
    get_income(id)
  end

  def cast(id) when is_binary(id) do
    {parsed_id, _} = Integer.parse(id)
    get_income(parsed_id)
  end

  def cast(_), do: :error

  # Used for loading into storage
  def load(id), do: id

  # Dumping transform to raw format (i.e. obfuscated)
  def dump(id), do: id

  defp get_income(id) do
    case Income.get_by_id(id) do
      {:ok, _income} ->
        {:ok, id}
      _ ->
        :error
    end 
  end
end