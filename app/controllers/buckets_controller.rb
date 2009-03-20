class BucketsController < ApplicationController
  before_filter :find_account, :only => :index
  before_filter :find_bucket, :only => :show

  def index
  end

  def show
    @page = (params[:page] || 0).to_i
    @more_pages, @items = bucket.line_items.page(@page)
  end

  protected

    attr_reader :account, :bucket
    helper_method :account, :bucket

    def find_account
      @account = Account.find(params[:account_id])
      @subscription = user.subscriptions.find(@account.subscription_id)
    end

    def find_bucket
      @bucket = Bucket.find(params[:id])
      @account = @bucket.account
      @subscription = user.subscriptions.find(@account.subscription_id)
    end

    def current_location
      if bucket
        "buckets/%d" % bucket.id
      else
        super
      end
    end
end