#!/usr/bin/env ruby

require 'fileutils'

path = File.expand_path(File.dirname __FILE__)
require path+'../lib/importer.rb'
require path+'../lib/nodes.rb'
if ARGV.size < 3
	puts "USAGE: [EdgeR FPKM file] [Interpro Results TSV] [Go OBO file] (--reset)"
	exit
end


FileUtils.mkdir_p path+"../db/neo4j_data"
Neo4j::Config[:storage_path] = path+"/neo4j_data"

if ARGV.include? "--reset"
	FileUtils.rm_rf Neo4j::Config[:storage_path]
end

def split_line(line,sep)
	line.chomp!
	(line.start_with? "#") ? false : line.split(sep)
end

def import_transcript(file,transcript_nodes)
		sample_nodes = []
		batch = BatchImport.new(Neo4j::Config[:storage_path])
		transcript_index = batch.create_index(Transcript,"sequence_id")
		sample_index = batch.create_index(Sample,"name")
		expression = BatchImport.create_relation("expression")
		File.open(file).each do |line|
			if (line.start_with? "#")
				samples = line.chomp.split("\t")[1..-1]
				samples.each {|s| sample_nodes << batch.add_node(sample_index,{"name" => s},Sample)}
			else (data = split_line(line,"\t"))
				transcript_nodes[data[0]] = batch.add_node(transcript_index,{"sequence_id" => data[0]},Transcript)
				sample_nodes.each_with_index do |sample_node_id,index|
					batch.inserter.create_relationship(sample_node_id,transcript_nodes[data[0]],expression,{"fpkm" => data[index+1].to_f})
				end
			end
		end
		batch.shutdown sample_index,transcript_index
end

def import_domain(file,transcript_nodes,go_nodes)
		domains = {}
		batch = BatchImport.new(Neo4j::Config[:storage_path])
		domain_index = batch.create_index(Domain,"accession_id")
		contains = BatchImport.create_relation "contains"
		functions = BatchImport.create_relation "functions"
		File.open(file).each do |line|
			if (data = split_line(line,"\t"))
				go = []
				if data[13]
					go = data[13].split("|")
				end
				sequences = data[0].split("|")
				sequences.each do |seq_id|
					unless domains.has_key? data[4]
				 	  properties = {} 
						if data.size > 11
							properties = {"accession_id" => data[4], "description" => data[5], "interpro" => data[11]}
						else
							properties = {"accession_id" => data[4], "description" => data[5]}
						end
						domains[data[4]] = batch.add_node(domain_index,properties,Domain)
						go.each do |go_id|
							g_id = go_id.split(":")[1]
							go_node_id = go_nodes[g_id]
							batch.inserter.create_relationship(domains[data[4]],go_node_id,functions,nil)
						end
					end
					transcript_node_id = transcript_nodes[seq_id.split("\s").first]	
					batch.inserter.create_relationship(transcript_node_id,domains[data[4]],contains,nil)
				end
			end
		end
		batch.shutdown domain_index
end


def process_obo_block(block)
		data = []
		block.split("\n").each do |elem|
			if elem.start_with? "id: "
		   	data << elem.gsub("id: ","")
			elsif elem.start_with? "name: "
				data << elem.gsub("name: ","")
			elsif elem.start_with? "namespace: "
				data << elem.gsub("namespace: ","")
			end	
		end
		data
end

def import_go(file_name,go_nodes)
	batch = BatchImport.new(Neo4j::Config[:storage_path])
	go_index = batch.create_index(Go,"go_id")
	file = File.open(file_name)
	file.each do |line|
			if line.start_with? "[Term]"
				 data = process_obo_block file.gets("\n\n")
				 properties = {'go_id' => data[0].split(":")[1], 'name' => data[1], 'namespace' => data[2]}
				 go_nodes[data[0].split(":")[1]] = batch.add_node(go_index,properties,Go)
			end
	end
	batch.shutdown go_index
end



transcript_file = ARGV.shift
domain_file = ARGV.shift
go_file = ARGV.shift

transcript_nodes = {}
go_nodes = {}

puts "Starting transcript data import..."
import_transcript transcript_file,transcript_nodes
puts "done."

puts "Starting Go data import..."
import_go go_file, go_nodes
puts "done."

puts "Starting Domain data import and relationship creation..."
import_domain domain_file, transcript_nodes, go_nodes
puts "done."

puts "All data import completed."

