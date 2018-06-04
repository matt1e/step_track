# step_track

    gem install step_track

## Usage

    StepTrack.init("some_track_name") do |payload|
      # process the payload once StepTrack.done is called
    end

    StepTrack.push("some_track_name", "some_step_name", foo: "bar")
    StepTrack.push("some_track_name", "another_step_name", bar: "foo")
    StepTrack.push("some_track_name", "same_step_name", foo: "bar", gnu: :tar)
    StepTrack.push("some_track_name", "same_step_name", foo: "bar", gnu: :gzip)

    StepTrack.done("some_track_name")

## Test

    ruby -Ilib:test test/runner.rb
