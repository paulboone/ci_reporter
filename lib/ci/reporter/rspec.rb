# (c) Copyright 2006-2008 Nick Sieger <nicksieger@gmail.com>
# See the file LICENSE.txt included with the distribution for
# software license details.

require 'ci/reporter/core'
tried_gem = false
begin
  require 'spec'
  require 'spec/runner/formatter/progress_bar_formatter'
  require 'spec/runner/formatter/specdoc_formatter'
rescue LoadError
  unless tried_gem
    tried_gem = true
    require 'rubygems'
    gem 'rspec'
    retry
  end
end

module CI
  module Reporter
    # Wrapper around a <code>RSpec</code> error or failure to be used by the test suite to interpret results.
    class RSpecFailure
      def initialize(failure)
        @failure = failure
      end

      def failure?
        @failure.expectation_not_met?
      end

      def error?
        !@failure.expectation_not_met?
      end

      def name() @failure.exception.class.name end
      def message() @failure.exception.message end
      def location() @failure.exception.backtrace.join("\n") end
    end

    # Custom +RSpec+ formatter used to hook into the spec runs and capture results.
    class RSpec < Spec::Runner::Formatter::BaseFormatter
      attr_accessor :report_manager
      attr_accessor :formatter
      def initialize(*args)
        super
        @formatter ||= Spec::Runner::Formatter::ProgressBarFormatter.new(*args)
        @report_manager = ReportManager.new("spec")
        @suite = nil
      end

      def start(spec_count)
        @formatter.start(spec_count)
      end

      def add_behaviour(name)
        @formatter.add_behaviour(name)
        new_suite(name)
      end

      def example_group_started(example_group)
        @formatter.example_group_started(example_group)
        new_suite(example_group.description)
      end

      def example_started(name)
        @formatter.example_started(name)
        name = name.description if name.respond_to?(:description)
        spec = TestCase.new name
        @suite.testcases << spec
        spec.start
      end

      def example_failed(name, counter, failure)
        @formatter.example_failed(name, counter, failure)
        spec = @suite.testcases.last
        spec.finish
        spec.failures << RSpecFailure.new(failure)
      end

      def example_passed(name)
        @formatter.example_passed(name)
        spec = @suite.testcases.last
        spec.finish
      end

      def example_pending(*args)
        @formatter.example_pending(*args)
        spec = @suite.testcases.last
        spec.finish
        spec.name = "#{spec.name} (PENDING)"
      end

      def start_dump
        @formatter.start_dump
      end

      def dump_failure(*args)
        @formatter.dump_failure(*args)
      end

      def dump_summary(*args)
        @formatter.dump_summary(*args)
        write_report
      end

      def dump_pending
        @formatter.dump_pending
      end

      def close
        @formatter.close
      end

      private
      def write_report
        @suite.finish
        @report_manager.write_report(@suite)
      end

      def new_suite(name)
        write_report if @suite
        @suite = TestSuite.new name
        @suite.start
      end
    end

    class RSpecDoc < RSpec
      def initialize(*args)
        @formatter = Spec::Runner::Formatter::SpecdocFormatter.new(*args)
        super
      end
    end
  end
end
