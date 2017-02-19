# Downloads attachments to Twitter messages in an archive.

require 'awesome_print'
require 'fileutils'
require 'json'

require_relative 'options'
require_relative 'exit_codes'


class Downloader

  attr_accessor :options

  def initialize(options)
    self.options = options
  end


  def stdout_print(str)
    $stdout.puts("\r%s\033[K" % str)
    $stdout.flush
  end


  def year_month_str(date)
    '%04d_%02d' % [date['year'], date['month']]
  end


# If an earlier archive has been specified, check whether or not it actually exists.
# (This is important because failure would mean quietly downloading all the files again.)
  def validate_archive_dir

    archive_root_dir = options.archive_root_dir
    unless Dir.exist?(archive_root_dir)
      puts "Could not find archive directory #{archive_root_dir}!"
      exit(ExitCodes.for(:archive_root_dir_missing))
    end
    unless File.exist?(options.tweet_index_filespec)
      puts "Could not find tweet master index at #{options.tweet_index_filespec}. " +
               "It should contain the index.html file."
      exit(ExitCodes.for(:tweet_master_index_missing))
    end
  end


# Process the index file to see what needs to be done
  def read_index
    json_text = File.read(options.tweet_index_filespec)
    json_text = json_text.gsub!(/var tweet_index =/, '')
    JSON.parse(json_text)
  end


  def create_filenames(date)
    ym_str = year_month_str(date)
    tweet_dir = options.tweet_dirspec

    # example: data/js/tweets/2017_01.js
    data_filename = File.join(tweet_dir, "#{ym_str}.js")

    # Make a copy of the original JS file, just in case (only if it doesn't exist before)
    # example: data/js/tweets/2017_01_original.js
    backup_filename = File.join(tweet_dir, "#{ym_str}_original.js")

    # example: data/js/tweets/2017_01_media
    media_directory_name = File.join(tweet_dir, "#{ym_str}_media")

    [data_filename, backup_filename, media_directory_name]
  end



  def read_month_data_file(data_filename)
    lines = File.readlines(data_filename)

    # First line will look like this:
    # Grailbird.data.tweets_2017_01 =[

    # Remove the assignment to a variable that breaks JSON parsing
    # (everything to the left of '['),
    # but save for later since we have to recreate the file.

    first_data_line = lines.first.dup
    lines.first.gsub!(%r{Grailbird.data.tweets_(.*) =}, '')
    json_string = lines.join("\n")
    data = JSON.parse(json_string)

    [data, first_data_line]
  end


  def media_already_downloaded(media)
    File.file?(media['media_url'])
  end


  def retweet?(tweet)
    tweet.keys().include?('retweeted_status')
  end


# Replace ':' with '.', spaces with underscores.
  def reformat_date_string_for_filename(string)
    string.gsub(':', '.').gsub(' ', '_')
  end


  def download_file(url, local_filespec)
    temp_filespec = File.join(options.archive_root_dir, 'twitter_downloader_tempfile')
    `curl -o #{temp_filespec} #{Shellwords.shellescape(url)}`
    if $?.exitstatus != 0
      raise "Curl Download failed with exit status #{$0.exitstatus}."
    else
      #   validate_downloaded_file(tempfilespec)
      # TODO: Handle 0 return code but failed request
      FileUtils.mv(temp_filespec, local_filespec)
      puts "Finished downloading #{local_filespec}\n\n"
    end
  end



  def media_locators(tweet, media, date, date_str, tweet_image_num)
    media_url = media['media_url_https']

    extension = File.extname(media_url)

    # Download the original/best image size, rather than the default one
    media_url_original_resolution = media_url + ':orig'

    local_filename = File.join(options.tweet_dirspec,
                               "%s_media" % (year_month_str(date)),
                               "%s-%s-%s%d%s" % [
                                   date_str,
                                   tweet['id'],
                                   retweet?(tweet) ? 'rt-' : '',
                                   tweet_image_num,
                                   extension
                               ]
    )
    [media_url, media_url_original_resolution, local_filename]
  end


  def rewrite_js_file(data_filespec, first_data_line, tweets_this_month)
    new_json_text = '' << first_data_line << tweets_this_month.to_json
    File.write(data_filespec, new_json_text)
    puts 'Rewrote '  + data_filespec
  end



  def process_tweet_image(tweet, media, date, date_str, tweet_image_num, tweet_num, tweet_count_to_process)

    media_url, media_url_original_resolution, local_filename = \
        media_locators(tweet, media, date, date_str, tweet_image_num)

    stdout_print("  [#{tweet_num}/#{tweet_count_to_process}] Downloading #{media_url}")

    download_file(media_url_original_resolution, local_filename)

    # Rewrite the data so that the archive's index.html
    # will now point to local files... and also so that the script can
    # continue from last point.
    media['media_url_orig'] = media['media_url']
    media['media_url'] = local_filename
  end


  def process_tweet(tweet, tweet_num, media_directory_name, date, tweet_count_to_process)

    media = tweet['entities']['media']

    return 0 if media.nil?

    media_to_download = media.select { |m| ! media_already_downloaded(m) }
    media_download_count = media_to_download.size

    return 0 if media_download_count == 0

    tweet_image_num = 1

    # Build a tweet date string to be used in the filename prefix
    # (only first 19 characters)
    date_str = reformat_date_string_for_filename(tweet['created_at'][0..19])

    FileUtils.mkdir_p(media_directory_name)

    media_to_download.each do |media|
      process_tweet_image(tweet, media, date, date_str, tweet_image_num, tweet_num, tweet_count_to_process)
      tweet_image_num += 1
    end

    media_download_count
  end


  def process_month(date)

    year_month_display_str = "%04d/%02d" % [date['year'], date['month']]
    data_filename, backup_filename, media_directory_name = create_filenames(date)

    unless File.file?(backup_filename)
      FileUtils.cp(data_filename, backup_filename)
    end

    tweets_this_month, first_data_line = read_month_data_file(data_filename)

    image_count_downloaded_for_month = 0

    tweets_to_process = tweets_this_month

    unless options.include_retweets
      tweets_to_process.reject! { |tweet| retweet?(tweet) }
    end

    tweet_count_to_process = tweets_to_process.size
    stdout_print("#{year_month_display_str}: #{tweet_count_to_process} tweets to process...")

    tweets_to_process.each_with_index do |tweet, tweet_num|
      image_count_downloaded_for_month += \
          process_tweet(tweet, tweet_num, media_directory_name, date, tweet_count_to_process)
    end

    # Rewrite the original JSON file so that the archive's index.html
    # will now point to local files... and also so that the script can
    # continue from last point.
    rewrite_js_file(data_filename, first_data_line, tweets_this_month)

    stdout_print(
        "%s: %4i tweets processed, %4i images downloaded.\n" \
        % [year_month_display_str, tweet_count_to_process, image_count_downloaded_for_month])
    image_count_downloaded_for_month
  end



  def call
    puts "Processing download of Twitter archive attachments with the following options:"
    ap options.to_h

    validate_archive_dir
    tweets_by_month = read_index

    puts "To process: #{tweets_by_month.size} months worth of tweets..."
    puts "(You can cancel any time. Next time you run, the script should resume at the last point.)\n\n"

    total_image_count = 0
    tweets_by_month.each do |month|
      puts "\nProcessing month #{month}...\n\n"
      total_image_count += process_month(month)
    end
    puts "\nDone!\n#{total_image_count} images downloaded in total.\n\n"
  end

end
