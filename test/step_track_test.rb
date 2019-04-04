describe "StepTrack" do
  after do
    Thread.current[StepTrack.send(:ref, "test")] = nil
  end

  describe ".init" do
    it "raises when no block is given" do
      begin
        rescued = false
        StepTrack.init("test")
      rescue ArgumentError
        rescued = true
      end
      assert rescued
    end

    it "stores the initialized data into thread context" do
      StepTrack.init("test") { }
      data = Thread.current[StepTrack.send(:ref, "test")]
      assert_equal [], data[:steps],
        "steps is no empty array #{data[:steps].inspect}"
      assert data[:callback].is_a?(Proc),
        "callback is no proc #{data[:callback].inspect}"
      assert data[:time] <= DateTime.now,
        "time #{data[:time].inspect} > #{DateTime.now.inspect}"
      assert_equal data[:track_id], Thread.current.object_id.to_s,
        "track id is #{StepTrack.track_id("test")}"
      refute_empty data[:caller], "caller is empty"
    end

    it "stores a track_id when given" do
      StepTrack.init("test", track_id: "moobar") { }
      assert_equal "moobar", StepTrack.track_id("test"),
        "track id is #{StepTrack.track_id("test")}"
    end
  end

  describe ".push" do
    before do
      StepTrack.init("test") { }
    end

    it "requires initialization" do
      begin
        rescued = false
        StepTrack.push("no_init", "step")
      rescue ArgumentError
        rescued = true
      end
      assert rescued
    end

    it "pushes a step including payload into data" do
      StepTrack.push("test", "step", moo: "bar")
      data = Thread.current[StepTrack.send(:ref, "test")]
      step = data[:steps].first
      assert_equal 1, data[:steps].size
      assert_equal "step", step[:step_name]
      assert_equal "bar", step[:moo]
      expected_keys = [:split, :duration, :time, :caller]
      assert_equal expected_keys, expected_keys & step.keys
    end

    it "merges the new payload into the previous result when requested" do
      StepTrack.push("test", "step", moo: "bar")
      StepTrack.push("test", "new", blu: "gnu", merge: true)
      data = Thread.current[StepTrack.send(:ref, "test")]
      assert_equal 1, data[:steps].size
      step = data[:steps].first
      assert_equal "bar", step[:moo]
      assert_equal "gnu", step[:blu]
    end
  end

  describe ".done" do
    before do
      StepTrack.init("test") { |result| result }
      StepTrack.push("test", "step", moo: "bar")
      StepTrack.push("test", "last", gnu: "blu")
    end

    it "requires initialization" do
      begin
        rescued = false
        StepTrack.done("no_init")
      rescue ArgumentError
        rescued = true
      end
      assert rescued
    end

    it "returns the callback result" do
      result = StepTrack.done("test")
      assert result.is_a?(Hash), "result is no hash #{result.inspect}"
    end

    it "sets a step count" do
      result = StepTrack.done("test")
      assert_equal 2, result[:step_count]
    end

    it "sets the final step name" do
      result = StepTrack.done("test")
      assert_equal "last", result[:final_step_name]
    end

    it "sets a duration" do
      result = StepTrack.done("test")
      assert result[:duration].is_a?(Float), "duration is no Float"
      assert result[:duration] > 0.0, "duration is not positive"
      assert result[:duration] < 1.0, "duration is too long"
    end

    it "sets a caller" do
      result = StepTrack.done("test")
      assert_match %r{#{Regexp.escape(__FILE__)}}, result[:caller]
    end

    it "sets a timestamp" do
      result = StepTrack.done("test")
      assert_match %r{\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+\d{2}:\d{2}}, result[:timestamp]
    end

    it "does not merge final step into results" do
      result = StepTrack.done("test")
      assert !result.key?(:gnu), "merged gnu into result"
    end

    it "merges the error into result when available" do
      StepTrack.push("test", "err", moo: "bar", error: true)
      StepTrack.push("test", "new")
      result = StepTrack.done("test")
      assert_equal "err", result[:final_step_name]
    end

    it "enumerates every step into result" do
      result = StepTrack.done("test")
      expected_key_parts = [:i, :split, :duration, :timestamp, :caller]

      ["step", "last"].each_with_index do |n, i|
        expected_keys = expected_key_parts.map { |k| "step_#{n}_#{k}".to_sym }
        assert_equal expected_keys, expected_keys & result.keys
      end
    end

    it "enumerate duplicated step names with index in the result" do
      StepTrack.push("test", "last", gnu: "blu")
      result = StepTrack.done("test")
      expected_key_parts = [:i, :split, :duration, :caller]

      ["step", "last", "last_1"].each_with_index do |n, i|
        expected_keys = expected_key_parts.map { |k| "step_#{n}_#{k}".to_sym }
        assert_equal expected_keys, expected_keys & result.keys
      end
    end
  end

  describe ".track_id" do
    it "raises when not initialized" do
      assert_raises ArgumentError do
        StepTrack.track_id("test")
      end
    end

    it "gives nil track_id when initialized without track_id" do
      StepTrack.init("test") {  }
      assert_equal Thread.current.object_id.to_s, StepTrack.track_id("test")
    end

    it "gives configured track_id when initialized with track_id" do
      StepTrack.init("test", track_id: "1234") {  }
      assert_equal "1234", StepTrack.track_id("test")
    end
  end
end
