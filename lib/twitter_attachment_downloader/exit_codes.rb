# Exit Codes for code throughout the application.

class ExitCodes

  CODES =     {
      archive_root_dir_missing:   -1,
      tweet_master_index_missing: -2,
      download_failed:            -3,
      index_file_missing:         -4,
      keyboard_interrupt:         -5
  }

  # e.g. ExitCodes.for(:download_failed) => -3
  def self.for(reason)
    if CODES.keys.include?(reason)
      CODES[reason]
    else
      $stderr.puts "ExitCodes: Unknown reason: #{reason.inspect}"
      -9999
    end
  end
end