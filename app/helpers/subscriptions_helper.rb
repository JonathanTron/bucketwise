module SubscriptionsHelper
  def blank_slate?
    subscription.accounts.empty?
  end

  def balance_cell(container, options={})
    balance = real_balance = container.balance
    if container.respond_to?(:available_balance)
      balance = container.available_balance
    end

    classes = %w(number)
    classes += Array(options[:classes]) if options[:classes]
    classes << "negative" if balance < 0

    content = format_amount(balance)
    if real_balance != balance
      content = "<span class='real_balance'>(" << format_amount(real_balance) << ")</span> #{content}"
    end

    content_tag(options.fetch(:tag, "td"), content, :class => classes.join(" "), :id => options[:id])
  end

  def format_amount(amount)
    number_to_currency(amount.abs / 100.0)
  end
end
