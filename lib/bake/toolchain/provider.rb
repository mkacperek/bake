module Bake
  module Toolchain

    def self.outputEnding(tcs = nil)
      if tcs && tcs[:LINKER][:OUTPUT_ENDING] != ""
        return tcs[:LINKER][:OUTPUT_ENDING]
      end
      Bake::Utils::OS.windows? ? ".exe" : ""
    end

    class Provider
      @@settings = {}
      @@default = {
        :COMPILER =>
        {
          :CPP => {
            :COMMAND => "",
            :PREFIX => "$(CompilerPrefix)",
            :DEFINE_FLAG => "",
            :OBJECT_FILE_FLAG => "",
            :OBJECT_FILE_ENDING => ".o",
            :OBJ_FLAG_SPACE => false,
            :INCLUDE_PATH_FLAG => "-I",
            :SYSTEM_INCLUDE_PATH_FLAG => "-I",
            :COMPILE_FLAGS => "",
            :DEFINES => [],
            :FLAGS => "",
            :SOURCE_FILE_ENDINGS => [".cxx", ".cpp", ".c++", ".cc", ".C"],
            :DEP_FLAGS => "",
            :DEP_FLAGS_SPACE => false,
            :DEP_FLAGS_FILENAME => true,
            :ERROR_PARSER => nil,
            :PREPRO_FLAGS => "",
            :PREPRO_FILE_FLAG => nil
          },
          :C => {
            :COMMAND => "",
            :PREFIX => "$(CompilerPrefix)",
            :DEFINE_FLAG => "",
            :OBJECT_FILE_FLAG => "",
            :OBJECT_FILE_ENDING => ".o",
            :OBJ_FLAG_SPACE => false,
            :INCLUDE_PATH_FLAG => "-I",
            :SYSTEM_INCLUDE_PATH_FLAG => "-I",
            :COMPILE_FLAGS => "",
            :DEFINES => [],
            :FLAGS => "",
            :SOURCE_FILE_ENDINGS => [".c", ".cu"],
            :DEP_FLAGS => "",
            :DEP_FLAGS_SPACE => false,
            :DEP_FLAGS_FILENAME => true,
            :ERROR_PARSER => nil,
            :PREPRO_FLAGS => "",
            :PREPRO_FILE_FLAG => nil
          },
          :ASM => {
            :COMMAND => "",
            :PREFIX => "$(CompilerPrefix)",
            :DEFINE_FLAG => "",
            :OBJECT_FILE_FLAG => "",
            :OBJECT_FILE_ENDING => ".o",
            :OBJ_FLAG_SPACE => false,
            :INCLUDE_PATH_FLAG => "-I",
            :SYSTEM_INCLUDE_PATH_FLAG => "-I",
            :COMPILE_FLAGS => "",
            :DEFINES => [],
            :FLAGS => "",
            :SOURCE_FILE_ENDINGS => [".asm", ".s", ".S"],
            :DEP_FLAGS => "",
            :DEP_FLAGS_SPACE => false,
            :DEP_FLAGS_FILENAME => true,
            :ERROR_PARSER => nil,
            :PREPRO_FLAGS => "",
            :PREPRO_FILE_FLAG => nil
          }
        },

        :ARCHIVER =>
        {
          :COMMAND => "",
          :PREFIX => "$(ArchiverPrefix)",
          :ARCHIVE_FLAGS => "",
          :ARCHIVE_FLAGS_SPACE => true,
          :FLAGS => "",
          :ERROR_PARSER => nil
        },

        :LINKER =>
        {
          :COMMAND => "",
          :PREFIX => "$(LinkerPrefix)",
          :MUST_FLAGS => "",
          :SCRIPT => "",
          :SCRIPT_SPACE => true,
          :USER_LIB_FLAG => "",
          :EXE_FLAG => "",
          :EXE_FLAG_SPACE => true,
          :LIB_FLAG => "",
          :LIB_PATH_FLAG => "",
          :LIB_PREFIX_FLAGS => "", # "-Wl,--whole-archive",
          :LIB_POSTFIX_FLAGS => "", # "-Wl,--no-whole-archive",
          :FLAGS => "",
          :MAP_FILE_FLAG => "",
          :MAP_FILE_PIPE => true,
          :OUTPUT_ENDING => "", # if empty, .exe is used on Windows, otherwise no ending
          :ERROR_PARSER => nil,
          :LIST_MODE => false
        },

        :MAKE =>
        {
          :COMMAND => "make",
          :FLAGS => "-j",
          :FILE_FLAG => "-f",
          :DIR_FLAG => "-C",
          :CLEAN => "clean"
        },

        :DEP_FILE_SINGLE_LINE => false,
        :DOCU => "",
        :KEEP_FILE_ENDINGS => false
      }

      def self.add(name, basedOn = nil)
        chain = Marshal.load(Marshal.dump(basedOn.nil? ? @@default : @@settings[basedOn]))
        @@settings[name] = chain
        chain
      end

      def self.default
        @@default
      end

      def self.modify_cpp_compiler(based_on, h)
        chain = Marshal.load(Marshal.dump(@@settings[based_on]))
        chain[:COMPILER][:CPP].update(h)
        chain
      end

      def self.[](name)
        return @@settings[name] if @@settings.include? name
        nil
      end

      def self.list
        return @@settings
      end

    end

  end
end

require 'bake/toolchain/diab'
require 'bake/toolchain/gcc'
require 'bake/toolchain/clang'
require 'bake/toolchain/clang_analyze'
require 'bake/toolchain/ti'
require 'bake/toolchain/greenhills'
require 'bake/toolchain/keil'
require 'bake/toolchain/msvc'
require 'bake/toolchain/gcc_env'
require 'bake/toolchain/tasking'
