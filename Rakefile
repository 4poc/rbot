require 'rubygems'
require 'rake'
require 'rake/gempackagetask'

task :default => [:repackage]

spec = Gem::Specification.new do |s|
  s.name = 'rbot'
  s.version = '0.9.11'
  s.summary = <<-EOF
    A modular ruby IRC bot.
  EOF
  s.description = <<-EOF
    A modular ruby IRC bot specifically designed for ease of extension via plugins.
  EOF
  s.requirements << 'Ruby, version 1.8.0 (or newer)'

  #  s.files = Dir.glob("**/*").delete_if { |item| item.include?(".svn") }
  s.files = FileList['lib/**/*.rb', 'bin/*', 'data/**/*', 'AUTHORS', 'COPYING', 'README', 'REQUIREMENTS', 'TODO', 'ChangeLog', 'INSTALL',  'Usage_en.txt', 'setup.rb'].to_a.delete_if {|item| item == ".svn"}
  s.executables << 'rbot'

#  s.autorequire = 'rbot/ircbot'
  s.has_rdoc = true
  s.rdoc_options = ['--exclude', 'post-install.rb',
  '--title', 'rbot API Documentation', '--main', 'README', 'README']

  s.author = 'Tom Gilbert'
  s.email = 'tom@linuxbrit.co.uk'
  s.homepage = 'http://ruby-rbot.org'
  s.rubyforge_project = 'rbot'
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

# normalize a po/pot file
def normalize_po(fn)
  content = File.read(fn)

  # replace project-id-version placholder
  modified = content.sub!(/^("Project-Id-Version: )PACKAGE VERSION(\\n")$/) {
    "#{$1}rbot#{$2}"
  }

  # sort the messages by file location
  if MSGCAT
    sorted = `#{MSGCAT} --width=79 --sort-by-file #{fn}`
    if sorted != content
      content = sorted
      modified = true
    end
  end

  if modified
    File.open(fn, 'w') {|f| f.write content}
  end
end

PLUGIN_FILES = FileList['data/rbot/plugins/**/*.rb']
NON_PLUGIN_FILES = FileList["{lib,bin,data}/**/*.{rb,rhtml}"] - PLUGIN_FILES

# this task defines how po files and pot files are made. those rules are not defined
# normally because po and pot files should be only updated in the updatepo task,
# but po files are also prereqs for makemo
task :define_po_rules do
  # generate pot file from rb files
  rgettext_proc = proc do |t|
    require 'gettext/utils'
    source_files, pot_file = t.prerequisites, t.name
    new_pot_file = "#{pot_file}.new"
    puts "#{source_files.join(', ')} => #{pot_file}"
    GetText.rgettext(source_files, new_pot_file)

    # only use the new pot file if it contains unique messages
    if MSGCOMM && `#{MSGCOMM} --unique #{pot_file} #{new_pot_file}`.empty?
      rm new_pot_file
    else
      mv new_pot_file, pot_file
    end

    normalize_po(pot_file)
    
    # save all this work until rb files are updated again
    touch pot_file
  end

  # generate pot file for non-plugin files
  file('po/rbot.pot' => NON_PLUGIN_FILES, &rgettext_proc)

  # generate pot files for plugin files
  rule(%r'^po/.+\.pot$' => proc {|fn|
    PLUGIN_FILES.select {|f| f.pathmap('rbot-%n') == fn.pathmap('%n')}
  }, &rgettext_proc)

  # map the po file to its source pot file
  pot_for_po = proc {|fn| fn.pathmap '%{^po/.+/,po/}X.pot'}

  # update po file from pot file
  msgmerge_proc = proc do |t|
    require 'gettext/utils'
    po_file, pot_file = t.name, t.source
    puts "#{pot_file} => #{po_file}"
    sh "#{MSGMERGE} --backup=off --update #{po_file} #{pot_file}"
    normalize_po(po_file)
    touch po_file
  end

  # generate English po files
  file(%r'^po/en_US/.+\.po$' => pot_for_po) do |t|
    po_file, pot_file = t.name, t.source
    if MSGEN
      sh "#{MSGEN} --output-file=#{po_file} #{pot_file}"
      normalize_po(po_file)
      touch po_file
    else
      msgmerge_proc.call t
    end
  end

  # update po files
  rule(%r'^po/.+/.+\.po$' => pot_for_po, &msgmerge_proc)
end

# generate mo files
rule(%r'^data/locale/.+/LC_MESSAGES/.+\.mo$' => proc {|fn|
  [ fn.pathmap('%{^data/locale,po;LC_MESSAGES/,}X.po'), 
    # the directory is created if not existing
    fn.pathmap('%d') ]
}) do |t|
  po_file, mo_file = t.source, t.name
  puts "#{po_file} => #{mo_file}"
  require 'gettext/utils'
  GetText.rmsgfmt po_file, mo_file
end

task :check_po_tools do
  have = {}

  po_tools = {
    'msgmerge' => {
      :options => %w[--backup= --update],
      :message => 'Cannot update po files' },
    'msgcomm' => {
      :options => %w[--unique],
      :message => 'Pot files may be modified even without message change' },
    'msgen' => {
      :options => %w[--output-file],
      :message => 'English po files will not be generated' },
    'msgcat' => {
      :options => %w[--width= --sort-by-file],
      :message => 'Pot files will not be normalized' }
  }

  po_tools.each_pair do |command, value|
    path = ENV["#{command.upcase}_PATH"] || command
    have_it = have[command] = value[:options].all? do |option|
      `#{path} --help`.include? option
    end
    Object.const_set(command.upcase, have_it ? path : false)
    warn "#{command} not found. #{value[:message]}" unless have_it
  end
  abort unless MSGMERGE
end

PLUGIN_BASENAMES = PLUGIN_FILES.map {|f| f.pathmap('%n')}
LOCALES = FileList['po/*/'].map {|d| d.pathmap('%n')}

LOCALES.each do |l|
  directory "data/locale/#{l}/LC_MESSAGES"
end

desc 'Update po files'
task :updatepo => [:define_po_rules, :check_po_tools] + LOCALES.map {|l|
  ["po/#{l}/rbot.po"] +
  PLUGIN_BASENAMES.map {|n| "po/#{l}/rbot-#{n}.po"}
}.flatten

desc 'Normalize po files'
task :normalizepo => :check_po_tools do
  FileList['po/*/*.po'].each {|fn| normalize_po(fn)}
end

desc 'Generate mo files'
task :makemo => LOCALES.map {|l|
  ["data/locale/#{l}/LC_MESSAGES/rbot.mo"] +
  PLUGIN_BASENAMES.map {|n| "data/locale/#{l}/LC_MESSAGES/rbot-#{n}.mo"}
}.flatten

