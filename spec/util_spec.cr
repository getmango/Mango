require "./spec_helper"

describe "compare_alphanumerically" do
	it "sorts filenames with leading zeros correctly" do
		ary = ["010.jpg", "001.jpg", "002.png"]
		ary.sort! {|a, b|
			compare_alphanumerically a, b
		}
		ary.should eq ["001.jpg", "002.png", "010.jpg"]
	end

	it "sorts filenames without leading zeros correctly" do
		ary = ["10.jpg", "1.jpg", "0.png", "0100.jpg"]
		ary.sort! {|a, b|
			compare_alphanumerically a, b
		}
		ary.should eq ["0.png", "1.jpg", "10.jpg", "0100.jpg"]
	end

	# https://ux.stackexchange.com/a/95441
	it "sorts like the stack exchange post" do
		ary = ["2", "12", "200000", "1000000", "a", "a12", "b2", "text2",
		 "text2a", "text2a2", "text2a12", "text2ab", "text12", "text12a"]
		ary.reverse.sort {|a, b|
			compare_alphanumerically a, b
		}.should eq ary
	end
end
