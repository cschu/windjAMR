include { amrfinder } from "./windjamr/modules/amrfinder"


params.contig_file_pattern = "**.{fna,fasta,fa,fna.gz,fasta.gz,fa.gz}"
params.gene_file_pattern = "**.{faa,fna,fasta,fa,faa.gz,fna.gz,fasta.gz,fa.gz}"
params.contigs = null
params.genes = null
params.amrfinder_db = "/g/bork6/dickinson/argnorm_prep/containers/AMRFinder_DB/2025-07-16.1"

workflow {

	contig_input_ch = Channel
        .fromPath("${params.contigs}/${params.contig_file_pattern}")
        .map { fasta ->
            def genome_id = fasta.name.replaceAll(/\.(fa(s(ta)?)?|fna)(\.gz)?$/, "")
            return [ genome_id, fasta ]
        }

	Channel
		.fromPath("${params.genes}/${params.gene_file_pattern}")
		.map { fasta ->
			def genome_id = fasta.name.replaceAll(/\.(fa(s(ta)?)?|f[an]a)(\.gz)?$/, "")
			return [ genome_id, fasta ]
		}
		.branch { genome_id, fasta  ->
			proteins: (fasta.name.endsWith(".faa") || fasta.name.endsWith(".faa.gz"))
			genes: true
		}
		.set { gene_input_ch }


	contig_input_ch.dump(pretty: true, tag: "contig_input_ch")
	gene_input_ch.proteins.dump(pretty: true, tag: "gene_input_ch.proteins")
	gene_input_ch.genes.dump(pretty: true, tag: "gene_input_ch.genes")
	
	amrfinder(
		gene_input_ch.genes.mix(contig_input_ch),
		params.amrfinder_db
	)
	



}