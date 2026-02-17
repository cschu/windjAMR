FROM r-base:4.5.2

LABEL maintainer="cschu1981@gmail.com"
LABEL version="0.1.0"
LABEL description="windjAMR R dependencies"


ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update

RUN R --slave -e 'install.packages(c("dplyr", "stringr"), dependencies=TRUE, repos="https://cran.rstudio.com/")'