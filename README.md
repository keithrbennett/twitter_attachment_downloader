# TwitterAttachmentDownloader

Twitter offers an archive download of users' tweets, but this archive does not contain
the attachments (such as photos).

This script downloads the files and modifies the HTML and JavaScript so that
when the archive is opened in a browser, the files are retrieved locally
instead of from Twitter servers.

Much/most of the logic has been copied from the Python script
"Twitter export image fill 1.02" by Marcin Wichary (aresluna.org)
at https://github.com/mwichary/twitter-export-image-fill
