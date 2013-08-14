# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require 'new_relic/agent/browser_token'

module NewRelic
  module Agent

    # This is THE location to store thread local information during a transaction
    # Need a new piece of data? Add a method here, NOT a new thread local variable.
    class TransactionState

      def self.get
        state_for(Thread.current)
      end

      # This method should only be used by TransactionState for access to the
      # current thread's state or to provide read-only accessors for other threads
      #
      # If ever exposed, this requires additional synchronization
      def self.state_for(thread)
        thread[:newrelic_transaction_state] ||= TransactionState.new
      end
      private_class_method :state_for

      def self.clear
        Thread.current[:newrelic_transaction_state] = nil
      end

      # This starts the timer for the transaction.
      def self.reset(request=nil)
        self.get.reset(request)
      end

      def reset(request)
        @transaction_start_time = Time.now
        @transaction = Transaction.current

        @request = request
        @request_token = BrowserToken.get_token(request)
        @request_guid = ""
        @request_ignore_enduser = false
      end

      # Cross app tracing
      # Because we need values from headers before the transaction actually starts
      attr_accessor :client_cross_app_id, :referring_transaction_info

      # Request data
      attr_accessor :request, :request_token, :request_guid, :request_ignore_enduser

      # Current transaction stack and sample building
      attr_accessor :transaction, :transaction_start_time, :transaction_sample_builder
      attr_writer   :current_transaction_stack

      # Returns and initializes the transaction stack if necessary
      #
      # We don't default in the initializer so non-transaction threads retain
      # a nil stack, and methods in this class use has_current_transction?
      # instead of this accessor to see if we're a transaction thread or not
      def current_transaction_stack
        @current_transaction_stack ||= []
      end

      def duration
        Time.now - self.transaction_start_time
      end

      def self.in_background_transaction?(thread)
        state_for(thread).in_background_transaction?
      end

      def self.in_request_transaction?(thread)
        state_for(thread).in_request_transaction?
      end

      def in_background_transaction?
        !current_transaction.nil? && current_transaction.request.nil?
      end

      def in_request_transaction?
        !current_transaction.nil? && !current_transaction.request.nil?
      end

      def current_transaction
        current_transaction_stack.last if has_current_transaction?
      end

      def has_current_transaction?
        !@current_transaction_stack.nil?
      end

      # Execution tracing on current thread
      attr_accessor :untraced

      def push_traced(should_trace)
        @untraced ||= []
        @untraced << should_trace
      end

      def pop_traced
        @untraced.pop if @untraced
      end

      def is_traced?
        @untraced.nil? || @untraced.last != false
      end

      # TT's and SQL
      attr_accessor :record_tt, :record_sql

      def is_transaction_traced?
        @record_tt != false
      end

      def is_sql_recorded?
        @record_sql != false
      end

      # Busy calculator
      attr_accessor :busy_entries

      # Sql Sampler Transaction Data
      attr_accessor :sql_sampler_transaction_data

      # Scope stack tracking from NewRelic::StatsEngine::Transactions
      attr_accessor :scope_stack

      def clear_stats_scope_stack
        @scope_stack = nil
      end

    end
  end
end
