module RSpec::Steps
  class StepContext
    attr_reader :before_hooks, :after_hooks, :around_hooks

    def initialize
      @before_hooks = Hash.new { |h, k| h[k] = [] }
      @after_hooks = Hash.new { |h, k| h[k] = [] }
      @around_hooks = Hash.new { |h, k| h[k] = [] }
    end

    def add_before(scope, &block)
      raise 'before scope must be :step or :each' unless %i[step each].include?(scope)

      @before_hooks[scope] << block
    end

    def add_after(scope, &block)
      raise 'after scope must be :step or :each' unless %i[step each].include?(scope)

      @after_hooks[scope] << block
    end

    def add_around(scope, &block)
      raise 'around scope must be :each' unless scope == :each

      @around_hooks[scope] << block
    end

    def run_before_hooks(scope, example)
      @before_hooks[scope].each { |hook| example.instance_eval(&hook) }
      @before_hooks[scope] = [] if scope == :step
    end

    def run_after_hooks(scope, example)
      @after_hooks[scope].each { |hook| example.instance_eval(&hook) }
      @after_hooks[scope] = [] if scope == :step
    end

    def run_around_hooks(scope, example, &block)
      # Nest the around hooks
      hooks = @around_hooks[scope]
      return block.call if hooks.empty?

      hooks.reduce(block) do |wrapped_block, hook|
        -> { example.instance_exec(wrapped_block, &hook) }
      end.call
    end
  end
end
