#!/usr/bin/env ruby
#
# This code is free software; you can redistribute it and/or modify it under the
# terms of the new BSD License.
#
# Copyright (c) 2009, Sebastian Staudt

require 'fileutils'

OPTIONS = $*.reject{|a| a.match(/^--/)}
RELEASE_VERSION = OPTIONS[0]
TARGET_DIR = File.expand_path(OPTIONS[1] || '.')
@@exit_code = 0

# This function tries to build the Ruby Gem
def build_gem
  FileUtils.cd('tmp/ruby')
  $stdout << 'Building Ruby Gem...'
  $stdout.flush
  output = `rake build 2>&1`
  if $?.exitstatus != 0
    puts " \033[0;31mfailed!\033[0;0m"
    puts 'Output was:', output
    @@exit_code = $?.exitstatus
    FileUtils.cd('../..')
    cleanup
  end
  puts " \033[1;32mOK!\033[0;0m"
  puts 'Moving Gem to temporary directory...'
  FileUtils.mv("pkg/steam-condenser-#{RELEASE_VERSION}.gem", '..')
  FileUtils.cd('../..')
end

# This function tries to build the Java JAR
def build_jar
  FileUtils.cd('tmp/java')
  $stdout << 'Building Java JAR...'
  $stdout.flush
  output = `ant -Drelease.version=#{RELEASE_VERSION} 2>&1`
  if $?.exitstatus != 0
    puts " \033[0;31mfailed!\033[0;0m"
    puts 'Output was:', output
    @@exit_code = $?.exitstatus
    FileUtils.cd('../..')
    cleanup
  end
  puts " \033[1;32mOK!\033[0;0m"
  puts 'Moving JAR to temporary directory...'
  FileUtils.mv("dist/steam-condenser-#{RELEASE_VERSION}.jar", '..')
  FileUtils.cd('../..')
end

# This function is a wrapper for building the Ruby Gem and Java JAR
def build_packages
  puts "Now building release packages for Steam Condenser version \033[1;37m#{RELEASE_VERSION}\033[0;0m."
  build_gem
  build_jar
end

# This function builds GZip and Bzip2 compressed tar archives of the sources for
# each programming language
def build_src_archives
  FileUtils.cd('tmp')
  %w(java php ruby).each do |l|
    puts "Creating source archives for #{l}..."
    `tar czf steam-condenser-#{RELEASE_VERSION}-#{l}.tar.gz -C #{l} .`
    `tar cjf steam-condenser-#{RELEASE_VERSION}-#{l}.tar.bz2 -C #{l} .`
  end
  FileUtils.cd('..')
end

# This function checks the version string syntax and the target directory
def check_parameters
  if RELEASE_VERSION.nil? or !RELEASE_VERSION.match(/^[0-9]+.[0-9]+.[0-9]+$/)
    warn "Error: Incorrect version string.\n"
    print_help
  end

  if File.exists? TARGET_DIR
    unless File.directory? TARGET_DIR
      warn "Error: Given target is not a directory.\n"
      print_help
    end
  else
    puts "Given target directory \"#{TARGET_DIR}\" does not exist."
    $stdout << "Do you want to create it? [y]: "
    reply = $stdin.readchar.chr
    if reply == "\r" or reply == "y"
      puts "Creating target directory..."
      FileUtils.mkdir_p(TARGET_DIR)
    else
      exit(4)
    end
  end
end

# This function checks for the Git repository for the tag specified by
# +version+. If the tag does not exist, it can be created.
def check_version
  if `which git`.empty?
    puts 'Git is required for this script.'
    exit(2)
  else
    git_tags = `git tag`.split
    unless git_tags.include? RELEASE_VERSION
      puts "The Git repository doesn't contain a tag named \033[1;37m#{RELEASE_VERSION}\033[0;0m."
      $stdout << 'Do you want to create it now? [n]: '
      if $stdin.readchar.chr == 'y'
        puts 'Creating Git tag...'
        `git tag -s #{RELEASE_VERSION} -m "Tagged version #{RELEASE_VERSION}"`
      else
        exit(3)
      end
    end
  end
end

# This function exports the contents of the Git repository tagged with the
# selected version string
def checkout_tmp
  FileUtils.mkdir('tmp')
  puts "Checking out contents of tag \033[1;37m#{RELEASE_VERSION}\033[0;0m to tmp/"
  `git archive #{RELEASE_VERSION} | tar xC tmp`
  return $?.exitstatus == 0
end

# This function calculates checksums for all created files using OpenSSL and the
# MD5 and SHA1 hash algorithms
def checksums
  FileUtils.cd('tmp')
  puts 'Calculating package checksums...'
  @@checksums = {}
  files = Dir.glob('steam-condenser-*')
  files.each { |file| @@checksums[file] = {} }
  files = files.join(' ')

  md5 = `openssl md5 #{files}`.split("\n")
  md5.each do |hash|
    hash.match(/MD5\((.*)\)= ([a-f0-9]{32})/)
    @@checksums[$1][:md5] = $2
  end
  
  sha1 = `openssl sha1 #{files}`.split("\n")
  sha1.each do |hash|
    hash.match(/SHA1\((.*)\)= ([a-f0-9]{40})/)
    @@checksums[$1][:sha1] = $2
  end

  @@checksums.each do |file, checksum|
    puts "    \033[1;37m#{file}\033[0;0m:"
    puts "\t\033[1;30mMD5:  \033[1;32m#{checksum[:md5]}\033[0;0m"
    puts "\t\033[1;30mSHA1: \033[1;32m#{checksum[:sha1]}\033[0;0m"
  end

  FileUtils.cd('..')
end

# This function deletes the temporary directory and exits the script
def cleanup
  puts 'Cleaning up...'
  FileUtils.rm_r('tmp')
  exit(@@exit_code)
end

# This functions moves the created files from the temporary directory to the
# given target directory
def move_to_target_dir
  puts "Moving files to #{TARGET_DIR}/ ..."
  files = Dir.glob('tmp/steam-condenser-*')
  FileUtils.mv(files, TARGET_DIR)
end

# This function prints out a help screen and exits the script
def print_help
  puts "Usage: #{$0} [options] version [target]\n\n"
  puts "  version\t\tA string of three integers separated by dots"
  puts "\t\t\tIf this is a tag in the Git repository, the code will be"
  puts "\t\t\texported to the temporary directory. Otherwise ..."
  puts "  target\t\tThe directory the created files should be saved to\n\n"
  puts "  --help\t\tShows this help"
  puts "  --no-archives\t\tDo not create source archives."
  puts "  --no-cleanup\t\tDo not remove the temporary directory."
  puts "  --no-packages\t\tDo not create language specific packages like Ruby Gem."
  exit(0)
end

# This is the main body of the script implementing the basic logic
print_help if $*.include? '--help'
check_parameters
check_version
checkout_tmp
build_packages unless $*.include? '--no-packages'
build_src_archives unless $*.include? '--no-archives'
checksums
move_to_target_dir
cleanup unless $*.include? '--no-cleanup'
puts "\033[1;32mdone.\033[0;0m"