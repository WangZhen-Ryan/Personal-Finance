class Account < ApplicationRecord
  belongs_to :family
  has_many :balances, class_name: "AccountBalance"
  has_many :valuations

  delegated_type :accountable, types: Accountable::TYPES, dependent: :destroy

  delegate :type_name, to: :accountable
  before_create :check_currency

  def balance_series(period)
    filtered_balances = balances.in_period(period).order(:date)
    return nil if filtered_balances.empty?

    series_data = [ nil, *filtered_balances ].each_cons(2).map do |previous, current|
      trend = current&.trend(previous)
      { data: current, trend: { amount: trend&.amount, direction: trend&.direction, percent: trend&.percent } }
    end

    last_balance = series_data.last[:data]

    {
      series_data: series_data,
      last_balance: last_balance.balance,
      trend: last_balance.trend(series_data.first[:data])
    }
  end

  def valuation_series
    series_data = [ nil, *valuations.order(:date) ].each_cons(2).map do |previous, current|
      { value: current, trend: current&.trend(previous) }
    end

    series_data.reverse_each
  end

    # new for dashboard
    # Class method to calculate net worth series for a family or user grouping
    def self.net_worth_series(family, period)
      accounts = family.accounts.includes(:balances)
      net_worth_by_date = {}

      accounts.each do |account|
        account_balances = account.balance_series(period)
        next if account_balances.nil?

        account_balances[:series_data].each do |entry|
          date = entry[:data].date
          balance = entry[:data].balance
          net_worth_by_date[date] ||= 0
          net_worth_by_date[date] += balance
        end
      end

      # Convert hash to series format expected by the front end
      net_worth_by_date.map do |date, total_balance|
        { date: date, balance: total_balance }
      end.sort_by { |entry| entry[:date] }
    end



  def check_currency
    if self.original_currency == self.family.currency
      self.converted_balance = self.original_balance
      self.converted_currency = self.original_currency
    else
      self.converted_balance = ExchangeRate.convert(self.original_currency, self.family.currency, self.original_balance)
      self.converted_currency = self.family.currency
    end
  end
end
