require_relative "step-context"

module RSpec::Steps
  class StepExampleRunner
    def initialize(context_example, running_example)
      @context_example = context_example
      @running_example = running_example

      @current_metadata = {}
      @let_hash = {}
      @subject_hash = {}
      @counter = 0
    end

    def should(matcher = nil, message = nil)
      expect(subject).to(matcher, message)
    end

    def should_not(matcher = nil, message = nil)
      expect(subject).not_to(matcher, message)
    end

    def is_expected
      expect(subject)
    end

    def metadata
      @current_metadata
    end

    def method_missing(method, *args, &block)
      method = @let_hash[method] if @let_hash.key?(method)
      method = @subject_hash[method] if @subject_hash.key?(method)
      @context_example.send(method, *args, &block)
    end

    def respond_to_missing?(method, include_private = false)
      method = @let_hash[method] if @let_hash.key?(method)
      method = @subject_hash[method] if @subject_hash.key?(method)
      @context_example.respond_to?(method, include_private)
    end
  end

  class StepRunner
    def initialize(context_example, running_example)
      @context_example = context_example
      @running_example = running_example

      @step_context = StepContext.new
      @metadata_stack = [@running_example.metadata.dup]
      @example_runner = StepExampleRunner.new(@context_example, @running_example)
    end

    def before(scope = :step, &block)
      @step_context.add_before(scope, &block)
    end

    def after(scope = :step, &block)
      @step_context.add_after(scope, &block)
    end

    def around(scope = :each, &block)
      @step_context.add_around(scope, &block)
    end

    def describe(description, metadata = {}, &block)
      @example_runner.instance_eval { @counter += 1 }

      parent_metadata = @metadata_stack.last.dup
      @metadata_stack.push(parent_metadata.merge(metadata))

      instance_eval(&block)

      @metadata_stack.pop
    end

    def it(*all_args, &block)
      @example_runner.instance_variable_set(:@current_metadata, @metadata_stack.last)

      @step_context.run_before_hooks(:step, @example_runner)
      @step_context.run_before_hooks(:each, @example_runner)

      @step_context.run_around_hooks(:each, @example_runner) do
        @example_runner.instance_eval(&block)
      end

      @step_context.run_after_hooks(:each, @example_runner)
    end

    def let(name, &block)
      example_runner = @example_runner
      example_runner.instance_eval do
        @let_hash[name] = "#{name}_#{@counter}"
        @context_example.class.let("#{name}_#{@counter}") do
          example_runner.instance_eval(&block)
        end
      end
    end

    def subject(name = nil, &block)
      name = :subject if name.nil?
      example_runner = @example_runner
      example_runner.instance_eval do
        @subject_hash[name] = "#{name}_#{@counter}"
        @context_example.class.subject("#{name}_#{@counter}") do
          example_runner.instance_eval(&block)
        end
      end
    end

    def it_behaves_like(name, *args)
      describe(name) do
        instance_exec(*args, &SharedExamples[name])
      end
    end

    def method_missing(method, *args, &block)
      @context_example.class.send(method, *args, &block)
    end

    def respond_to_missing?(method, include_private = false)
      @context_example.class.respond_to?(method, include_private)
    end
  end
end
