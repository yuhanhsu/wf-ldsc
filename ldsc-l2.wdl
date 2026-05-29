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
		File gene_set_file
		File gene_coord_file
		Int window_size
		String plink_folder
		String plink_prefix
		Int ld_wind_cm
		File snp_file
	}

	# scatter over chromosomes 1-22 (range(22) returns 0-indexed array 0-21)
	scatter (i in range(22)) {
		call run_ldsc_l2 {
			input:
				ldsc_docker = ldsc_docker,
				destination = destination,
				out_dir = out_dir,
				gene_set = gene_set,
				gene_set_file = gene_set_file,
				gene_coord_file = gene_coord_file,
				window_size = window_size,
				plink_folder = plink_folder,
				plink_prefix = plink_prefix,
				chr = i+1,
				ld_wind_cm = ld_wind_cm,
				snp_file = snp_file
		}
	}

	output {
		# bucket link to output
		String output_l2 = select_first(run_ldsc_l2.out_link)
	}
}

task run_ldsc_l2 {
	input {
		String ldsc_docker
		String destination
		String out_dir
		String gene_set
		File gene_set_file
		File gene_coord_file
		Int window_size
		String plink_folder
		String plink_prefix
		Int chr
		Int ld_wind_cm
		File snp_file
	}

	command <<<
		echo "### copy plink folder to working directory"
		gcloud storage cp -r "~{plink_folder}" .
		
		# get plink folder name (careful with single vs. double quotes for awk)
		plink_name=$(echo "~{plink_folder}" | awk -F '/' '{print $NF}')
		
		# create output directory
		mkdir -p "~{out_dir}/~{gene_set}"
		
		echo "### make annotation (make_annot.py)"
		/opt/miniconda3/envs/ldsc/bin/python /ldsc/make_annot.py \
		--gene-set-file "~{gene_set_file}" \
		--gene-coord-file "~{gene_coord_file}" \
		--windowsize ~{window_size} \
		--bimfile "${plink_name}/~{plink_prefix}.~{chr}.bim" \
		--annot-file "~{out_dir}/~{gene_set}/~{gene_set}.~{chr}.annot.gz"

		echo "### compute LD scores (ldsc.py --l2)"
		/opt/miniconda3/envs/ldsc/bin/python /ldsc/ldsc.py \
		--l2 \
		--bfile "${plink_name}/~{plink_prefix}.~{chr}" \
		--ld-wind-cm ~{ld_wind_cm} \
		--annot "~{out_dir}/~{gene_set}/~{gene_set}.~{chr}.annot.gz" \
		--thin-annot \
		--out "~{out_dir}/~{gene_set}/~{gene_set}.~{chr}" \
		--print-snps "~{snp_file}"

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

