
require 'neo4j'

java_import	"org.neo4j.unsafe.batchinsert.BatchInserters"
java_import "org.neo4j.unsafe.batchinsert.LuceneBatchInserterIndexProvider"
java_import "org.neo4j.graphdb.DynamicRelationshipType"


class BatchImport
	

	def self.create_relation(name)
		DynamicRelationshipType.with_name name
	end


	attr_reader :inserter
	def initialize(db_path)
		@inserter = BatchInserters.inserter(db_path)
		@index_provider = LuceneBatchInserterIndexProvider.new @inserter
	end

	def create_index(klass, name, cache=100000)
		index = @index_provider.node_index(klass.to_s+"_exact",{"type" => "exact" })	
		index.setCacheCapacity(name,cache)
		index
	end

	def add_node(index,properties,klass)
		properties["_classname"] = klass.to_s
		node_id = @inserter.create_node(properties)
		index.add(node_id,properties)
		node_id
	end

	def shutdown(*indexes)
		indexes.each {|index| index.flush}
		@index_provider.shutdown
		@inserter.shutdown
	end

end


