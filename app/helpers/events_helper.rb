module EventsHelper
  def emit_account_data_assignments
    update_page do |page|
      page.events.accounts = accounts_with_buckets
      page.events.tags     = subscription.tags(:reload).map(&:name).sort
      page.events.actors   = subscription.actors(:reload).sort_by(&:sort_name).map(&:name)
    end
  end

  def accounts_with_buckets
    # This rule is so that standard buckets (like "aside") that have not
    # yet been created get sorted to the bottom. Until they're "real" they
    # are second-class citizens, but we still want to let people select them
    # if they need them.

    sorter = Proc.new do |bucket|
      [Integer === bucket.id ? 0 : 1, bucket.name.downcase]
    end

    subscription.accounts.inject({}) do |hash, account|
      buckets = account.buckets.with_defaults.sort_by(&sorter).map do |bucket|
        { :id => bucket.id, :name => bucket.name,
          :role => bucket.role, :balance => bucket.balance }
      end

      hash[account.id] = { :id => account.id, :name => account.name,
        :role => account.role, :buckets => buckets }
      hash
    end
  end

  def links_to_accounts_for_event(event)
    links = event.account_items.map do |item|
      link_to(h(item.account.name), item.account)
    end

    links.join(", ")
  end

  def form_sections
    %w(payment_source
       credit_options
       deposit
       transfer_from
       transfer_to
       reallocate_from
       reallocate_to
       tags)
  end

  def select_account(section, accounts, selection)
    select_tag "event[#{section}][account_id]", 
      options_for_select(
        (selection ? [] : [["", ""]]) +
          accounts.map { |acct| [acct.name, acct.id] },
        selection),
      :id => "account_for_#{section}",
      :onchange => "Events.handleAccountChange(this, '#{section}')"
  end

  def select_bucket(section, options={})
    splittable = options.fetch(:splittable, true)

    if options[:line_item]
      select_options = options_for_select(
        options[:line_item].account.buckets.sorted.map { |bucket| [bucket.name, bucket.id] },
        options[:line_item].bucket_id)
      select_options += "<option value='+'>#{I18n.t(:"helpers.events.more_than_one")}</option>" if splittable
      select_options += "<option value='++'>#{I18n.t(:"helpers.events.add_new_bucket")}</option>"
      disabled = false
    else
      select_options = "<option>#{I18n.t(:"helpers.events.select_an_account")}</option>"
      disabled = true
    end

    classes = ["bucket_for_#{section}", splittable ? "splittable" : nil]

    select_tag "event[#{section}][bucket_id]", select_options,
      :class => classes.compact.join(" "),
      :disabled => disabled,
      :onchange => "Events.handleBucketChange(this, '#{section}')"
  end

  def event_for_form
    @event || Event.new(:occurred_on => Date.today)
  end

  def event_form_source
    action_name == "new" ? "new" : nil
  end

  def event_form_action
    if @event.nil? || @event.new_record?
      subscription_events_path(subscription, :source => event_form_source)
    else
      update_event_path(@event)
    end
  end

  def event_amount_value
    if @event
      if @event.role == :transfer
        balance = @event.account_items.map { |a| a.amount.abs }.max
      else
        balance = @event.balance.abs
      end

      "%.2f" % (balance / 100.0)
    else
      ""
    end
  end

  def line_item_amount_value(item)
    if item && item.amount
      "%.2f" % (item.amount.abs / 100.0)
    else
      ""
    end
  end

  def tagged_item_name_value(item)
    if item
      item.tag.name
    else
      ""
    end
  end

  def tagged_item_amount_value(item)
    if item
      "%.2f" % (item.amount.abs / 100.0)
    else
      ""
    end
  end

  def tag_list_for_event
    if @event
      @event.tagged_items.whole.map(&:tag).map(&:name).sort.join(", ")
    else
      ""
    end
  end

  def section_wants_check_options?(section)
    case section
    when :payment_source, :transfer_from, :deposit
      true
    else
      false
    end
  end

  def section_wants_repayment_options?(section)
    section == :payment_source
  end

  def event_wants_memo?
    @event && @event.memo.present?
  end

  def event_wants_section?(section)
    return true unless @event

    section = section.to_sym
    return true if section == :tags

    case section
    when :general_information then
      return @event.role != :reallocation
    when :payment_source, :credit_options then
      return @event.role == :expense
    when :deposit then
      return @event.role == :deposit
    when :transfer_from, :transfer_to then
      return @event.role == :transfer
    when :reallocate_from, :reallocate_to
      return @event.role == :reallocation &&
        @event.line_items.any? { |item| item.role.to_sym == section }
    end

    return false
  end

  def event_has_tags?
    @event && @event.tagged_items.any?
  end

  def event_has_partial_tags?
    @event && @event.tagged_items.partial.any?
  end

  def section_visible_for_event?(section)
    return true unless @event

    if @event.role == :expense && section == :credit_options
      return @event.line_items.for_role(:credit_options).any?
    end

    return true
  end

  def check_options_visible_for?(section)
    @event && @event.account_for(section).checking?
  end

  def repayment_options_visible_for?(section)
    @event && section == :payment_source &&
      @event.account_for(:payment_source).credit_card? &&
      @event.line_items.for_role('credit_options').empty?
  end

  def section_has_single_bucket?(section)
    return false if @event && @event.line_items.for_role(section).length > 1
    return true
  end

  def multi_bucket_visibility_for(section)
    return nil if @event && @event.line_items.for_role(section).length > 1
    return "display: none;"
  end

  def for_each_line_item_in(section)
    (@event && @event.line_items.for_role(section) || []).each do |item|
      yield item
    end
  end

  def for_each_partial_tagged_item
    (@event && @event.tagged_items.partial || []).each do |item|
      yield item
    end
  end

  def line_item_for_section(section)
    @event && @event.line_items.for_role(section).first
  end

  def account_id_for_section(section)
    @event && @event.line_items.for_role(section).first.account_id
  end

  def bucket_action_phrase_for(section)
    case section.to_sym
    when :payment_source
      I18n.t(:"helpers.events.was_drown_from")
    when :credit_options
      I18n.t(:"helpers.events.will_be_repaid_from")
    when :deposit
      I18n.t(:"helpers.events.was_deposited_to")
    when :transfer_from
      I18n.t(:"helpers.events.was_transferred_from")
    when :transfer_to
      I18n.t(:"helpers.events.was_transferred_to")
    else raise ArgumentError, "unsupported form section: #{section.inspect}"
    end
  end

  FORM_SECTIONS = {
    :deposit => {
      :title                => I18n.t(:"helpers.events.deposit_information"),
      :account_prompt       => I18n.t(:"helpers.events.which_account_was_this_deposited_to"),
      :single_bucket_prompt => I18n.t(:"helpers.events.which_bucket_was_this_deposited_to"),
      :multi_bucket_prompt  => I18n.t(:"helpers.events.this_deposit_was_to_multiple_buckets"),
    },
    :credit_options => {
      :title                => I18n.t(:"helpers.events.repayment_options"),
      :account_prompt       => I18n.t(:"helpers.events.which_account_will_be_used_to_repay_this_credit"),
      :single_bucket_prompt => I18n.t(:"helpers.events.which_bucket_will_be_used_to_repay_this_credit"),
      :multi_bucket_prompt  => I18n.t(:"helpers.events.multiple_buckets_will_be_used_to_repay_this_credit"),
    },
    :payment_source => {
      :title                => I18n.t(:"helpers.events.payment_source"),
      :account_prompt       => I18n.t(:"helpers.events.which_account_was_this_drawn_from"),
      :single_bucket_prompt => I18n.t(:"helpers.events.which_bucket_was_this_drawn_from"),
      :multi_bucket_prompt  => I18n.t(:"helpers.events.this_expense_drew_from_multiple_buckets")
    },
    :transfer_from => {
      :title                => I18n.t(:"helpers.events.transfer_source"),
      :account_prompt       => I18n.t(:"helpers.events.which_account_were_funds_transferred_from"),
      :single_bucket_prompt => I18n.t(:"helpers.events.which_bucket_were_funds_transferred_from"),
      :multi_bucket_prompt  => I18n.t(:"helpers.events.this_transfer_pulled_from_multiple_buckets")
    },
    :transfer_to => {
      :title                => I18n.t(:"helpers.events.transfer_destination"),
      :account_prompt       => I18n.t(:"helpers.events.which_account_were_fund_transferred_to"),
      :single_bucket_prompt => I18n.t(:"helpers.events.which_bucket_were_fund_transferred_to"),
      :multi_bucket_prompt  => I18n.t(:"helpers.events.this_transfer_targeted_multiple_buckets")
    }
  }

  def render_event_form_section(form, section)
    section = section.to_sym

    case section
    when :tags then
      render :partial => "events/form_tags", :locals => { :form => form }

    when :reallocate_from, :reallocate_to then
      render :partial => "events/form_reallocate",
        :locals => { :form => form, :section => section }

    else
      accounts = subscription.accounts
      accounts = accounts.select { |a| a.role == "checking" } if section == :credit_options

      values = { :section          => section,
                 :form             => form,
                 :accounts         => accounts,
                 :selected_account => form.object && form.object.account_for(section) }

      render :partial => "events/form_section",
             :locals => FORM_SECTIONS[section].merge(values)
    end
  end

  def tag_links_for(event)
    event.tags.sort_by(&:name).map { |tag| link_to(h(tag.name), tag_path(tag)) }.join(", ")
  end

  def tag_entry_field(name, value, options={})
    completer_opts = {}
    completer_opts[:tokens] = "," if options.delete(:multiple)

    tag_field = text_field_tag(name, value, options)
    dropdown = content_tag(:div, "", :style => "display: none", :class => "autocomplete_select", :id => "#{options[:id]}_select")

    tag_field + dropdown
  end

  def reallocation_verbs_for(section)
    case section.to_sym
    when :reallocate_to   then [I18n.t(:"to"), I18n.t(:"from")]
    when :reallocate_from then [I18n.t(:"from"), I18n.t(:"to")]
    else
      raise ArgumentError, "unsupported section #{section.inspect} for reallocation_verbs_for"
    end
  end

  def template_partial_for(section)
    case section
    when "tags" then "events/tagged_item"
    when "reallocate_from", "reallocate_to" then "events/reallocation_item"
    else "events/line_item"
    end
  end
end
