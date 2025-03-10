module RSpec::Steps
  class Step < Struct.new(:metadata, :args, :action)
    def initialize(*whatever)
      super
      @failed_step = nil
    end

    attr_accessor :failed_step

    def define_on(step_list, example_group)
      step = self
      example_group.it(*args, metadata) do |example|
        step_list.run_only_once(self, example)
        result = step_list.result_for(step)
        pending if result.is_after_failed_step?
        expect(result).to have_executed_successfully
      end
    end

    def run_inside(step_runner)
      action = self.action

      step_runner.instance_eval do
        instance_exec(@running_example, &action)
      end
    end

  end
end
