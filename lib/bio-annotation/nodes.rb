class Transcript; end
class Domain; end
class Go; end
class Sample; end
class Expression < Neo4j::Rails::Relationship; end

class	Sample
	include Neo4j::NodeMixin	
	property :name
	index :name
	has_n(:transcripts).to(Transcript).relationship(Expression)	
end

class Expression
	property :fpkm, :type => Float
	index :fpkm
end


class Transcript 
	include Neo4j::NodeMixin
	property :sequence_id 
	index :sequence_id
	has_n(:domains).to(Domain)
	has_n(:samples).from(Sample,:samples)
end

class Domain
	include Neo4j::NodeMixin
	property :accession_id, :description, :interpro
	index :accession_id
	has_n(:domains).from(Transcript, :domains)
	has_n(:functions).to(Go)
end

class Go
  include Neo4j::NodeMixin	
	property :go_id, :name, :namespace	
	index :go_id
	has_n(:functions).from(Domain,:functions)
end

