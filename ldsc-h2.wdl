version 1.0

workflow main {
	input {
		# docker image with ldsc and gcloud CLI
		String ldsc_docker
		
		# bucket to store output
		String destination

		# input to ldsc scripts
		String out_dir
		String gene_set
		String gene_set_folder
		String trait
		File trait_file
		String baseline_folder
		String baseline_prefix
		# optional: conditional background (e.g. neuronal proteome)
		String? background_folder
		String? background_prefix
		String weights_folder
		String weights_prefix
		String freq_folder
		String freq_prefix
	}

	call run_ldsc_h2 {
		input:
			ldsc_docker = ldsc_docker,
			destination = destination,
			out_dir = out_dir,
			gene_set = gene_set,
			gene_set_folder = gene_set_folder,
			trait = trait,
			trait_file = trait_file,
			baseline_folder = baseline_folder,
			baseline_prefix = baseline_prefix,
			background_folder = background_folder,
			background_prefix = background_prefix,
			weights_folder = weights_folder,
			weights_prefix = weights_prefix,
                	freq_folder = freq_folder
	}

	output {
		# bucket link to output
		String output_h2 = run_ldsc_h2.out_link
	}
}

task run_ldsc_h2 {
	input {
		String ldsc_docker
		String destination
		String out_dir
		String gene_set
		String gene_set_folder
		String trait
		File trait_file
		String baseline_folder
		String baseline_prefix
		String? background_folder
		String? background_prefix
		String weights_folder
		String weights_prefix
		String freq_folder
		String freq_prefix
	}

	command <<<
		echo "### copy input folders to working directory"
		gcloud storage cp -r "~{gene_set_folder}" \
		"~{baseline_folder}" "~{weights_folder}" "~{freq_folder}" .
		
		baseline_name=$(echo "~{baseline_folder}" | awk -F '/' '{print $NF}')
		weights_name=$(echo "~{weights_folder}" | awk -F '/' '{print $NF}')
		freq_name=$(echo "~{freq_folder}" | awk -F '/' '{print $NF}')
	
		# set up alternative ldsc input params if optional background is defined
		if [ -n "~{background_folder}" ]; then
			gcloud storage cp -r "~{background_folder}" .
			background_name=$(echo "~{background_folder}" | awk -F '/' '{print $NF}')
			
			ref_ld_chr_str="${baseline_name}/~{baseline_prefix}.,${background_name}/~{background_prefix}.,~{gene_set}/~{gene_set}."
			out_str="~{out_dir}/~{gene_set}/~{trait}.~{baseline_prefix}.~{background_prefix}.~{gene_set}"
		else
			ref_ld_chr_str="${baseline_name}/~{baseline_prefix}.,~{gene_set}/~{gene_set}."
			out_str="~{out_dir}/~{gene_set}/~{trait}.~{baseline_prefix}.~{gene_set}"
		fi
		
		# create output directory
		mkdir -p "~{out_dir}/~{gene_set}"
		
		echo "### partition heritability (ldsc.py --h2)"
		python /ldsc/ldsc.py \
		--h2 "~{trait_file}" \
		--ref-ld-chr "${ref_ld_chr_str}" \ 
		--w-ld-chr "${weights_name}/~{weights_prefix}." \ 
		--frqfile-chr "${freq_name}/~{freq_prefix}." \
		--overlap-annot \
		--print-coefficients \
		--out "${out_str}"

		echo "### copy output files to destination bucket"
		gcloud storage cp -r "~{out_dir}" "~{destination}"

		# save bucket link to output folder
		echo "~{destination}/~{out_dir}/~{gene_set}" > outLink.txt
	>>>

	output {
		String out_link = read_string("outLink.txt")
	}

	runtime {
		docker: "~{ldsc_docker}"
		memory: "20 GB"
		cpu: 1
		preemptible: 2
	}
}

