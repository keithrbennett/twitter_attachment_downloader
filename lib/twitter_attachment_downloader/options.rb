# Encapsulates and manages program options, including getting them from the command line.

require 'optparse'

class Options < Struct.new(:archive_root_dir, :include_retweets)

  # Creates an instance from the command line options
  def self.from_command_line

    option_parser = nil
    output_help_and_terminate = -> { puts option_parser; puts; exit }

    options = Options.new

    OptionParser.new do |opts|

      option_parser = opts

      opts.banner = "Usage: twitter-attachment-downloader [options]"

      opts.on('-d', '--archive_root_dir dir', 'Root of Twitter archive directory (default: .)') do |value|
        options.archive_root_dir = value
      end

      opts.on('-r', '--[no-]include_retweets', 'Download attachments to retweets') do |value|
        options.include_retweets = value
      end

      opts.on_tail("-h", "--help", "Show this message") do
        output_help_and_terminate.()
      end

    end.parse!

    if options.archive_root_dir.nil?
      puts "Archive root directory not specified. Assuming current directory."
      self.archive_root_dir = Dir.getwd
    end

    options
  end


  def tweet_index_filespec
    File.join(archive_root_dir, 'data', 'js', 'tweet_index.js')
  end


  def tweet_dirspec
    File.join(archive_root_dir, 'data', 'js', 'tweets')
  end
end
