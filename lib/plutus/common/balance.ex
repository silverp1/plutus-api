defmodule Plutus.Common.Balance do
  alias Plutus.Model.Event
  alias Plutus.Common.Date, as: PDate

  require Logger

  def compute_balance(%{balance: balance, id: id} = account) do
    {:ok, current_income} = Event.get_current_income_event(id)
    if is_nil(current_income) do
      Logger.warn("#{__MODULE__}: Found no current income when calculating balance for #{id}")
      {balance, []}
    else
      {:ok, expenses} = Event.get_expenses_for_income(current_income.id)
      computed_balance = expenses
      |> Enum.reduce(balance, fn e, acc -> 
        acc - e.amount
      end)
      {computed_balance, expenses}
    end
  end

  def add_computed_values(model) do
    {updated_balance, expenses} = compute_balance(model)
    |> potentially_subtract_balance_to_maintain(model)
    updated_model = model
    |> Map.put(:computed_balance, updated_balance)
    |> Map.put(:computed_expenses, expenses |> parse_expenses)
    {:ok, updated_model}
  end

  def parse_expenses(models) do
    models 
    |> Enum.map(fn event ->
      %{
        id: event.id,
        description: event.description,
        amount: event.amount,
        type: event.type,
        settled: event.settled,
        anticipated_date: event.anticipated_date,
        parent_id: event.parent_id
      }
    end)
  end

  def potentially_subtract_balance_to_maintain({computed_balance, expenses}, account) do
    case is_nil(Map.get(account, :balance_to_maintain, nil)) do
      true ->
        {computed_balance, expenses}
      false ->
        {computed_balance - account.balance_to_maintain, expenses}
    end
  end
end