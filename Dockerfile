### Dockerfile for ldsc (python 3 implementation) and gcloud CLI

# Miniconda base image
FROM anaconda/miniconda
LABEL maintainer="Yu-Han Hsu <yuhanhsu@broadinstitute.org>"

# prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# install git and gcloud CLI
RUN apt-get update && apt-get install -y \
	git \
	bedtools \
	curl \
	ca-certificates \
	gnupg \
	&& echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
	&& curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
	&& apt-get update && apt-get install -y google-cloud-cli \
	&& rm -rf /root/.cache/pip/ \
	&& find /usr/lib/google-cloud-sdk -name "*.pyc" -delete \
	&& find /usr/lib/google-cloud-sdk -name "*__pycache__*" -delete \
	&& rm -rf /var/lib/apt/lists/*

# clone python3 ldsc repo
# ldsc39 branch = python 3.9
#RUN git clone -b ldsc39 https://github.com/CBIIT/ldsc.git
# forked repo with bug fix in ldscore/parse.py 
#RUN git clone -b ldsc39 https://github.com/yuhanhsu/ldsc.git
# ldsc313 branch = python 3.13
RUN git clone -b ldsc313 https://github.com/yuhanhsu/ldsc.git
WORKDIR /ldsc

# create conda environment with dependencies
ENV CONDA_PLUGINS_AUTO_ACCEPT_TOS=true
RUN conda env create -f environment3.yml

# test environment
SHELL ["/bin/bash", "--login", "-c"]
RUN conda activate ldsc \
	&& gcloud help \
	&& ./munge_sumstats.py -h \
	&& ./make_annot.py -h \
	&& ./ldsc.py -h

# cromwell overides startup script that can activate conda environment
# so use absolute path in ldsc env when calling python in WDL:
# /opt/miniconda3/envs/ldsc/bin/python

