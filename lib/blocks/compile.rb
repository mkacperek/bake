require 'blocks/blockBase'

require 'multithread/job'
require 'common/process'
require 'common/ext/dir'
require 'common/utils'
require 'bake/toolchain/colorizing_formatter'
require 'bake/config/loader'


begin
require 'Win32API'

def longname short_name
  max_path = 1024
  long_name = " " * max_path
  lfn_size = Win32API.new("kernel32", "GetLongPathName", ['P','P','L'],'L').call(short_name, long_name, max_path)
  return long_name[0..lfn_size-1]
end

def shortname long_name
  max_path = 1024
  short_name = " " * max_path
  lfn_size = Win32API.new("kernel32", "GetShortPathName", ['P','P','L'],'L').call(long_name, short_name, max_path)
  return short_name[0..lfn_size-1]
end

def realname file
    longname(shortname(file))
end

rescue LoadError

def realname file
    file
end

end






module Bake

  module Blocks

    class Compile < BlockBase

      attr_reader :objects, :include_list

      def mutex
        @mutex ||= Mutex.new
      end

      def initialize(block, config, referencedConfigs)
        super(block, config, referencedConfigs)
        @objects = []
        @object_files = {}
        @system_includes = Set.new

        calcFileTcs
        calcIncludes
        calcDefines # not for files with changed tcs
        calcFlags   # not for files with changed tcs
      end

      def get_object_file(source)
        # until now all OBJECT_FILE_ENDING are equal in all three types

        sourceEndingAdapted = @block.tcs[:KEEP_FILE_ENDINGS] ? source : source.chomp(File.extname(source))
        srcWithoutDotDot = sourceEndingAdapted.gsub(/\.\./, "__")
        if srcWithoutDotDot[0] == '/'
          srcWithoutDotDot = "_" + srcWithoutDotDot
        elsif srcWithoutDotDot[1] == ':'
          srcWithoutDotDot = "_" + srcWithoutDotDot[0] + "_" + srcWithoutDotDot[2..-1]
        end

        adaptedSource = srcWithoutDotDot + (Bake.options.prepro ? ".i" : @block.tcs[:COMPILER][:CPP][:OBJECT_FILE_ENDING])

        File.join([@block.output_dir, adaptedSource])
      end

      def ignore?(type)
        Bake.options.linkOnly or (Bake.options.prepro and type == :ASM)
      end

      def needed?(source, object, type, dep_filename_conv)
        return "because analyzer toolchain is configured" if Bake.options.analyze
        return "because prepro was specified and source is no assembler file" if Bake.options.prepro

        Dir.mutex.synchronize do
          Dir.chdir(@projectDir) do
            return "because object does not exist" if not File.exist?(object)
            oTime = File.mtime(object)

            return "because source is newer than object" if oTime < File.mtime(source)

            if type != :ASM
              return "because dependency file does not exist" if not File.exist?(dep_filename_conv)

              begin
                File.readlines(dep_filename_conv).map{|line| line.strip}.each do |dep|
                  Thread.current[:filelist].add(File.expand_path(dep, @projectDir)) if Bake.options.filelist

                  if not File.exist?(dep)
                    # we need a hack here. with some windows configurations the compiler prints unix paths
                    # into the dep file which cannot be found easily. this will be true for system includes,
                    # e.g. /usr/lib/...xy.h
                    if (Bake::Utils::OS.windows? and dep.start_with?"/") or
                      (not Bake::Utils::OS.windows? and dep.length > 1 and dep[1] == ":")
                      puts "Dependency header file #{dep} ignored!" if Bake.options.debug
                    else
                      return "because dependent header #{dep} does not exist"
                    end
                  else
                    return "because dependent header #{dep} is newer than object" if oTime < File.mtime(dep)
                  end
                end
              rescue Exception => ex
                if Bake.options.debug
                  puts "While reading #{dep_filename_conv}:"
                  puts ex.message
                  puts ex.backtrace
                end
                return "because dependency file could not be loaded"
              end
            end
          end
        end
        return false
      end

      def calcCmdlineFile(object)
        File.expand_path(object[0..-3] + ".cmdline", @projectDir)
      end

      def calcDepFile(object, type)
        dep_filename = nil
        if type != :ASM
          dep_filename = object[0..-3] + ".d"
        end
        dep_filename
      end

      def calcDepFileConv(dep_filename)
        dep_filename + ".bake"
      end

      def get_source_type(source)
        ex = File.extname(source)
        [:CPP, :C, :ASM].each do |t|
          return t if @block.tcs[:COMPILER][t][:SOURCE_FILE_ENDINGS].include?(ex)
        end
        nil
      end

      def compileFile(source)
        type = get_source_type(source)
        return if type.nil?

        @headerFilesFromDep = []

        object = @object_files[source]

        dep_filename = calcDepFile(object, type)
        dep_filename_conv = calcDepFileConv(dep_filename) if type != :ASM

        cmdLineCheck = false
        cmdLineFile = calcCmdlineFile(object)

        return if ignore?(type)
        reason = needed?(source, object, type, dep_filename_conv)
        if not reason
          cmdLineCheck = true
          reason = config_changed?(cmdLineFile)
        end

        Thread.current[:filelist].add(File.expand_path(source, @projectDir)) if Bake.options.filelist

        if @fileTcs.include?(source)
          compiler = @fileTcs[source][:COMPILER][type]
          defines = getDefines(compiler)
          flags = getFlags(compiler)
        else
          compiler = @block.tcs[:COMPILER][type]
          defines = @define_array[type]
          flags = @flag_array[type]
        end
        includes = @include_array[type]

        if Bake.options.prepro and compiler[:PREPRO_FLAGS] == ""
          Bake.formatter.printError("Error: No preprocessor option available for " + source)
          raise SystemCommandFailed.new
        end

        cmd = Utils.flagSplit(compiler[:PREFIX], true)
        cmd += Utils.flagSplit(compiler[:COMMAND], true)
        cmd += compiler[:COMPILE_FLAGS].split(" ")

        if dep_filename
          cmd += @block.tcs[:COMPILER][type][:DEP_FLAGS].split(" ")
          if @block.tcs[:COMPILER][type][:DEP_FLAGS_FILENAME]
            if @block.tcs[:COMPILER][type][:DEP_FLAGS_SPACE]
              cmd << dep_filename
            else
              if dep_filename.include?" "
                cmd[cmd.length-1] << "\"" + dep_filename + "\""
              else
                cmd[cmd.length-1] << dep_filename
              end

            end
          end
        end

        cmd += compiler[:PREPRO_FLAGS].split(" ") if Bake.options.prepro
        cmd += flags
        cmd += includes
        cmd += defines

        offlag = compiler[:OBJECT_FILE_FLAG]
        offlag = compiler[:PREPRO_FILE_FLAG] if compiler[:PREPRO_FILE_FLAG] and Bake.options.prepro

        if compiler[:OBJ_FLAG_SPACE]
          cmd << offlag
          cmd << object
        else
          if object.include?" "
            cmd << offlag + "\"" + object + "\""
          else
            cmd << offlag + object
          end
        end
        cmd << source

        if Bake.options.cc2j_filename
          cmdJson = cmd.is_a?(Array) ? cmd.join(' ') : cmd
          Blocks::CC2J << { :directory => @projectDir, :command => cmdJson, :file => File.join(@projectDir, source) }
        end

        if not (cmdLineCheck and BlockBase.isCmdLineEqual?(cmd, cmdLineFile))
          BlockBase.prepareOutput(File.expand_path(object,@projectDir))
          outputType = Bake.options.analyze ? "Analyzing" : (Bake.options.prepro ? "Preprocessing" : "Compiling")
          printCmd(cmd, "#{outputType} #{@projectName} (#{@config.name}): #{source}", reason, false)
          SyncOut.flushOutput()
          BlockBase.writeCmdLineFile(cmd, cmdLineFile)

          success = true
          consoleOutput = ""
          success, consoleOutput = ProcessHelper.run(cmd, false, false, nil, [0], @projectDir) if !Bake.options.dry
          incList = process_result(cmd, consoleOutput, compiler[:ERROR_PARSER], nil, reason, success)
          if type != :ASM and not Bake.options.analyze and not Bake.options.prepro
            Dir.mutex.synchronize do
              Dir.chdir(@projectDir) do
                incList = Compile.read_depfile(dep_filename, @projectDir, @block.tcs[:COMPILER][:DEP_FILE_SINGLE_LINE]) if incList.nil?
                Compile.write_depfile(source, incList, dep_filename_conv, @projectDir)
              end
            end

            incList.each do |h|
              Thread.current[:filelist].add(File.expand_path(h, @projectDir))
            end if Bake.options.filelist
          end
          check_config_file
        else
          if Bake.options.filename and Bake.options.verbose >= 1
            puts "Up-to-date #{source}"
            SyncOut.flushOutput()
          end
        end



      end

      def self.read_depfile(dep_filename, projDir, singleLine)
        deps = []
        begin
          if singleLine
            File.readlines(dep_filename).each do |line|
              splitted = line.split(": ")
              if splitted.length > 1
                deps << splitted[1].gsub(/[\\]/,'/')
              else
                splitted = line.split(":\t") # right now only for tasking compiler
                if splitted.length > 1
                  dep = splitted[1].gsub(/[\\]/,'/').strip
                  dep = dep[1..-2] if dep.start_with?("\"")
                  deps << dep
                end
              end
            end
          else
            deps_string = File.read(dep_filename)
            deps_string = deps_string.gsub(/\\\n/,'')
            dep_splitted = deps_string.split(/([^\\]) /).each_slice(2).map(&:join)[2..-1]
            deps = dep_splitted.map { |d| d.gsub(/[\\] /,' ').gsub(/[\\]/,'/').strip }.delete_if {|d| d == "" }
          end
        rescue Exception => ex1
          if !Bake.options.dry
            Bake.formatter.printWarning("Could not read '#{dep_filename}'", projDir)
            puts ex1.message if Bake.options.debug
          end
          return nil
        end
        deps
      end

      # todo: move to toolchain util file
      def self.write_depfile(source, deps, dep_filename_conv, projDir)
        if deps && !Bake.options.dry
          wrongCase = false
          begin
            File.open(dep_filename_conv, 'wb') do |f|
              deps.each do |dep|
                f.puts(dep)

                if (Bake.options.caseSensitivityCheck)
                  if dep.length<2 || dep[1] != ":"
                    real = realname(dep)
                    if dep != real && dep.upcase == real.upcase
                      Bake.formatter.printError("Case sensitivity error in #{source}:\n  included: #{dep}\n  realname: #{real}")
                      wrongCase = true
                    end
                  end
                end

              end
            end
          rescue Exception
            Bake.formatter.printWarning("Could not write '#{dep_filename_conv}'", projDir)
            return nil
          end
          if wrongCase
            FileUtils.rm_f(dep_filename_conv)
            raise SystemCommandFailed.new
          end
        end
      end

      def execute
        #Dir.chdir(@projectDir) do

          SyncOut.mutex.synchronize do
            calcSources
            calcObjects
          end

          fileListBlock = Set.new if Bake.options.filelist
          compileJobs = Multithread::Jobs.new(@source_files) do |jobs|
            while source = jobs.get_next_or_nil do

              if (jobs.failed && Bake.options.stopOnFirstError) or Bake::IDEInterface.instance.get_abort
                break
              end

              SyncOut.startStream()
              begin
                Thread.current[:filelist] = Set.new if Bake.options.filelist
                Thread.current[:lastCommand] = nil

                result = false
                begin
                  compileFile(source)
                  result = true
                rescue Bake::SystemCommandFailed => scf # normal compilation error
                rescue SystemExit => exSys
                rescue Exception => ex1
                  if not Bake::IDEInterface.instance.get_abort
                    Bake.formatter.printError("Error: #{ex1.message}")
                    puts ex1.backtrace if Bake.options.debug
                  end
                end

                jobs.set_failed if not result
              ensure
                SyncOut.stopStream()
              end
              self.mutex.synchronize do
                fileListBlock.merge(Thread.current[:filelist]) if Bake.options.filelist
              end

            end
          end
          compileJobs.join

          if Bake.options.filelist && !Bake.options.dry
            Bake.options.filelist.merge(fileListBlock.merge(fileListBlock))

            odir = File.expand_path(@block.output_dir, @projectDir)
            FileUtils.mkdir_p(odir)
            File.open(odir + "/" + "file-list.txt", 'wb') do |f|
              fileListBlock.sort.each do |entry|
                f.puts(entry)
              end
            end

          end

          raise SystemCommandFailed.new if compileJobs.failed

        #end
        return true
      end

      def clean
        if (Bake.options.filename or Bake.options.analyze)
          Dir.chdir(@projectDir) do
            calcSources(true)
            @source_files.each do |source|

              type = get_source_type(source)
              next if type.nil?
              object = get_object_file(source)
              if File.exist?object
                puts "Deleting file #{object}" if Bake.options.verbose >= 2
                if !Bake.options.dry
                  FileUtils.rm_rf(object)
                end
              end
              if not Bake.options.analyze
                dep_filename = calcDepFile(object, type)
                if dep_filename and File.exist?dep_filename
                  puts "Deleting file #{dep_filename}" if Bake.options.verbose >= 2
                  if !Bake.options.dry
                    FileUtils.rm_rf(dep_filename)
                  end
                end
                cmdLineFile = calcCmdlineFile(object)
                if File.exist?cmdLineFile
                  puts "Deleting file #{cmdLineFile}" if Bake.options.verbose >= 2
                  if !Bake.options.dry
                    FileUtils.rm_rf(cmdLineFile)
                  end
                end
              end
            end
          end
        end
        return true
      end

      def calcObjects
        @source_files.each do |source|
          type = get_source_type(source)
          if not type.nil?
            object = get_object_file(source)
            if @objects.include?object
              @object_files.each do |k,v|
                if (v == object) # will be found exactly once
                  Bake.formatter.printError("Source files '#{k}' and '#{source}' would result in the same object file", source)
                  raise SystemCommandFailed.new
                end
              end
            end
            @object_files[source] = object
            @objects << object
          end
        end
      end

      def calcSources(cleaning = false, keep = false)
        return @source_files if @source_files and not @source_files.empty?
        @source_files = []

        exclude_files = Set.new
        @config.excludeFiles.each do |pr|
          Dir.glob_dir(pr.name, @projectDir).each {|f| exclude_files << f}
        end

        source_files = Set.new
        @config.files.each do |sources|
          pr = sources.name
          pr = pr[2..-1] if pr.start_with?"./"

          res = Dir.glob_dir(pr, @projectDir).sort
          if res.length == 0 and cleaning == false
            if not pr.include?"*" and not pr.include?"?"
              Bake.formatter.printError("Source file '#{pr}' not found", sources)
              raise SystemCommandFailed.new
            elsif Bake.options.verbose >= 1
              Bake.formatter.printInfo("Source file pattern '#{pr}' does not match to any file", sources)
            end
          end
          res.each do |f|
            next if exclude_files.include?(f)
            next if source_files.include?(f)
            source_files << f
            @source_files << f
          end
        end

        if Bake.options.filename
          @source_files.keep_if do |source|
            source.include?Bake.options.filename
          end
          if @source_files.length == 0 and cleaning == false and @config.files.length > 0 and Bake.options.verbose >= 2
            Bake.formatter.printInfo("#{Bake.options.filename} does not match to any source", @config)
          end
        end

        if Bake.options.eclipseOrder # directories reverse order, files in directories in alphabetical order
          dirs = []
          filemap = {}
          @source_files.sort.reverse.each do |o|
            d = File.dirname(o)
            if filemap.include?(d)
              filemap[d] << o
            else
              filemap[d] = [o]
              dirs << d
            end
          end
          @source_files = []
          dirs.each do |d|
            filemap[d].reverse.each do |f|
              @source_files << f
            end
          end
        end

        @source_files
      end

      def mapInclude(inc, orgBlock)

        if inc.name == "___ROOTS___"
          return Bake.options.roots.map { |r| File.rel_from_to_project(@projectDir,r.dir,false) }
        end

        i = orgBlock.convPath(inc,nil,true)
        if orgBlock != @block
          if not File.is_absolute?(i)
            i = File.rel_from_to_project(@projectDir,orgBlock.config.parent.get_project_dir) + i
          end
        end

        Pathname.new(i).cleanpath
      end

      def calcIncludesInternal(block)
        @blocksRead << block
        block.config.baseElement.each do |be|
          if Metamodel::IncludeDir === be
            if be.inherit == true || block == @block
              mappedInc = mapInclude(be, block)
              @include_list << mappedInc
              @system_includes << mappedInc if be.system
            end
          elsif Metamodel::Dependency === be
            childBlock = block.depToBlock[be.name + "," + be.config]
            calcIncludesInternal(childBlock) if !@blocksRead.include?(childBlock)
          end
        end
      end

      def calcIncludes

        @blocksRead = Set.new
        @include_list = []
        @system_includes = Set.new
        calcIncludesInternal(@block) # includeDir and child dependencies with inherit: true

        @block.getBlocks(:parents).each do |b|
          if b.config.respond_to?("includeDir")
            include_list_front = []
            b.config.includeDir.each do |inc|
              if inc.inject == "front" || inc.infix == "front"
                mappedInc = mapInclude(inc, b)
                include_list_front << mappedInc
                @system_includes << mappedInc if inc.system
              elsif inc.inject == "back" || inc.infix == "back"
                mappedInc = mapInclude(inc, b)
                @include_list << mappedInc
                @system_includes << mappedInc if inc.system
              end
            end
            @include_list = include_list_front + @include_list
          end
        end

        @include_list = @include_list.flatten.uniq

        @include_array = {}
        [:CPP, :C, :ASM].each do |type|
          @include_array[type] = @include_list.map do |k|
            if @system_includes.include?(k)
              "#{@block.tcs[:COMPILER][type][:SYSTEM_INCLUDE_PATH_FLAG]}#{k}"
            else
              "#{@block.tcs[:COMPILER][type][:INCLUDE_PATH_FLAG]}#{k}"
            end
          end
        end
      end

      def getDefines(compiler)
        compiler[:DEFINES].map {|k| "#{compiler[:DEFINE_FLAG]}#{k}"}
      end

      def getFlags(compiler)
        Bake::Utils::flagSplit(compiler[:FLAGS],true)
      end

      def calcDefines
        @define_array = {}
        [:CPP, :C, :ASM].each do |type|
          @define_array[type] = getDefines(@block.tcs[:COMPILER][type])
        end
      end
      def calcFlags
        @flag_array = {}
        [:CPP, :C, :ASM].each do |type|
          @flag_array[type] = getFlags(@block.tcs[:COMPILER][type])
        end
      end

      def calcFileTcs
        @fileTcs = {}
        @config.files.each do |f|
          if (f.define.length > 0 or f.flags.length > 0)
            if f.name.include?"*"
              Bake.formatter.printWarning("Toolchain settings not allowed for file pattern #{f.name}", f)
              err_res = ErrorDesc.new
              err_res.file_name = @config.file_name
              err_res.line_number = f.line_number
              err_res.severity = ErrorParser::SEVERITY_WARNING
              err_res.message = "Toolchain settings not allowed for file patterns"
              Bake::IDEInterface.instance.set_errors([err_res])
            else
              @fileTcs[f.name] = integrateCompilerFile(Utils.deep_copy(@block.tcs),f)
            end
          end
        end
      end

      def tcs4source(source)
        @fileTcs[source] || @block.tcs
      end


    end

  end
end