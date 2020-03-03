require "./spec_helper"

include MangaDex

describe Queue do
	it "creates DB at given path" do
		with_queue do |queue, path|
			File.exists?(path).should be_true
		end
	end

	it "inserts multiple jobs" do
		with_queue do |queue|
			j1 = Job.new "1", "1", "title", "manga_title", JobStatus::Error,
				Time.utc
			j2 = Job.new "2", "2", "title", "manga_title", JobStatus::Completed,
				Time.utc
			j3 = Job.new "0", "0", "title", "manga_title", JobStatus::Pending,
				Time.utc
			count = queue.push [j1, j2, j3]
			count.should eq 3
		end
	end

	it "pops pending job" do
		with_queue do |queue|
			job = queue.pop
			job.should_not be_nil
			job.not_nil!.id.should eq "0"
		end
	end

	it "cleans up" do
		State.reset
		with_queue do
			true
		end
	end
end

