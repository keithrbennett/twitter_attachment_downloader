# Encapsulates and manages program options, including getting them from the command line.

require 'optparse'

class Options < Struct.new(:archive_root_dir, :include_retweets)

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
    options
  end


  def archive_root_dir
    @archive_root_dir ||= '.'
  end


  def tweet_index_filespec
    File.join(archive_root_dir, 'data', 'js', 'tweet_index.js')
  end


  def tweet_dirspec
    File.join(archive_root_dir, 'data', 'js', 'tweets')
  end
end
