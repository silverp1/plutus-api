defmodule Plutus.Worker.PrecomputeWorker do
  use GenServer

  alias Plutus.Model.{Account,Income,Expense,Event}
  alias Plutus.Types.Precompute
  alias Plutus.Common.Date, as: PDate
  alias Plutus.Common.Utilities

  require Logger

  @precompute_months 3
  @interval 604_800_000 # 1 week

  def start_link() do
    GenServer.start_link(
      __MODULE__,
      nil,
      name: :precompute_worker
    )
  end

  def init(_) do
    Logger.info("#{__MODULE__}: Initializing genserver for precompute processing")
    Process.send_after(self(), :precompute, 1_000)
    precompute_struct = Precompute.build(%{last_run: DateTime.utc_now()})
    {:ok, precompute_struct}
  end

  def handle_info(:precompute, precompute_struct) do
    Logger.info("#{__MODULE__}: Starting precompute now")
    valid_accounts = Account.get_all_accounts() 
    |> Utilities.filter_valid_accounts()
    :ok = do_precompute(valid_accounts)
    precompute_struct = precompute_struct |> Precompute.set_last_precompute_now
    Process.send_after(self(), :precompute, @interval)
    {:noreply, precompute_struct}
  end

  def do_precompute(accounts) do
    accounts
    |> Enum.map(fn account ->
      {:ok, incomes} = Income.get_all_income_for_account(account.id)
      process_income(account, incomes)
    end)
    :ok
  end

  def process_income(account, incomes) do
    precompute_date = PDate.get_current_date()
    incomes
    |> Enum.map(fn income -> 
      # for each income instance, make an event for each month
      # in precompute window
      if income.recurring == true do
        Logger.info("#{__MODULE__}: Income #{inspect(income.id)} is recurring, precomputing out")
        Enum.each(0..@precompute_months, fn index -> 
          {:ok, model} = Event.maybe_insert(%{
            amount: income.amount,
            description: income.description,
            target_id: income.id,
            type: :income,
            precompute_date: precompute_date,
            anticipated_date: get_anticipated_date(income, index),
            parent_id: income.id,
            account_id: income.account_id
          })
          process_expense(model)
          end)
        else
          Logger.info("#{__MODULE__}: Income #{inspect(income.id)} is not recurring, examining further")
          if in_same_month?(income) do
            Logger.info("#{__MODULE__}: Income #{inspect(income.id)} is not recurring, but precomputing for expected month")
            {:ok, model} = Event.maybe_insert(%{
              amount: income.amount,
              description: income.description,
              target_id: income.id,
              type: :income,
              precompute_date: precompute_date,
              anticipated_date: get_anticipated_date(income, 0),
              parent_id: income.id,
              account_id: income.account_id
            })
            process_expense(model)
          else
            Logger.info("#{__MODULE__}: Income #{inspect(income.id)} is not recurring and precomputing for unexpected month, skipping")
          end
        end
    end)
  end

  def process_expense(%{anticipated_date: anticipated_date, account_id: account_id, target_id: id, id: parent_id, precompute_date: precompute_date} = _model) do
    {:ok, expenses} = Expense.get_all_expenses_for_income(id)
    expenses
    |> Enum.map(fn expense ->
        if expense.recurring == true do
          Logger.info("#{__MODULE__}: Expense #{inspect(expense.id)} is recurring, precomputing out")
          {:ok, model} = Event.maybe_insert(%{
            amount: expense.amount,
            description: expense.description,
            target_id: expense.id,
            type: :expense,
            precompute_date: precompute_date,
            anticipated_date: anticipated_date,
            parent_id: parent_id,
            account_id: account_id,
            transaction_description: expense.transaction_description,
          })
        else
          Logger.info("#{__MODULE__}: Expense #{inspect(expense.id)} is not recurring, examining further")
          if in_same_month?(expense) do
            Logger.info("#{__MODULE__}: Expense #{inspect(expense.id)} is not recurring, but precomputing for expected month")
            {:ok, model} = Event.maybe_insert(%{
              amount: expense.amount,
              description: expense.description,
              target_id: expense.id,
              type: :expense,
              precompute_date: precompute_date,
              anticipated_date: anticipated_date,
              parent_id: parent_id,
              account_id: account_id,
              transaction_description: expense.transaction_description
            })            
          else
            Logger.info("#{__MODULE__}: Expense #{inspect(expense.id)} is not recurring and precomputing for unexpected month, skipping")
          end
        end
      end)
  end

  def get_anticipated_date(income, index) do
    # first create a naive date time from current year + month + day of month in income
    # then shift that however many months in the future that we are looking to precompute for
    date = if income.day_of_month == 99 do
      date = PDate.assemble_date_from_day_of_month(1)
      |> PDate.shift_months(index)
      |> PDate.end_of_month
      |> PDate.shift_to_earliest_business_day
    else
      date = PDate.assemble_date_from_day_of_month(income.day_of_month)
      |> PDate.shift_months(index)
    end
    # now we need to look to see if the given date is a bank holiday
    # if it is, start iterating backwards until it finds the next non-holiday business day
    case PDate.is_bank_holiday?(date) do
      true ->
        PDate.find_next_earliest_business_day(date)
      false ->
        date
    end

  end

  def adhoc_precompute() do
    valid_accounts = Account.get_all_accounts() 
    |> Utilities.filter_valid_accounts()
    :ok = do_precompute(valid_accounts)  
  end

  def in_same_month?(%Income{month: income_month} = _income) do
    {_year, current_month, _day} = PDate.get_current_date
    |> PDate.format_date()

    income_month == current_month   
  end

  def in_same_month?(%Expense{month: expense_month} = _expense) do
    {_year, current_month, _day} = PDate.get_current_date
    |> PDate.format_date()

    expense_month == current_month
  end
end