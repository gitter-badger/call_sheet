require "call_sheet/result_matcher"

module CallSheet
  class Transaction
    # @api private
    attr_reader :steps
    private :steps

    # @api private
    def initialize(steps)
      @steps = steps
    end

    # @api public
    def call(input, options = {}, &block)
      assert_valid_options(options)
      assert_options_satisfy_step_arity(options)

      steps = steps_with_options_applied(options)
      result = steps.inject(Right(input), :>>)

      if block
        block.call(ResultMatcher.new(result))
      else
        result
      end
    end
    alias_method :[], :call

    # @api public
    def subscribe(listeners)
      if listeners.is_a?(Hash)
        listeners.each do |step_name, listener|
          steps.detect { |step| step.step_name == step_name }.subscribe(listener)
        end
      else
        steps.each do |step|
          step.subscribe(listeners)
        end
      end

      self
    end

    private

    def assert_valid_options(options)
      options.each_key do |step_name|
        unless steps.map(&:step_name).include?(step_name)
          raise ArgumentError, "+#{step_name}+ is not a valid step name"
        end
      end
    end

    def assert_options_satisfy_step_arity(options)
      steps.each do |step|
        args_required = step.arity >= 0 ? step.arity : ~step.arity
        args_supplied = options.fetch(step.step_name, []).length + 1 # add 1 for main `input`

        if args_required > args_supplied
          raise ArgumentError, "not enough options for step +#{step.step_name}+"
        end
      end
    end

    def steps_with_options_applied(options)
      steps.map { |step|
        if (args = options[step.step_name])
          step.with_call_args(*args)
        else
          step
        end
      }
    end
  end
end
