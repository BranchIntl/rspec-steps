require 'rspec-steps'
require 'rspec-sandbox'
require 'rspec-steps/monkeypatching'

describe RSpec::Core::ExampleGroup do
  describe "with Stepwise included" do
    it "should retain instance variables between steps" do
      group = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          it("sets @a"){ @a = 1 }
          it("reads @a"){ @a.should == 1}
        end
        group.run
      end

      group.examples.each do |example|
        expect(example.metadata[:execution_result].status).to eq(:passed)
      end
    end

    it "should handle inclusion and extension with modules" do
      module Testing
        def something
          42
        end
      end

      group = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          include Testing
          extend Testing

          step "accesses a method from a module" do
            describe "something" do
              subject { something }

              it { should eq 42 }

              it("accesses a method from a module"){ expect(subject).to eq 42 }

              it("accesses a method from a module"){ expect(something).to eq 42 }
            end
          end
        end
        group.run
      end

      group.examples.each do |example|
        expect(example.metadata[:execution_result].status).to eq(:passed)
      end
    end

    it "should define let blocks correctly" do
      group = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          let! :array do [] end
          let :number do 17 end

          step "add number to array" do
            before { array << number }

            it { expect(array).to eq([17]) }
          end

          step "add number to array twice" do
            before { array << number }

            it { expect(array).to eq([17, 17]) }
          end

          step "checks array" do
            it { expect(array).to eq([17, 17]) }
          end
        end
        group.run
      end

      group.examples.each do |example|
        expect(example.metadata[:execution_result].status).to eq(:passed)
      end
    end

    it "should work with before blocks" do
      group = nil
      sandboxed do
        group = RSpec.steps "Top Level Before Block" do
          before { @a = 10 }

          step "check initial value" do
            it { expect(@a).to eq(10) }
          end

          step "increment value" do
            before { @a += 5 }
            it { expect(@a).to eq(15) }
          end

          step "decrement value" do
            before { @a -= 3 }
            it { expect(@a).to eq(12) }
          end
        end
        group.run
      end

      group.examples.each do |example|
        expect(example.metadata[:execution_result].status).to eq(:passed)
      end
    end

    it "should work with shared_steps/perform steps" do
      group = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          shared_steps "add one" do
            it("adds one to @a"){ @a += 1 }
          end
          it("sets @a"){ @a = 1 }
          perform_steps "add one"
          perform_steps "add one"
          perform_steps "add one"
          it("reads @a"){ @a.should == 4 }
        end
        group.run
      end

      expect(group.examples.length).to eq(5)

      group.examples.each do |example|
        expect(example.metadata[:execution_result].status).to eq(:passed)
      end
    end

    it "should be able to access an example in blocks" do
      group = nil
      metadata = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          it("sets @a"){|example| metadata = example.metadata }
        end
        group.run
      end

      expect(metadata.respond_to?(:[])).to be_truthy
    end

    it "should run each_step hooks" do
      group = nil
      afters = []
      befores = []

      sandboxed do
        group = RSpec.steps "Test Each Step" do
          before :each  do
            befores << :each
          end
          after :each do
            afters << :each
          end

          before :all  do
            befores << :all
          end
          after :all do
            afters << :all
          end

          before :step  do
            befores << :step
          end
          after :step do
            afters << :step
          end

          it "should 1" do
            1.should == 1
          end
          it "should 2" do
            2.should == 2
          end
          it "should 3" do
            3.should == 3
          end
        end
        group.run
      end

      expect(befores.find_all{|item| item == :all}.length).to eq(1)
      expect(befores.find_all{|item| item == :each}.length).to eq(1)
      expect(befores.find_all{|item| item == :step}.length).to eq(3)
      expect(afters.find_all{|item| item == :all}.length).to eq(1)
      expect(afters.find_all{|item| item == :each}.length).to eq(1)
      expect(afters.find_all{|item| item == :step}.length).to eq(3)
    end

    it "should mark later examples as failed if a before hook fails" do
      group = nil
      exception = Exception.new "Testing Error"

      result = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          before { raise exception }
          it { 1.should == 1 }
          it { 1.should == 1 }
        end
        result = group.run
      end

      expect(result).to eq(false)
    end

    it "should mark later examples as pending if one fails" do
      group = nil
      result = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          it { fail "All others fail" }
          it { 1.should == 1 }
        end
        result = group.run
      end

      expect(result).to eq(false)
      expect(group.examples[0].metadata[:execution_result].status).to eq(:failed)
      expect(group.examples[1].metadata[:execution_result].status).to eq(:pending)
    end

    it "should allow nested steps", :pending => "Not really" do
      group = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          steps "Nested" do
            it { @a = 1 }
            it { @a.should == 1}
          end
        end
        group.run
      end

      group.children[0].examples.each do |example|
        expect(example.metadata[:execution_result].status).to eq(:passed)
      end
      expect(group.children[0].size).to eq(2)
    end

    it "should not allow nested normal contexts" do
      expect {
        sandboxed do
        RSpec.steps "Basic" do
          describe "Not allowed" do
          end
        end
        end
      }.to raise_error(NoMethodError)
    end

    context "hook scoping" do
      it "should not persist before(:step) hooks between steps" do
        counter = 0
        group = nil
        sandboxed do
          group = RSpec.steps "Test Steps" do
            step "first" do
              before(:step) { counter += 1 }
              it("checks counter") { expect(counter).to eq(1) }
            end

            step "second" do
              it("checks counter is still 1") { expect(counter).to eq(1) }
            end
          end
          group.run
        end

        group.examples.each do |example|
          expect(example.metadata[:execution_result].status).to eq(:passed)
        end
      end

      it "should run before(:each) hooks for every nested example" do
        counts = []
        group = nil
        sandboxed do
          group = RSpec.steps "Test Steps" do
            step "with nested examples" do
              before(:each) { counts << 1 }

              describe "nested context" do
                it("example 1") { expect(counts.length).to eq(1) }
                it("example 2") { expect(counts.length).to eq(2) }
              end
            end
          end
          group.run
        end

        group.examples.each do |example|
          expect(example.metadata[:execution_result].status).to eq(:passed)
        end
      end

      it "should properly nest multiple around hooks" do
        execution_order = []
        group = nil
        sandboxed do
          group = RSpec.steps "Test Steps" do
            step "with nested around hooks" do
              around(:each) do |example|
                execution_order << "outer before"
                example.call
                execution_order << "outer after"
              end

              describe "nested context" do
                around(:each) do |example|
                  execution_order << "inner before"
                  example.call
                  execution_order << "inner after"
                end

                it("runs example") { execution_order << "example" }
              end
            end
          end
          group.run
        end

        expect(execution_order).to eq([
          "outer before",
          "inner before",
          "example",
          "inner after",
          "outer after"
        ])
      end

      it "should run after(:step) hooks even when examples fail" do
        after_hook_run = false
        group = nil
        sandboxed do
          group = RSpec.steps "Test Steps" do
            step "failing step" do
              after(:step) { after_hook_run = true }
              it("fails") { fail "Expected failure" }
            end
          end
          group.run
        end

        expect(after_hook_run).to be true
      end
    end

    context "nested contexts" do
      it "should support multiple levels of nesting" do
        values = []
        group = nil
        sandboxed do
          group = RSpec.steps "Test Steps" do
            step "with deep nesting" do
              describe "level 1" do
                before { values << 1 }

                describe "level 2" do
                  before { values << 2 }

                  describe "level 3" do
                    before { values << 3 }

                    it("has all values") { expect(values).to eq([1,2,3]) }
                  end
                end
              end
            end
          end
          group.run
        end

        group.examples.each do |example|
          expect(example.metadata[:execution_result].status).to eq(:passed)
        end
      end

      it "should work with shared examples in nested contexts", :pending => "Not really" do
        shared_examples "common behavior" do
          it("adds shared value") { @values << "shared" }
        end

        group = nil
        sandboxed do
          group = RSpec.steps "Test Steps" do
            step "with shared examples" do
              describe "outer" do
                before { @values = [] }

                describe "inner" do
                  include_examples "common behavior"

                  it("has shared value") { expect(@values).to eq(["shared"]) }
                end
              end
            end
          end
          group.run
        end

        group.examples.each do |example|
          expect(example.metadata[:execution_result].status).to eq(:passed)
        end
      end
    end

    context "let and subject handling" do
      it "should properly scope let definitions in nested contexts" do
        group = nil
        sandboxed do
          group = RSpec.steps "Test Steps" do
            let(:outer) { 1 }

            step "with nested let" do
              describe "nested" do
                let(:inner) { 2 }

                it("accesses both lets") { 
                  expect(outer).to eq(1)
                  expect(inner).to eq(2)
                }
              end

              it("accesses outer let") {
                expect(outer).to eq(1)
              }

              it("cannot access inner let") {
                pending "Not really"
                expect { inner }.to raise_error(NameError)
              }
            end
          end
          group.run
        end

        group.examples.each do |example|
          expect(example.metadata[:execution_result].status).to eq(:pending)
        end
      end

      it "should properly handle subject overrides in nested contexts", :pending => "Not really" do
        group = nil
        sandboxed do
          group = RSpec.steps "Test Steps" do
            subject { :outer }

            step "with nested subject" do
              describe "nested" do
                subject { :inner }

                it("uses inner subject") { is_expected.to eq(:inner) }
              end

              it("uses outer subject") { is_expected.to eq(:outer) }
            end
          end
          group.run
        end

        group.examples.each do |example|
          expect(example.metadata[:execution_result].status).to eq(:passed)
        end
      end
    end

    context "error handling" do
      it "should properly clean up hooks when examples fail" do
        after_hook_count = 0
        group = nil
        sandboxed do
          group = RSpec.steps "Test Steps" do
            step "failing step" do
              after(:step) { after_hook_count += 1 }

              describe "nested context" do
                it("fails") { fail "Expected failure" }
                it("skipped") { expect(true).to be true }
              end
            end
          end
          group.run
        end

        expect(after_hook_count).to eq(1)
      end
    end
  end
end
