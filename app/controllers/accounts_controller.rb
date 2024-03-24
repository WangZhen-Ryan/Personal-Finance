class AccountsController < ApplicationController
  before_action :authenticate_user!

  def new
    @account = Account.new(
      original_balance: nil,
      accountable: Accountable.from_type(params[:type])&.new
    )
  end

  def show
    @account = Current.family.accounts.find(params[:id])

    @period = Period.find_by_name(params[:period])
    if @period.nil?
      start_date = params[:start_date].presence&.to_date
      end_date = params[:end_date].presence&.to_date
      if start_date.is_a?(Date) && end_date.is_a?(Date) && start_date <= end_date
        @period = Period.new(name: "custom", date_range: start_date..end_date)
      else
        params[:period] = "last_30_days"
        @period = Period.find_by_name(params[:period])
      end
    end

    @balance_series = @account.balance_series(@period)
    @valuation_series = @account.valuation_series
  end

  def create
    @account = Current.family.accounts.build(account_params.except(:accountable_type))
    @account.accountable = Accountable.from_type(account_params[:accountable_type])&.new

    if @account.save
      redirect_to accounts_path, notice: t(".success")
    else
      render "new", status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:account).permit(:name, :accountable_type, :original_balance, :original_currency, :subtype)
  end


# new for dashboard

# Add a new action or modify an existing one
def net_worth_series
  @period = determine_period(params)

  # Aggregate balances from all accounts
  aggregated_balances = {}
  Current.family.accounts.each do |account|
    account_balances = account.balance_series(@period)[:series_data]
    account_balances.each do |entry|
      date = entry[:data].date.to_s
      aggregated_balances[date] ||= 0
      aggregated_balances[date] += entry[:data].balance
    end
  end

  # Convert to a series format for the chart
  @net_worth_series = aggregated_balances.map do |date, total_balance|
    { date: date, balance: total_balance }
  end.sort_by { |entry| entry[:date] }

  respond_to do |format|
    format.html
    format.json { render json: @net_worth_series }
  end
end

private

def determine_period(params)
  # Logic to determine the period based on params
end
end
