require "./spec_helper"

include MangaDex

describe Queue do
	it "creates DB at given path" do
		with_queue do |queue, path|
			File.exists?(path).should be_true
		end
	end

	it "pops nil when empty" do
		with_queue do |queue|
			queue.pop.should be_nil
		end
	end

	it "inserts multiple jobs" do
		with_queue do |queue|
			j1 = Job.new "1", "1", "title", "manga_title", JobStatus::Error,
				Time.utc
			j2 = Job.new "2", "2", "title", "manga_title", JobStatus::Completed,
				Time.utc
			j3 = Job.new "3", "3", "title", "manga_title", JobStatus::Pending,
				Time.utc
			j4 = Job.new "4", "4", "title", "manga_title",
				JobStatus::Downloading, Time.utc
			count = queue.push [j1, j2, j3, j4]
			count.should eq 4
		end
	end

	it "pops pending job" do
		with_queue do |queue|
			job = queue.pop
			job.should_not be_nil
			job.not_nil!.id.should eq "3"
		end
	end

	it "correctly counts jobs" do
		with_queue do |queue|
			queue.count.should eq 4
		end
	end

	it "deletes job" do
		with_queue do |queue|
			queue.delete "4"
			queue.count.should eq 3
		end
	end

	it "sets status" do
		with_queue do |queue|
			job = queue.pop.not_nil!
			queue.set_status JobStatus::Downloading, job
			job = queue.pop
			job.should_not be_nil
			job.not_nil!.status.should eq JobStatus::Downloading
		end
	end

	it "sets number of pages" do
		with_queue do |queue|
			job = queue.pop.not_nil!
			queue.set_pages 100, job
			job = queue.pop
			job.should_not be_nil
			job.not_nil!.pages.should eq 100
		end
	end

	it "adds fail/success counts" do
		with_queue do |queue|
			job = queue.pop.not_nil!
			queue.add_success job
			queue.add_success job
			queue.add_fail job
			job = queue.pop
			job.should_not be_nil
			job.not_nil!.success_count.should eq 2
			job.not_nil!.fail_count.should eq 1
		end
	end

	it "appends status message" do
		with_queue do |queue|
			job = queue.pop.not_nil!
			queue.add_message "hello", job
			queue.add_message "world", job
			job = queue.pop
			job.should_not be_nil
			job.not_nil!.status_message.should eq "\nhello\nworld"
		end
	end

	it "cleans up" do
		State.reset
		with_queue do
			true
		end
	end
end

