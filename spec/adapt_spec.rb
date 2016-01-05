#!/usr/bin/env ruby

require 'common/version'

require 'bake/options/options'
require 'bake/util'
require 'common/exit_helper'
require 'socket'
require 'fileutils'
require 'helper'

module Bake

  # todo: timestand adapt file
  # scope __MAIN__ etc...
  # mehrere kaskadiert
  # docu fix von syntax popup diag
  # adapt filename in cache -> wenn anders, dann neu einlesen  - achtung test lösche cache immer...
  
describe "Adapt" do

  it 'Dep extend 0' do
    Bake.startBake("adapt/main", ["test_dep0", "--rebuild", "--adapt", "dep_extend"])
    expect($mystring.include?("Building 1 of 4: lib1 (test_other)")).to be == true
    expect($mystring.include?("Building 2 of 4: lib1 (test_ok)")).to be == true
    expect($mystring.include?("Building 3 of 4: lib3 (test_ok)")).to be == true
    expect($mystring.include?("Building 4 of 4: main (test_dep0)")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end  
  
  it 'Dep extend 2' do
    Bake.startBake("adapt/main", ["test_dep2", "--rebuild", "--adapt", "dep_extend"])
    expect($mystring.include?("Building 1 of 5: lib1 (test_ok)")).to be == true
    expect($mystring.include?("Building 2 of 5: lib2 (test_ok)")).to be == true
    expect($mystring.include?("Building 3 of 5: lib1 (test_other)")).to be == true
    expect($mystring.include?("Building 4 of 5: lib3 (test_ok)")).to be == true
    expect($mystring.include?("Building 5 of 5: main (test_dep2)")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end

  it 'Dep remove 0' do
    Bake.startBake("adapt/main", ["test_dep0", "--rebuild", "--adapt", "dep_remove"])
    expect($mystring.include?("Building 1 of 1: main (test_dep0)")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end  
  
  it 'Dep remove 2' do
    Bake.startBake("adapt/main", ["test_dep2", "--rebuild", "--adapt", "dep_remove"])
    expect($mystring.include?("Building 1 of 2: lib2 (test_ok)")).to be == true
    expect($mystring.include?("Building 2 of 2: main (test_dep2)")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end  
  
  it 'Dep replace 0' do
    Bake.startBake("adapt/main", ["test_dep0", "--rebuild", "--adapt", "dep_replace"])
    expect($mystring.include?("Building 1 of 4: lib1 (test_other)")).to be == true
    expect($mystring.include?("Building 2 of 4: lib1 (test_ok)")).to be == true
    expect($mystring.include?("Building 3 of 4: lib3 (test_ok)")).to be == true
    expect($mystring.include?("Building 4 of 4: main (test_dep0)")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end  
  
  it 'Dep replace 2' do
    Bake.startBake("adapt/main", ["test_dep2", "--rebuild", "--adapt", "dep_replace"])
    expect($mystring.include?("Building 1 of 4: lib1 (test_other)")).to be == true
    expect($mystring.include?("Building 2 of 4: lib1 (test_ok)")).to be == true
    expect($mystring.include?("Building 3 of 4: lib3 (test_ok)")).to be == true
    expect($mystring.include?("Building 4 of 4: main (test_dep2)")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end    
  
  it 'Set extend 0' do
    Bake.startBake("adapt/main", ["test_set0", "--rebuild", "--adapt", "set_extend"])
    expect($mystring.include?("vars: VARNEW1VARNEW3-")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end  
 
  it 'Set extend 2' do
    Bake.startBake("adapt/main", ["test_set2", "--rebuild", "--adapt", "set_extend"])
    expect($mystring.include?("vars: VARNEW1VAR2VARNEW3-")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end     
 
  it 'Set remove 0' do
    Bake.startBake("adapt/main", ["test_set0", "--rebuild", "--adapt", "set_remove"])
    expect($mystring.include?("vars: -")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end  

  it 'Set remove 2' do
    Bake.startBake("adapt/main", ["test_set2", "--rebuild", "--adapt", "set_remove"])
    expect($mystring.include?("vars: VAR2-")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end 
  
  it 'Set replace 0' do
    Bake.startBake("adapt/main", ["test_set0", "--rebuild", "--adapt", "set_replace"])
    expect($mystring.include?("vars: VARNEW1VARNEW3-")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end  
 
  it 'Set replace 2' do
    Bake.startBake("adapt/main", ["test_set2", "--rebuild", "--adapt", "set_replace"])
    expect($mystring.include?("vars: VARNEW1VARNEW3-")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end     

  
  it 'ArtifactName extend 0' do
    Bake.startBake("adapt/main", ["test_art0", "--rebuild", "-v2", "--adapt", "art_extend"])
    expect($mystring.include?("new.exe")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'ArtifactName extend 1' do
    Bake.startBake("adapt/main", ["test_art1", "--rebuild", "-v2", "--adapt", "art_extend"])
    expect($mystring.include?("new.exe")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'ArtifactName remove 0' do
    Bake.startBake("adapt/main", ["test_art0", "--rebuild", "-v2", "--adapt", "art_remove_ok"])
    expect($mystring.include?("main.exe")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'ArtifactName remove 1 ok' do
    Bake.startBake("adapt/main", ["test_art1", "--rebuild", "-v2", "--adapt", "art_remove_ok"])
    expect($mystring.include?("main.exe")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'ArtifactName remove 1 nok' do
    Bake.startBake("adapt/main", ["test_art1", "--rebuild", "-v2", "--adapt", "art_remove_nok"])
    expect($mystring.include?("org.exe")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end 
   
  it 'ArtifactName replace 0' do
    Bake.startBake("adapt/main", ["test_art0", "--rebuild", "-v2", "--adapt", "art_replace"])
    expect($mystring.include?("new.exe")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'ArtifactName replace 1' do
    Bake.startBake("adapt/main", ["test_art1", "--rebuild", "-v2", "--adapt", "art_replace"])
    expect($mystring.include?("new.exe")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
   
  it 'MapFile extend 0' do
    Bake.startBake("adapt/main", ["test_map0", "--rebuild", "-v2", "--adapt", "map_extend"])
    expect($mystring.include?("new.map")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'MapFile extend 1' do
    Bake.startBake("adapt/main", ["test_map1", "--rebuild", "-v2", "--adapt", "map_extend"])
    expect($mystring.include?("new.map")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'MapFile remove 0' do
    Bake.startBake("adapt/main", ["test_map0", "--rebuild", "-v2", "--adapt", "map_remove_ok"])
    expect($mystring.include?(".map")).to be == false
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'MapFile remove 1 ok' do
    Bake.startBake("adapt/main", ["test_map1", "--rebuild", "-v2", "--adapt", "map_remove_ok"])
    expect($mystring.include?(".map")).to be == false
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'MapFile remove 1 nok' do
    Bake.startBake("adapt/main", ["test_map1", "--rebuild", "-v2", "--adapt", "map_remove_nok"])
    expect($mystring.include?("org.map")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end 
   
  it 'MapFile replace 0' do
    Bake.startBake("adapt/main", ["test_map0", "--rebuild", "-v2", "--adapt", "map_replace"])
    expect($mystring.include?("new.map")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'MapFile replace 1' do
    Bake.startBake("adapt/main", ["test_map1", "--rebuild", "-v2", "--adapt", "map_replace"])
    expect($mystring.include?("new.map")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
   
  it 'LinkerScript extend 0' do
    Bake.startBake("adapt/main", ["test_lin0", "--rebuild", "-v2", "--adapt", "lin_extend"])
    expect($mystring.include?("linkerscript2.dld")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'LinkerScript extend 1' do
    Bake.startBake("adapt/main", ["test_lin1", "--rebuild", "-v2", "--adapt", "lin_extend"])
    expect($mystring.include?("linkerscript2.dld")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'LinkerScript remove 0' do
    Bake.startBake("adapt/main", ["test_lin0", "--rebuild", "-v2", "--adapt", "lin_remove_ok"])
    expect($mystring.include?(".dld")).to be == false
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'LinkerScript remove 1 ok' do
    Bake.startBake("adapt/main", ["test_lin1", "--rebuild", "-v2", "--adapt", "lin_remove_ok"])
    expect($mystring.include?(".dld")).to be == false
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'LinkerScript remove 1 nok' do
    Bake.startBake("adapt/main", ["test_lin1", "--rebuild", "-v2", "--adapt", "lin_remove_nok"])
    expect($mystring.include?("linkerscript1.dld")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end 
   
  it 'LinkerScript replace 0' do
    Bake.startBake("adapt/main", ["test_lin0", "--rebuild", "-v2", "--adapt", "lin_replace"])
    expect($mystring.include?("linkerscript2.dld")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end   
  
  it 'LinkerScript replace 1' do
    Bake.startBake("adapt/main", ["test_lin1", "--rebuild", "-v2", "--adapt", "lin_replace"])
    expect($mystring.include?("linkerscript2.dld")).to be == true
    expect($mystring.include?("Rebuilding done.")).to be == true
  end  
  
  
  
  
  
  
  
  #toReplace = [:exLib, :exLibSearchPath, :userLibrary, :startupSteps, :preSteps, :postSteps, :exitSteps, :toolchain, :defaultToolchain]
  #place << :step
   # toReplace << :files << :excludeFiles << :includeDir
    #      toReplace << :linkerScript << :artifactName << :mapFile
end

end