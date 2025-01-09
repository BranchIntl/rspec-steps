require_relative "step-context"

module RSpec::Steps
  class StepExampleRunner
    def initialize(context_example, running_example)
      @_context_example = context_example
      @_running_example = running_example

      @_current_metadata = {}
      @_let_hash = {}
      @_subject_hash = {}
      @_counter = 0

      context_example.instance_variables.each do |var|
        instance_variable_set(var, context_example.instance_variable_get(var))
      end
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
      @_current_metadata
    end

    def method_missing(method, *args, &block)
      method = @_let_hash[method] if @_let_hash.key?(method)
      method = @_subject_hash[method] if @_subject_hash.key?(method)
      @_context_example.send(method, *args, &block)
    end

    def respond_to_missing?(method, include_private = false)
      method = @_let_hash[method] if @_let_hash.key?(method)
      method = @_subject_hash[method] if @_subject_hash.key?(method)
      @_context_example.respond_to?(method, include_private)
    end
  end

  class StepRunner
    def initialize(context_example, running_example)
      @_context_example = context_example
      @_running_example = running_example

      @_step_context = StepContext.new
      @_metadata_stack = [@_running_example.metadata.dup]
      @_example_runner = StepExampleRunner.new(@_context_example, @_running_example)
    end

    def before(scope = :step, &block)
      @_step_context.add_before(scope, &block)
    end

    def after(scope = :step, &block)
      @_step_context.add_after(scope, &block)
    end

    def around(scope = :each, &block)
      @_step_context.add_around(scope, &block)
    end

    def describe(description, metadata = {}, &block)
      @_example_runner.instance_eval { @_counter += 1 }

      parent_metadata = @_metadata_stack.last.dup
      @_metadata_stack.push(parent_metadata.merge(metadata))

      instance_eval(&block)

      @_metadata_stack.pop
    end

    def it(*all_args, &block)
      @_example_runner.instance_variable_set(:@_current_metadata, @_metadata_stack.last)

      @_step_context.run_before_hooks(:step, @_example_runner)
      @_step_context.run_before_hooks(:each, @_example_runner)

      @_step_context.run_around_hooks(:each, @_example_runner) do
        @_example_runner.instance_eval(&block)
      end

      @_step_context.run_after_hooks(:each, @_example_runner)
    end

    def let(name, &block)
      example_runner = @_example_runner
      example_runner.instance_eval do
        @_let_hash[name] = "#{name}_#{@_counter}"
        @_context_example.class.let("#{name}_#{@_counter}") do
          example_runner.instance_eval(&block)
        end
      end
    end

    def subject(name = nil, &block)
      name = :subject if name.nil?
      example_runner = @_example_runner
      example_runner.instance_eval do
        @_subject_hash[name] = "#{name}_#{@_counter}"
        @_context_example.class.subject("#{name}_#{@_counter}") do
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
      @_context_example.class.send(method, *args, &block)
    end

    def respond_to_missing?(method, include_private = false)
      @_context_example.class.respond_to?(method, include_private)
    end
  end
end
