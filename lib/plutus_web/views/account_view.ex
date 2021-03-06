defmodule PlutusWeb.AccountView do
  use PlutusWeb, :view

  def render("update_balances.json", %{}) do
    %{
      message: "balances updated"
    }
  end

  def render("link_token.json", %{link_token: link_token}) do
    %{
      message: "link token created",
      linkToken: link_token
    }
  end

  def render("account_created.json", %{account: account}) do
    %{
      message: "account created",
      account: %{
        id: account.id,
        description: account.description,
        remote_id: account.remote_id,
        balance: account.balance,
        last_refreshed: account.last_refreshed,
        account_name: account.account_name,
        balance_to_maintain: account.balance_to_maintain,
        type: account.type,
        include_in_overall: account.include_in_overall
      }
    }
  end

  def render("account_updated.json", %{account: account}) do
    %{
      message: "account updated",
      account: %{
        id: account.id,
        description: account.description,
        remote_id: account.remote_id,
        balance: account.balance,
        last_refreshed: account.last_refreshed,
        account_name: account.account_name,
        balance_to_maintain: account.balance_to_maintain,
        type: account.type,
        include_in_overall: account.include_in_overall
      }
    }
  end

  def render("account_update_required.json", _) do
    %{
      message: "plaid update required",
      type: "UPDATE_REQUIRED"
    }
  end

  def render("bad_request.json", %{message: message}) do
    %{
      message: message
    }
  end

  def render("account.json", %{account: account}) do
    %{
      message: "account get success",
      account: %{
        id: account.id,
        description: account.description,
        remote_id: account.remote_id,
        balance: account.balance,
        computed_balance: account.computed_balance,
        computed_expenses: account.computed_expenses,
        last_refreshed: account.last_refreshed,
        account_name: account.account_name,
        balance_to_maintain: account.balance_to_maintain,
        type: account.type,
        include_in_overall: account.include_in_overall
      }
    }
  end

  def render("accounts.json", %{accounts: accounts}) do
    rendered_accounts = accounts
    |> Enum.map(fn account -> 
      %{
        id: account.id,
        description: account.description,
        remote_id: account.remote_id,
        balance: account.balance,
        computed_balance: account.computed_balance,
        computed_expenses: account.computed_expenses,
        last_refreshed: account.last_refreshed,
        account_name: account.account_name,
        balance_to_maintain: account.balance_to_maintain,
        type: account.type,
        include_in_overall: account.include_in_overall
      }
    end)

    %{
      message: "accounts get success",
      accounts: rendered_accounts
    }
  end
end